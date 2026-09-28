import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Brackets, In, Repository } from 'typeorm';
import { findManyOrgScoped, findOneOrgScoped } from '../../common/base/org-scoped.repository';
import { Ball, DismissalType, ExtraType } from '../../database/entities/ball.entity';
import { Innings } from '../../database/entities/innings.entity';
import { Match, MatchStatus } from '../../database/entities/match.entity';
import { NotificationType } from '../../database/entities/notification.entity';
import { Player, PlayerRole, PlayerVerificationStatus } from '../../database/entities/player.entity';
import { TeamPlayer } from '../../database/entities/team-player.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { SmsService } from '../sms/sms.service';
import { AddToRosterDto } from './dto/add-to-roster.dto';
import { CreatePlayerDto } from './dto/create-player.dto';
import { DEFAULT_RANKINGS_LIMIT, RankingMetric } from './dto/player-rankings-query.dto';
import { QuickAddPlayerDto } from './dto/quick-add-player.dto';
import { RatePlayerDto } from './dto/rate-player.dto';
import { UpdatePlayerDto } from './dto/update-player.dto';
import { VerifyPlayerDto } from './dto/verify-player.dto';

// ---------------------------------------------------------------------
// Player statistics — response shapes. See getStatistics() doc for the
// aggregation approach; these mirror TournamentsService's PointsTableRow
// precedent (a computed-on-read shape defined alongside the service method
// that builds it, nothing persisted).
// ---------------------------------------------------------------------

/**
 * `matchesPlayed` definition: a completed match counts if the player
 * appears in at least one non-voided `Ball` row for that match — as
 * striker, non-striker, bowler, the dismissed batter, or the fielder. This
 * is the "appeared in the ball log" definition, NOT "was named in a Playing
 * XI". A player picked in the XI who never faced a ball, never bowled, and
 * was never involved in a dismissal (as batter or fielder) will NOT count
 * towards matchesPlayed under this definition. That's a real but rare edge
 * case, and the deliberate choice here (not an oversight): it's the more
 * useful "genuinely took part" signal for a stats screen, it falls straight
 * out of the same ball-log query every other number here needs, and a
 * Playing-XI-based definition would require a second, unrelated join
 * (match_lineups) purely to count players who otherwise contribute nothing
 * to any other statistic on this page.
 */
export interface PlayerStatisticsSummary {
  matchesPlayed: number;
  totalRuns: number;
  timesOut: number;
  /** runs / timesOut. Null (not Infinity/NaN) when timesOut is 0 — see class doc. */
  battingAverage: number | null;
  /** (totalRuns / totalBallsFaced) * 100, aggregated across every innings. 0 when no balls faced. */
  strikeRate: number;
  totalWickets: number;
  /** totalRunsConceded / (totalLegalBallsBowled / 6). Null when the player has never bowled a legal ball. */
  bowlingEconomy: number | null;
}

export interface PlayerBattingStats {
  innings: number;
  runs: number;
  ballsFaced: number;
  highestScore: number;
  highestScoreNotOut: boolean;
  fifties: number;
  hundreds: number;
  fours: number;
  sixes: number;
  timesOut: number;
  average: number | null;
  strikeRate: number;
}

export interface PlayerBowlingStats {
  innings: number;
  /** overs.balls display notation (e.g. "4.3") — see Innings.totalOversBowled doc for why this isn't a true decimal. */
  overs: string;
  runsConceded: number;
  wickets: number;
  /** Best single-innings figures by (most wickets, then fewest runs). Null if the player has never bowled. */
  bestBowling: { wickets: number; runsConceded: number } | null;
  average: number | null;
  economy: number | null;
  maidens: number;
}

export interface PlayerFieldingStats {
  catches: number;
  runOuts: number;
  stumpings: number;
}

/** One completed match the player appeared in, with their personal figures for it. */
export interface PlayerMatchHistoryEntry {
  matchId: string;
  tournamentId: string;
  scheduledAt: Date | null;
  playerTournamentTeamId: string | null;
  opponentTournamentTeamId: string | null;
  playerTeamName: string;
  opponentTeamName: string;
  resultSummary: string | null;
  won: boolean | null;
  batting: {
    runs: number;
    ballsFaced: number;
    fours: number;
    sixes: number;
    isOut: boolean;
    dismissalType: DismissalType | null;
    strikeRate: number;
  } | null;
  bowling: {
    overs: string;
    runsConceded: number;
    wickets: number;
    maidens: number;
    economy: number;
  } | null;
  fielding: PlayerFieldingStats;
}

export interface PlayerStatisticsResponse {
  playerId: string;
  summary: PlayerStatisticsSummary;
  batting: PlayerBattingStats;
  bowling: PlayerBowlingStats;
  fielding: PlayerFieldingStats;
  /** Chronological (ascending by match date), so the client can plot runs/wickets-per-match directly off this array — see module doc. */
  matchHistory: PlayerMatchHistoryEntry[];
}

/** One row of the org-wide rankings leaderboard — see PlayersService.getRankings. */
export interface PlayerRankingRow {
  position: number;
  playerId: string;
  playerName: string;
  matchesPlayed: number;
  runs: number;
  wickets: number;
  average: number | null;
  economy: number | null;
}

@Injectable()
export class PlayersService {
  constructor(
    @InjectRepository(Player) private readonly playerRepo: Repository<Player>,
    @InjectRepository(TournamentTeam)
    private readonly tournamentTeamRepo: Repository<TournamentTeam>,
    @InjectRepository(TeamPlayer) private readonly teamPlayerRepo: Repository<TeamPlayer>,
    @InjectRepository(Ball) private readonly ballRepo: Repository<Ball>,
    @InjectRepository(Innings) private readonly inningsRepo: Repository<Innings>,
    @InjectRepository(Match) private readonly matchRepo: Repository<Match>,
    private readonly notificationsService: NotificationsService,
  ) {}

  async create(organizationId: string, dto: CreatePlayerDto): Promise<Player> {
    return this.playerRepo.save(
      this.playerRepo.create({
        ...dto,
        organizationId,
        basePrice: dto.basePrice !== undefined ? dto.basePrice.toFixed(2) : null,
      }),
    );
  }

  async findAll(organizationId: string): Promise<Player[]> {
    return findManyOrgScoped(this.playerRepo, organizationId);
  }

  async findOne(organizationId: string, playerId: string): Promise<Player> {
    const player = await findOneOrgScoped(this.playerRepo, organizationId, { id: playerId });
    if (!player) {
      throw new NotFoundException('Player not found');
    }
    return player;
  }

  async remove(organizationId: string, playerId: string): Promise<void> {
    const player = await this.findOne(organizationId, playerId);
    await this.playerRepo.remove(player);
  }

  async update(organizationId: string, playerId: string, dto: UpdatePlayerDto): Promise<Player> {
    const player = await this.findOne(organizationId, playerId);
    Object.assign(player, {
      ...dto,
      basePrice: dto.basePrice !== undefined ? dto.basePrice.toFixed(2) : player.basePrice,
    });
    return this.playerRepo.save(player);
  }

  /**
   * Admin approval workflow — moves a player through the 4-stage
   * verification flow: PENDING -> VERIFIED -> APPROVED, with REJECTED
   * reachable from PENDING or VERIFIED (but not from APPROVED — once fully
   * cleared, rejecting doesn't fit this flow). PENDING is never a valid
   * transition target. Deliberately a flat allow-list rather than a full
   * state machine — simplest thing that documents and enforces the rules.
   */
  private static readonly ALLOWED_VERIFICATION_TRANSITIONS: Record<
    PlayerVerificationStatus,
    PlayerVerificationStatus[]
  > = {
    [PlayerVerificationStatus.PENDING]: [
      PlayerVerificationStatus.VERIFIED,
      PlayerVerificationStatus.REJECTED,
    ],
    [PlayerVerificationStatus.VERIFIED]: [
      PlayerVerificationStatus.APPROVED,
      PlayerVerificationStatus.REJECTED,
    ],
    [PlayerVerificationStatus.APPROVED]: [],
    [PlayerVerificationStatus.REJECTED]: [],
  };

  async setVerification(
    organizationId: string,
    playerId: string,
    dto: VerifyPlayerDto,
  ): Promise<Player> {
    if (dto.status === PlayerVerificationStatus.PENDING) {
      throw new BadRequestException('Cannot set verification status back to pending');
    }
    const player = await this.findOne(organizationId, playerId);

    const allowedNext = PlayersService.ALLOWED_VERIFICATION_TRANSITIONS[player.verificationStatus] ?? [];
    if (!allowedNext.includes(dto.status)) {
      throw new BadRequestException(
        `Cannot transition verification status from "${player.verificationStatus}" to "${dto.status}"`,
      );
    }

    player.verificationStatus = dto.status;
    player.verificationNote = dto.note ?? null;
    return this.playerRepo.save(player);
  }

  async setRating(organizationId: string, playerId: string, dto: RatePlayerDto): Promise<Player> {
    const player = await this.findOne(organizationId, playerId);
    player.rating = dto.rating.toFixed(2);
    return this.playerRepo.save(player);
  }

  /** Adds an org-level player to a tournament-team's roster (creates the team_players row). */
  async addToRoster(
    organizationId: string,
    playerId: string,
    tournamentTeamId: string,
    dto: AddToRosterDto,
  ): Promise<TeamPlayer> {
    const player = await this.findOne(organizationId, playerId);

    // tournament_teams doesn't carry organization_id directly — verify tenancy
    // by joining through its tournament. 'team' is also joined so a
    // team_selection notification (below) can name the team without a
    // second round trip.
    const tournamentTeam = await this.tournamentTeamRepo.findOne({
      where: { id: tournamentTeamId },
      relations: ['tournament', 'team'],
    });
    if (!tournamentTeam || tournamentTeam.tournament.organizationId !== organizationId) {
      throw new NotFoundException('Tournament team not found');
    }

    const existing = await this.teamPlayerRepo.findOne({
      where: { tournamentTeamId, playerId },
    });
    if (existing) {
      throw new ConflictException('Player is already on this tournament-team roster');
    }

    const teamPlayer = await this.teamPlayerRepo.save(
      this.teamPlayerRepo.create({
        tournamentTeamId,
        playerId,
        jerseyNumber: dto.jerseyNumber ?? null,
        isCaptain: dto.isCaptain ?? false,
        isWicketkeeper: dto.isWicketkeeper ?? false,
        acquisitionType: dto.acquisitionType,
        acquiredPrice: dto.acquiredPrice !== undefined ? dto.acquiredPrice.toFixed(2) : null,
      }),
    );

    // Many players aren't linked to a login account (Player.userId is
    // nullable — see player.entity.ts) — skip silently when there's nobody
    // to notify, per spec.
    if (player.userId) {
      await this.notificationsService.notify(organizationId, [player.userId], {
        type: NotificationType.TEAM_SELECTION,
        title: 'Added to team roster',
        message: `You have been added to ${tournamentTeam.team?.name ?? 'a team'}'s roster.`,
        relatedEntityType: 'tournament_team',
        relatedEntityId: tournamentTeamId,
      });
    }

    return teamPlayer;
  }

  /**
   * Backs the Quick Match "Add via phone number" roster flow — finds an
   * existing org player by phone (normalized the same way
   * AuthService/UsersService store it, so formatting doesn't matter), or
   * creates a minimal one (role defaults to BATSMAN, editable later via
   * the normal player profile — asking for a role at this quick-add step
   * would defeat the point of it being quick), then adds them straight to
   * the roster via the exact same addToRoster path as the full flow.
   */
  async quickAddByPhone(
    organizationId: string,
    tournamentTeamId: string,
    dto: QuickAddPlayerDto,
  ): Promise<TeamPlayer> {
    const normalizedPhone = SmsService.normalizePhone(dto.phone);
    let player = await findOneOrgScoped(this.playerRepo, organizationId, { phone: normalizedPhone });

    if (!player) {
      player = await this.playerRepo.save(
        this.playerRepo.create({
          organizationId,
          fullName: dto.fullName?.trim() || normalizedPhone,
          phone: normalizedPhone,
          role: PlayerRole.BATSMAN,
        }),
      );
    }

    return this.addToRoster(organizationId, player.id, tournamentTeamId, {});
  }

  // ---------------------------------------------------------------------
  // Player statistics (career/cross-match aggregation) — computed on read,
  // same philosophy as TournamentsService.getPointsTable: nothing here is
  // persisted, everything is rebuilt from the `balls` table (the scoring
  // engine's single source of truth — see ScoringRealtimeService's class
  // doc) every time this is called.
  //
  // `isLegalBall`/`bowlerChargedRuns` below are deliberately duplicated
  // (not imported) from ScoringRealtimeService's private helpers of the
  // same name — that service keeps them private by design, and
  // TournamentsService already establishes the "small pure helper
  // duplicated across services rather than a shared import" precedent in
  // this codebase (see its own private static `toDecimalOvers`).
  // ---------------------------------------------------------------------

  /** Wide/no-ball don't count as a faced/legal delivery; every other delivery does. Mirrors ScoringRealtimeService.isLegalBall. */
  private static isLegalBall(ball: Pick<Ball, 'extraType'>): boolean {
    return ball.extraType !== ExtraType.WIDE && ball.extraType !== ExtraType.NO_BALL;
  }

  /** Runs charged to the bowler's figures — excludes byes/leg-byes. Mirrors ScoringRealtimeService.bowlerChargedRuns. */
  private static bowlerChargedRuns(ball: Pick<Ball, 'extraType' | 'runsBatter' | 'runsExtra'>): number {
    if (ball.extraType === ExtraType.BYE || ball.extraType === ExtraType.LEG_BYE) return 0;
    return ball.runsBatter + ball.runsExtra;
  }

  /**
   * A player is considered "dismissed" for batting-average purposes for
   * every DismissalType except RETIRED_HURT — standard cricket convention:
   * a retired-hurt innings is not out (the batter didn't get out, they left
   * the field), so it must not deflate the average the way a genuine
   * dismissal (including a run-out, which DOES count against the batter's
   * average despite not being bowler-credited) does.
   */
  private static countsAsDismissalForAverage(dismissalType: DismissalType | null): boolean {
    return !!dismissalType && dismissalType !== DismissalType.RETIRED_HURT;
  }

  /**
   * Aggregates one player's career figures across every `completed` match
   * they've appeared in, via ANY of their `team_player` rows (an org-level
   * Player can have many TeamPlayer rows — one per tournament-team roster
   * they've ever joined, possibly across many tournaments in this org).
   *
   * Query shape (kept to a handful of batch queries, not one per match):
   *   1. Resolve every TeamPlayer id belonging to this player, scoped to
   *      this org (join team_players -> tournament_teams -> tournaments).
   *   2. ONE query for every non-voided Ball row, in any COMPLETED match,
   *      where the player appears in ANY of strikerTeamPlayerId /
   *      nonStrikerTeamPlayerId / bowlerTeamPlayerId / dismissedTeamPlayerId
   *      / fielderTeamPlayerId. Because a whole over's ball rows all share
   *      the same bowlerTeamPlayerId, and a whole batting innings' "am I
   *      out" ball is captured via dismissedTeamPlayerId regardless of who
   *      was on strike for that specific ball (e.g. a non-striker run-out),
   *      this single filtered set is a COMPLETE picture of the player's
   *      involvement — no follow-up per-innings/per-match ball query is
   *      needed.
   *   3. ONE query for the distinct Innings rows touched (to map ball ->
   *      match, and get inningsNumber) and ONE query for the distinct Match
   *      rows touched (with team/tournament relations, for match history
   *      display). Both are `WHERE id IN (...)` batches, not N+1 loops.
   */
  async getStatistics(organizationId: string, playerId: string): Promise<PlayerStatisticsResponse> {
    await this.findOne(organizationId, playerId); // 404s + tenant-scopes

    const teamPlayers = await this.teamPlayerRepo
      .createQueryBuilder('tp')
      .innerJoin('tp.tournamentTeam', 'tt')
      .innerJoin('tt.tournament', 't')
      .where('tp.playerId = :playerId', { playerId })
      .andWhere('t.organizationId = :organizationId', { organizationId })
      .getMany();

    const emptyResponse: PlayerStatisticsResponse = {
      playerId,
      summary: { matchesPlayed: 0, totalRuns: 0, timesOut: 0, battingAverage: null, strikeRate: 0, totalWickets: 0, bowlingEconomy: null },
      batting: {
        innings: 0,
        runs: 0,
        ballsFaced: 0,
        highestScore: 0,
        highestScoreNotOut: false,
        fifties: 0,
        hundreds: 0,
        fours: 0,
        sixes: 0,
        timesOut: 0,
        average: null,
        strikeRate: 0,
      },
      bowling: { innings: 0, overs: '0.0', runsConceded: 0, wickets: 0, bestBowling: null, average: null, economy: null, maidens: 0 },
      fielding: { catches: 0, runOuts: 0, stumpings: 0 },
      matchHistory: [],
    };
    if (teamPlayers.length === 0) {
      return emptyResponse;
    }

    const teamPlayerIds = teamPlayers.map((tp) => tp.id);
    const teamPlayerIdSet = new Set(teamPlayerIds);
    const playerTournamentTeamIds = new Set(teamPlayers.map((tp) => tp.tournamentTeamId));

    const balls = await this.ballRepo
      .createQueryBuilder('b')
      .innerJoin('b.innings', 'i')
      .innerJoin('i.match', 'm')
      .where('m.status = :completed', { completed: MatchStatus.COMPLETED })
      .andWhere('b.voided = false')
      .andWhere(
        new Brackets((qb) => {
          qb.where('b.strikerTeamPlayerId IN (:...teamPlayerIds)', { teamPlayerIds })
            .orWhere('b.nonStrikerTeamPlayerId IN (:...teamPlayerIds)', { teamPlayerIds })
            .orWhere('b.bowlerTeamPlayerId IN (:...teamPlayerIds)', { teamPlayerIds })
            .orWhere('b.dismissedTeamPlayerId IN (:...teamPlayerIds)', { teamPlayerIds })
            .orWhere('b.fielderTeamPlayerId IN (:...teamPlayerIds)', { teamPlayerIds });
        }),
      )
      .getMany();

    if (balls.length === 0) {
      return emptyResponse;
    }

    const ballsByInnings = new Map<string, Ball[]>();
    for (const b of balls) {
      const list = ballsByInnings.get(b.inningsId) ?? [];
      list.push(b);
      ballsByInnings.set(b.inningsId, list);
    }

    const inningsRows = await this.inningsRepo.find({ where: { id: In([...ballsByInnings.keys()]) } });

    interface MatchAgg {
      matchId: string;
      catches: number;
      runOuts: number;
      stumpings: number;
      batting: {
        runs: number;
        ballsFaced: number;
        fours: number;
        sixes: number;
        isOut: boolean;
        dismissalType: DismissalType | null;
        strikeRate: number;
      } | null;
      bowling: { legalBalls: number; runsConceded: number; wickets: number; maidens: number } | null;
    }
    const matchAggByMatchId = new Map<string, MatchAgg>();
    const getMatchAgg = (matchId: string): MatchAgg => {
      let agg = matchAggByMatchId.get(matchId);
      if (!agg) {
        agg = { matchId, catches: 0, runOuts: 0, stumpings: 0, batting: null, bowling: null };
        matchAggByMatchId.set(matchId, agg);
      }
      return agg;
    };

    // Career-wide accumulators (summed across every innings below).
    let battingInningsCount = 0;
    let careerRuns = 0;
    let careerBallsFaced = 0;
    let careerFours = 0;
    let careerSixes = 0;
    let careerTimesOut = 0;
    let highestScore = 0;
    let highestScoreNotOut = false;
    let fifties = 0;
    let hundreds = 0;

    let bowlingInningsCount = 0;
    let careerRunsConceded = 0;
    let careerLegalBallsBowled = 0;
    let careerWickets = 0;
    let careerMaidens = 0;
    let bestBowling: { wickets: number; runsConceded: number } | null = null;

    let careerCatches = 0;
    let careerRunOuts = 0;
    let careerStumpings = 0;

    for (const innings of inningsRows) {
      const inningsBalls = ballsByInnings.get(innings.id) ?? [];
      const agg = getMatchAgg(innings.matchId);

      // --- Batting (only ball rows where the player was on strike credit runs to them) ---
      const battingBalls = inningsBalls.filter((b) => teamPlayerIdSet.has(b.strikerTeamPlayerId));
      const participatedBatting = inningsBalls.some(
        (b) => teamPlayerIdSet.has(b.strikerTeamPlayerId) || teamPlayerIdSet.has(b.nonStrikerTeamPlayerId),
      );
      if (participatedBatting) {
        const runs = battingBalls.reduce((sum, b) => sum + b.runsBatter, 0);
        // ballsFaced excludes only wides (a no-ball is still a faced delivery) — matches
        // ScoringRealtimeService.battingFiguresFor's `extraType !== ExtraType.WIDE` rule exactly.
        const ballsFaced = battingBalls.filter((b) => b.extraType !== ExtraType.WIDE).length;
        const fours = battingBalls.filter((b) => b.runsBatter === 4).length;
        const sixes = battingBalls.filter((b) => b.runsBatter === 6).length;
        const dismissalBall = inningsBalls.find((b) => b.isWicket && b.dismissedTeamPlayerId && teamPlayerIdSet.has(b.dismissedTeamPlayerId));
        const dismissalType = dismissalBall?.dismissalType ?? null;
        const isOut = PlayersService.countsAsDismissalForAverage(dismissalType);
        const strikeRate = ballsFaced > 0 ? Number(((runs / ballsFaced) * 100).toFixed(2)) : 0;

        battingInningsCount += 1;
        careerRuns += runs;
        careerBallsFaced += ballsFaced;
        careerFours += fours;
        careerSixes += sixes;
        if (isOut) careerTimesOut += 1;
        // A strictly higher score always wins. A tying score only upgrades
        // the not-out flag (matching the real-world convention that "87*"
        // outranks a plain "87") — it never displaces a genuinely higher score.
        if (runs > highestScore) {
          highestScore = runs;
          highestScoreNotOut = !isOut;
        } else if (runs === highestScore && !isOut) {
          highestScoreNotOut = true;
        }
        if (runs >= 100) hundreds += 1;
        else if (runs >= 50) fifties += 1;

        agg.batting = { runs, ballsFaced, fours, sixes, isOut, dismissalType, strikeRate };
      }

      // --- Bowling (every ball in an over they bowled shares their bowlerTeamPlayerId) ---
      const bowlingBalls = inningsBalls.filter((b) => teamPlayerIdSet.has(b.bowlerTeamPlayerId));
      if (bowlingBalls.length > 0) {
        const legalBalls = bowlingBalls.filter((b) => PlayersService.isLegalBall(b)).length;
        const runsConceded = bowlingBalls.reduce((sum, b) => sum + PlayersService.bowlerChargedRuns(b), 0);
        const wickets = bowlingBalls.filter((b) => b.isWicket && b.dismissalType !== DismissalType.RUN_OUT).length;

        const byOver = new Map<string, Ball[]>();
        for (const b of bowlingBalls) {
          const list = byOver.get(b.overId) ?? [];
          list.push(b);
          byOver.set(b.overId, list);
        }
        let maidens = 0;
        for (const overBalls of byOver.values()) {
          const overLegal = overBalls.filter((b) => PlayersService.isLegalBall(b)).length;
          const overRuns = overBalls.reduce((sum, b) => sum + PlayersService.bowlerChargedRuns(b), 0);
          if (overLegal >= 6 && overRuns === 0) maidens += 1;
        }

        bowlingInningsCount += 1;
        careerRunsConceded += runsConceded;
        careerLegalBallsBowled += legalBalls;
        careerWickets += wickets;
        careerMaidens += maidens;
        if (!bestBowling || wickets > bestBowling.wickets || (wickets === bestBowling.wickets && runsConceded < bestBowling.runsConceded)) {
          bestBowling = { wickets, runsConceded };
        }

        agg.bowling = {
          legalBalls,
          runsConceded,
          wickets,
          maidens,
        };
      }

      // --- Fielding (independent of who batted/bowled this ball) ---
      const fieldingBalls = inningsBalls.filter((b) => b.fielderTeamPlayerId && teamPlayerIdSet.has(b.fielderTeamPlayerId));
      const catches = fieldingBalls.filter((b) => b.dismissalType === DismissalType.CAUGHT).length;
      const runOuts = fieldingBalls.filter((b) => b.dismissalType === DismissalType.RUN_OUT).length;
      const stumpings = fieldingBalls.filter((b) => b.dismissalType === DismissalType.STUMPED).length;
      agg.catches += catches;
      agg.runOuts += runOuts;
      agg.stumpings += stumpings;
      careerCatches += catches;
      careerRunOuts += runOuts;
      careerStumpings += stumpings;
    }

    const matchIds = [...matchAggByMatchId.keys()];
    const matches = await this.matchRepo.find({
      where: { id: In(matchIds) },
      relations: ['homeTournamentTeam', 'homeTournamentTeam.team', 'awayTournamentTeam', 'awayTournamentTeam.team'],
    });
    const matchById = new Map(matches.map((m) => [m.id, m]));

    const matchHistory: PlayerMatchHistoryEntry[] = [];
    for (const agg of matchAggByMatchId.values()) {
      const match = matchById.get(agg.matchId);
      if (!match) continue; // defensive: shouldn't happen, every innings belongs to a match

      const playerTournamentTeamId =
        (match.homeTournamentTeamId && playerTournamentTeamIds.has(match.homeTournamentTeamId) && match.homeTournamentTeamId) ||
        (match.awayTournamentTeamId && playerTournamentTeamIds.has(match.awayTournamentTeamId) && match.awayTournamentTeamId) ||
        null;
      const opponentTournamentTeamId =
        playerTournamentTeamId === match.homeTournamentTeamId ? match.awayTournamentTeamId : match.homeTournamentTeamId;

      const isTie = match.winnerTournamentTeamId === null && match.resultSummary === 'Match tied';
      const won = !playerTournamentTeamId || isTie ? (isTie ? false : null) : match.winnerTournamentTeamId === playerTournamentTeamId;

      const bowlingFigures = agg.bowling
        ? {
            overs: `${Math.floor(agg.bowling.legalBalls / 6)}.${agg.bowling.legalBalls % 6}`,
            runsConceded: agg.bowling.runsConceded,
            wickets: agg.bowling.wickets,
            maidens: agg.bowling.maidens,
            economy: agg.bowling.legalBalls > 0 ? Number((agg.bowling.runsConceded / (agg.bowling.legalBalls / 6)).toFixed(2)) : 0,
          }
        : null;

      matchHistory.push({
        matchId: match.id,
        tournamentId: match.tournamentId,
        scheduledAt: match.scheduledAt,
        playerTournamentTeamId,
        opponentTournamentTeamId,
        playerTeamName:
          (playerTournamentTeamId === match.homeTournamentTeamId ? match.homeTournamentTeam?.team?.name : match.awayTournamentTeam?.team?.name) ??
          'Unknown',
        opponentTeamName:
          (playerTournamentTeamId === match.homeTournamentTeamId ? match.awayTournamentTeam?.team?.name : match.homeTournamentTeam?.team?.name) ??
          'Unknown',
        resultSummary: match.resultSummary,
        won,
        batting: agg.batting,
        bowling: bowlingFigures,
        fielding: { catches: agg.catches, runOuts: agg.runOuts, stumpings: agg.stumpings },
      });
    }

    // Chronological ascending — falls back to Match.createdAt (always
    // present) when scheduledAt wasn't set, so the client's trend graph
    // still gets a stable order even for a bare TBD-scheduled match.
    matchHistory.sort((a, b) => {
      const matchA = matchById.get(a.matchId)!;
      const matchB = matchById.get(b.matchId)!;
      const tA = (a.scheduledAt ?? matchA.createdAt).getTime();
      const tB = (b.scheduledAt ?? matchB.createdAt).getTime();
      return tA - tB;
    });

    const battingAverage = careerTimesOut > 0 ? Number((careerRuns / careerTimesOut).toFixed(2)) : null;
    const careerStrikeRate = careerBallsFaced > 0 ? Number(((careerRuns / careerBallsFaced) * 100).toFixed(2)) : 0;
    const bowlingAverage = careerWickets > 0 ? Number((careerRunsConceded / careerWickets).toFixed(2)) : null;
    const bowlingEconomy = careerLegalBallsBowled > 0 ? Number((careerRunsConceded / (careerLegalBallsBowled / 6)).toFixed(2)) : null;

    return {
      playerId,
      summary: {
        matchesPlayed: matchAggByMatchId.size,
        totalRuns: careerRuns,
        timesOut: careerTimesOut,
        battingAverage,
        strikeRate: careerStrikeRate,
        totalWickets: careerWickets,
        bowlingEconomy,
      },
      batting: {
        innings: battingInningsCount,
        runs: careerRuns,
        ballsFaced: careerBallsFaced,
        highestScore,
        highestScoreNotOut,
        fifties,
        hundreds,
        fours: careerFours,
        sixes: careerSixes,
        timesOut: careerTimesOut,
        average: battingAverage,
        strikeRate: careerStrikeRate,
      },
      bowling: {
        innings: bowlingInningsCount,
        overs: `${Math.floor(careerLegalBallsBowled / 6)}.${careerLegalBallsBowled % 6}`,
        runsConceded: careerRunsConceded,
        wickets: careerWickets,
        bestBowling,
        average: bowlingAverage,
        economy: bowlingEconomy,
        maidens: careerMaidens,
      },
      fielding: { catches: careerCatches, runOuts: careerRunOuts, stumpings: careerStumpings },
      matchHistory,
    };
  }

  /**
   * Org-wide player leaderboard, sorted by `metric` (runs/wickets/average
   * descending — higher is better; economy ascending — lower is better) and
   * annotated with 1-based `position` numbers.
   *
   * Implementation note (deliberate tradeoff, documented for future
   * reference): this reuses `getStatistics` UNCHANGED, once per org player
   * (N calls), rather than writing a second, parallel aggregate SQL query
   * that computes every player's figures in one pass. The N-calls approach
   * is the simplest-possible-correct option — it can never drift out of
   * sync with `getStatistics`'s career-stat definitions (matchesPlayed,
   * battingAverage-null-handling, etc.), since there's only one
   * implementation of those rules to maintain. Its cost is O(players) round
   * trips to the DB instead of O(1); given this app's confirmed small data
   * volumes (per prior agents' investigation — small orgs, small rosters),
   * that's an acceptable, explicitly-not-premature-optimization choice. If
   * org sizes grow enough for this to matter, the fix is a single grouped
   * query mirroring getStatistics's Ball/Innings joins with a GROUP BY
   * playerId — not attempted here (YAGNI).
   *
   * Only players who have appeared in at least one completed match
   * (`matchesPlayed > 0`) are included — an org can accumulate many
   * registered-but-never-played players, and an all-zero/all-null row for
   * every one of them would just be noise at the bottom of every metric's
   * leaderboard.
   */
  async getRankings(
    organizationId: string,
    metric: RankingMetric = RankingMetric.RUNS,
    limit: number = DEFAULT_RANKINGS_LIMIT,
  ): Promise<PlayerRankingRow[]> {
    const players = await this.findAll(organizationId);
    if (players.length === 0) return [];

    // See method doc: N calls to getStatistics, not a bespoke aggregate query.
    const stats = await Promise.all(players.map((p) => this.getStatistics(organizationId, p.id)));

    const rows: PlayerRankingRow[] = players
      .map((p, idx) => {
        const s = stats[idx];
        return {
          position: 0, // assigned after sort, below
          playerId: p.id,
          playerName: p.fullName,
          matchesPlayed: s.summary.matchesPlayed,
          runs: s.summary.totalRuns,
          wickets: s.summary.totalWickets,
          average: s.summary.battingAverage,
          economy: s.summary.bowlingEconomy,
        };
      })
      .filter((row) => row.matchesPlayed > 0);

    const ascending = metric === RankingMetric.ECONOMY;
    rows.sort((a, b) => {
      const av = a[metric];
      const bv = b[metric];
      // Nulls (e.g. average with zero dismissals, economy with zero legal balls bowled)
      // always sort last, regardless of sort direction — an undefined figure is never
      // "the best" or "the worst" on a leaderboard, just not rankable on this metric.
      if (av === null && bv === null) return 0;
      if (av === null) return 1;
      if (bv === null) return -1;
      return ascending ? av - bv : bv - av;
    });

    return rows.slice(0, limit).map((row, index) => ({ ...row, position: index + 1 }));
  }
}
