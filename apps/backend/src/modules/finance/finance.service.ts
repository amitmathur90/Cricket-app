import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, LessThanOrEqual, MoreThanOrEqual, Repository } from 'typeorm';
import { findManyOrgScoped, findOneOrgScoped } from '../../common/base/org-scoped.repository';
import { AuctionPlayerPool, AuctionPoolStatus } from '../../database/entities/auction-player-pool.entity';
import {
  FINANCE_CATEGORY_TYPE,
  FinanceTransaction,
  FinanceTransactionCategory,
  FinanceTransactionType,
} from '../../database/entities/finance-transaction.entity';
import { Sponsor } from '../../database/entities/sponsor.entity';
import { TeamPlayer } from '../../database/entities/team-player.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { CreateFinanceTransactionDto } from './dto/create-finance-transaction.dto';
import { QueryFinanceTransactionsDto } from './dto/query-finance-transactions.dto';
import { UpdateFinanceTransactionDto } from './dto/update-finance-transaction.dto';

export interface DashboardResponse {
  scope: { organizationId: string; tournamentId: string | null };
  totalRevenue: string;
  revenueBreakdown: {
    registrationRevenue: string;
    auctionRevenue: string;
    sponsorshipRevenue: string;
    otherIncome: string;
  };
  totalExpenses: string;
  expenseBreakdown: {
    groundExpense: string;
    officialsPayment: string;
    otherExpense: string;
  };
  netBalance: string;
}

export interface TeamFeeRow {
  tournamentTeamId: string;
  teamId: string;
  teamName: string;
  feeAmount: string;
  /**
   * Honest placeholder — see FinanceService class doc comment. Nothing in
   * this codebase tracks per-team payment status today, so this is never
   * fabricated as true.
   */
  paid: false;
  paidAt: null;
}

export interface PlayerFeeRow {
  teamPlayerId: string;
  playerId: string;
  playerName: string;
  tournamentTeamId: string;
  teamName: string;
  feeAmount: string;
  paid: false;
  paidAt: null;
}

/**
 * Finance dashboard aggregation. Three revenue lines are DERIVED at read
 * time from data that already exists elsewhere (never persisted, same
 * philosophy as `TournamentsService.getPointsTable`/`teamsCount`):
 *
 *  - `registrationRevenue` = teamRegistrationFee × (count of tournament_teams
 *    rows) + playerRegistrationFee × (count of team_players rows across
 *    those tournament_teams). Team count intentionally does NOT filter out
 *    `WITHDRAWN` teams — this mirrors `TournamentsService.teamsCount`, which
 *    also counts all `tournament_teams` rows unconditionally, so the two
 *    "team count" figures shown elsewhere in the app and here never
 *    disagree. Player count uses `team_players` (the resolved roster) rather
 *    than `tournament_applications`, because an approved application does
 *    NOT automatically create a roster entry in this codebase (see
 *    TournamentApplication's own doc comment) — `team_players` is the
 *    stronger, more concrete signal that a player is actually registered
 *    onto a tournament roster and a fee is attributable to them.
 *
 *  - `auctionRevenue` = SUM(auction_player_pool.finalPrice) WHERE
 *    status = 'sold', for auction sessions under the tournament(s) in
 *    scope. Judgment call (documented per the task): this is NOT "money the
 *    org banked" — an auction sale debits a *team's* purse, it doesn't
 *    credit the organization's bank account. It's shown as a
 *    revenue-adjacent reporting figure representing the total value that
 *    changed hands in the auction (mirroring how the spec's mockup labels
 *    it "Auction ₹1,80,000" as a headline number), consistent with
 *    `purse_ledger`/`auction_player_pool` remaining the sole source of
 *    truth for the underlying transactions — nothing is duplicated into
 *    `finance_transactions`.
 *
 *  - `sponsorshipRevenue` = SUM(Sponsor.amount) [org-wide only — `Sponsor`
 *    has no `tournamentId`, so it's excluded when the dashboard is scoped to
 *    one tournament] + SUM(finance_transactions WHERE category=sponsorship,
 *    type=income). Additive, not deduped, per the task spec — `Sponsor` is
 *    the source of truth for ongoing sponsorship deals, `finance_transactions`
 *    covers one-off sponsorship income not modeled there. The `Sponsor`
 *    query is wrapped defensively: at the time this module was built, the
 *    Sponsor module existed as an entity file but had NOT been migrated
 *    into the live database yet (a parallel workstream) — see the
 *    try/catch below, which treats a missing `sponsors` table as zero
 *    rather than failing the whole dashboard.
 *
 * `otherIncome` and the three expense categories come straight off
 * `finance_transactions`, grouped by `category` (whose `type` is enforced
 * consistent via `FINANCE_CATEGORY_TYPE` — see `assertCategoryTypeMatch`).
 *
 * Tournament-scoping rule for `finance_transactions` rows: when
 * `tournamentId` is provided, ONLY rows with that exact `tournamentId` are
 * included (org-wide rows with a null `tournamentId` are excluded — they
 * aren't attributable to this one tournament). When no `tournamentId` is
 * given, every row for the org is included regardless of its own
 * `tournamentId` (both tournament-specific and org-wide rows), since that's
 * the whole-org aggregate.
 */
@Injectable()
export class FinanceService {
  private readonly logger = new Logger(FinanceService.name);

  constructor(
    @InjectRepository(FinanceTransaction)
    private readonly financeRepo: Repository<FinanceTransaction>,
    @InjectRepository(Tournament) private readonly tournamentRepo: Repository<Tournament>,
    @InjectRepository(TournamentTeam) private readonly tournamentTeamRepo: Repository<TournamentTeam>,
    @InjectRepository(TeamPlayer) private readonly teamPlayerRepo: Repository<TeamPlayer>,
    @InjectRepository(AuctionPlayerPool) private readonly poolRepo: Repository<AuctionPlayerPool>,
    @InjectRepository(Sponsor) private readonly sponsorRepo: Repository<Sponsor>,
  ) {}

  private assertCategoryTypeMatch(category: FinanceTransactionCategory, type: FinanceTransactionType): void {
    const expected = FINANCE_CATEGORY_TYPE[category];
    if (expected !== type) {
      throw new BadRequestException(
        `Category "${category}" must have type "${expected}", got "${type}"`,
      );
    }
  }

  /** Verifies the tournament belongs to the org and returns it, or throws NotFoundException. */
  private async getOrgScopedTournament(organizationId: string, tournamentId: string): Promise<Tournament> {
    const tournament = await findOneOrgScoped(this.tournamentRepo, organizationId, { id: tournamentId });
    if (!tournament) {
      throw new NotFoundException('Tournament not found');
    }
    return tournament;
  }

  // --- CRUD ---

  async create(
    organizationId: string,
    dto: CreateFinanceTransactionDto,
    createdByUserId: string,
  ): Promise<FinanceTransaction> {
    this.assertCategoryTypeMatch(dto.category, dto.type);
    if (dto.tournamentId) {
      await this.getOrgScopedTournament(organizationId, dto.tournamentId);
    }
    return this.financeRepo.save(
      this.financeRepo.create({
        organizationId,
        tournamentId: dto.tournamentId ?? null,
        category: dto.category,
        type: dto.type,
        amount: dto.amount.toFixed(2),
        description: dto.description ?? null,
        referenceDate: dto.referenceDate,
        createdByUserId,
      }),
    );
  }

  async findAll(organizationId: string, query: QueryFinanceTransactionsDto): Promise<FinanceTransaction[]> {
    const where: Record<string, unknown> = {};
    if (query.tournamentId) where.tournamentId = query.tournamentId;
    if (query.category) where.category = query.category;
    if (query.type) where.type = query.type;
    if (query.from && query.to) where.referenceDate = Between(query.from, query.to);
    else if (query.from) where.referenceDate = MoreThanOrEqual(query.from);
    else if (query.to) where.referenceDate = LessThanOrEqual(query.to);

    return findManyOrgScoped(this.financeRepo, organizationId, where);
  }

  async findOne(organizationId: string, transactionId: string): Promise<FinanceTransaction> {
    const transaction = await findOneOrgScoped(this.financeRepo, organizationId, { id: transactionId });
    if (!transaction) {
      throw new NotFoundException('Finance transaction not found');
    }
    return transaction;
  }

  async update(
    organizationId: string,
    transactionId: string,
    dto: UpdateFinanceTransactionDto,
  ): Promise<FinanceTransaction> {
    const transaction = await this.findOne(organizationId, transactionId);
    const nextCategory = dto.category ?? transaction.category;
    const nextType = dto.type ?? transaction.type;
    this.assertCategoryTypeMatch(nextCategory, nextType);
    if (dto.tournamentId) {
      await this.getOrgScopedTournament(organizationId, dto.tournamentId);
    }
    Object.assign(transaction, {
      ...dto,
      tournamentId: dto.tournamentId !== undefined ? dto.tournamentId : transaction.tournamentId,
      amount: dto.amount !== undefined ? dto.amount.toFixed(2) : transaction.amount,
    });
    return this.financeRepo.save(transaction);
  }

  async remove(organizationId: string, transactionId: string): Promise<void> {
    const transaction = await this.findOne(organizationId, transactionId);
    await this.financeRepo.remove(transaction);
  }

  // --- Derived data ---

  /** Resolves the set of tournament ids in scope for a dashboard/report call. */
  private async resolveTournamentScope(
    organizationId: string,
    tournamentId?: string,
  ): Promise<Tournament[]> {
    if (tournamentId) {
      return [await this.getOrgScopedTournament(organizationId, tournamentId)];
    }
    return findManyOrgScoped(this.tournamentRepo, organizationId);
  }

  private async computeRegistrationRevenue(tournaments: Tournament[]): Promise<number> {
    if (tournaments.length === 0) return 0;
    const tournamentIds = tournaments.map((t) => t.id);

    const teamCountRows = await this.tournamentTeamRepo
      .createQueryBuilder('tt')
      .select('tt.tournamentId', 'tournamentId')
      .addSelect('COUNT(*)', 'count')
      .where('tt.tournamentId IN (:...tournamentIds)', { tournamentIds })
      .groupBy('tt.tournamentId')
      .getRawMany<{ tournamentId: string; count: string }>();
    const teamCountByTournament = new Map(teamCountRows.map((r) => [r.tournamentId, Number(r.count)]));

    const playerCountRows = await this.teamPlayerRepo
      .createQueryBuilder('tp')
      .innerJoin('tp.tournamentTeam', 'tt')
      .select('tt.tournamentId', 'tournamentId')
      .addSelect('COUNT(*)', 'count')
      .where('tt.tournamentId IN (:...tournamentIds)', { tournamentIds })
      .groupBy('tt.tournamentId')
      .getRawMany<{ tournamentId: string; count: string }>();
    const playerCountByTournament = new Map(playerCountRows.map((r) => [r.tournamentId, Number(r.count)]));

    let total = 0;
    for (const tournament of tournaments) {
      const teamCount = teamCountByTournament.get(tournament.id) ?? 0;
      const playerCount = playerCountByTournament.get(tournament.id) ?? 0;
      const teamFee = tournament.teamRegistrationFee ? parseFloat(tournament.teamRegistrationFee) : 0;
      const playerFee = tournament.playerRegistrationFee ? parseFloat(tournament.playerRegistrationFee) : 0;
      total += teamFee * teamCount + playerFee * playerCount;
    }
    return total;
  }

  private async computeAuctionRevenue(tournamentIds: string[]): Promise<number> {
    if (tournamentIds.length === 0) return 0;
    const result = await this.poolRepo
      .createQueryBuilder('pool')
      .innerJoin('pool.auctionSession', 'session')
      .select('COALESCE(SUM(pool.finalPrice), 0)', 'total')
      .where('session.tournamentId IN (:...tournamentIds)', { tournamentIds })
      .andWhere('pool.status = :status', { status: AuctionPoolStatus.SOLD })
      .getRawOne<{ total: string }>();
    return parseFloat(result?.total ?? '0');
  }

  /**
   * Scoped to the org (never to a single tournament) — `Sponsor` has no
   * `tournamentId` column, so a sponsor amount cannot be attributed to one
   * tournament; it's included only in the org-wide dashboard call.
   * Defensive: at the time this module was built the `sponsors` table did
   * not exist yet in the live database (a parallel, in-progress
   * workstream) — a missing-relation error is caught and treated as zero
   * rather than failing the whole dashboard, so this keeps working whether
   * that migration has landed yet or not.
   */
  private async computeSponsorEntityRevenue(
    organizationId: string,
    scopedToTournament: boolean,
  ): Promise<number> {
    if (scopedToTournament) return 0;
    try {
      const result = await this.sponsorRepo
        .createQueryBuilder('sponsor')
        .select('COALESCE(SUM(sponsor.amount), 0)', 'total')
        .where('sponsor.organizationId = :organizationId', { organizationId })
        .getRawOne<{ total: string }>();
      return parseFloat(result?.total ?? '0');
    } catch (err) {
      this.logger.warn(
        `Sponsor revenue query failed (sponsors table likely not migrated yet) — treating as 0: ${(err as Error).message}`,
      );
      return 0;
    }
  }

  private async sumFinanceTransactions(
    organizationId: string,
    tournamentId: string | undefined,
    category: FinanceTransactionCategory,
  ): Promise<number> {
    const qb = this.financeRepo
      .createQueryBuilder('ft')
      .select('COALESCE(SUM(ft.amount), 0)', 'total')
      .where('ft.organizationId = :organizationId', { organizationId })
      .andWhere('ft.category = :category', { category });
    if (tournamentId) {
      qb.andWhere('ft.tournamentId = :tournamentId', { tournamentId });
    }
    const result = await qb.getRawOne<{ total: string }>();
    return parseFloat(result?.total ?? '0');
  }

  async getDashboard(organizationId: string, tournamentId?: string): Promise<DashboardResponse> {
    const tournaments = await this.resolveTournamentScope(organizationId, tournamentId);
    const tournamentIds = tournaments.map((t) => t.id);

    const [
      registrationRevenue,
      auctionRevenue,
      sponsorEntityRevenue,
      sponsorshipTransactions,
      otherIncome,
      groundExpense,
      officialsPayment,
      otherExpense,
    ] = await Promise.all([
      this.computeRegistrationRevenue(tournaments),
      this.computeAuctionRevenue(tournamentIds),
      this.computeSponsorEntityRevenue(organizationId, !!tournamentId),
      this.sumFinanceTransactions(organizationId, tournamentId, FinanceTransactionCategory.SPONSORSHIP),
      this.sumFinanceTransactions(organizationId, tournamentId, FinanceTransactionCategory.OTHER_INCOME),
      this.sumFinanceTransactions(organizationId, tournamentId, FinanceTransactionCategory.GROUND_EXPENSE),
      this.sumFinanceTransactions(organizationId, tournamentId, FinanceTransactionCategory.OFFICIALS_PAYMENT),
      this.sumFinanceTransactions(organizationId, tournamentId, FinanceTransactionCategory.OTHER_EXPENSE),
    ]);

    const sponsorshipRevenue = sponsorEntityRevenue + sponsorshipTransactions;
    const totalRevenue = registrationRevenue + auctionRevenue + sponsorshipRevenue + otherIncome;
    const totalExpenses = groundExpense + officialsPayment + otherExpense;
    const netBalance = totalRevenue - totalExpenses;

    const fmt = (n: number) => n.toFixed(2);
    return {
      scope: { organizationId, tournamentId: tournamentId ?? null },
      totalRevenue: fmt(totalRevenue),
      revenueBreakdown: {
        registrationRevenue: fmt(registrationRevenue),
        auctionRevenue: fmt(auctionRevenue),
        sponsorshipRevenue: fmt(sponsorshipRevenue),
        otherIncome: fmt(otherIncome),
      },
      totalExpenses: fmt(totalExpenses),
      expenseBreakdown: {
        groundExpense: fmt(groundExpense),
        officialsPayment: fmt(officialsPayment),
        otherExpense: fmt(otherExpense),
      },
      netBalance: fmt(netBalance),
    };
  }

  /**
   * Per-registered-team fee list. `paid`/`paidAt` are HONEST PLACEHOLDERS —
   * nothing in this codebase tracks whether a team's registration fee was
   * actually paid (no `paidAt`/`paymentStatus` concept exists anywhere on
   * `TournamentTeam` or elsewhere). Built anyway (rather than skipped)
   * because the fee-amount-owed half is genuinely useful and derivable;
   * every row is always `paid: false, paidAt: null` rather than fabricating
   * a status. A future milestone that adds real payment tracking should
   * replace this placeholder, not this endpoint's shape.
   */
  async getTeamFees(organizationId: string, tournamentId: string): Promise<TeamFeeRow[]> {
    const tournament = await this.getOrgScopedTournament(organizationId, tournamentId);
    const feeAmount = tournament.teamRegistrationFee ?? '0.00';

    const teams = await this.tournamentTeamRepo.find({
      where: { tournamentId },
      relations: ['team'],
    });
    return teams.map((tt) => ({
      tournamentTeamId: tt.id,
      teamId: tt.teamId,
      teamName: tt.team.name,
      feeAmount,
      paid: false,
      paidAt: null,
    }));
  }

  /** Same honest-placeholder rationale as `getTeamFees` — see its doc comment. */
  async getPlayerFees(organizationId: string, tournamentId: string): Promise<PlayerFeeRow[]> {
    const tournament = await this.getOrgScopedTournament(organizationId, tournamentId);
    const feeAmount = tournament.playerRegistrationFee ?? '0.00';

    const rosterEntries = await this.teamPlayerRepo
      .createQueryBuilder('tp')
      .innerJoinAndSelect('tp.tournamentTeam', 'tt')
      .innerJoinAndSelect('tt.team', 'team')
      .innerJoinAndSelect('tp.player', 'player')
      .where('tt.tournamentId = :tournamentId', { tournamentId })
      .getMany();

    return rosterEntries.map((tp) => ({
      teamPlayerId: tp.id,
      playerId: tp.playerId,
      playerName: tp.player.fullName,
      tournamentTeamId: tp.tournamentTeamId,
      teamName: tp.tournamentTeam.team.name,
      feeAmount,
      paid: false,
      paidAt: null,
    }));
  }
}
