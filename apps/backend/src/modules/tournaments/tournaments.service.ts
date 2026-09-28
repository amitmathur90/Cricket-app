import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { findManyOrgScoped, findOneOrgScoped } from '../../common/base/org-scoped.repository';
import { Ball, DismissalType, ExtraType } from '../../database/entities/ball.entity';
import { Innings } from '../../database/entities/innings.entity';
import { Match, MatchStatus } from '../../database/entities/match.entity';
import { Player } from '../../database/entities/player.entity';
import { TeamPlayer } from '../../database/entities/team-player.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { CreateTournamentDto } from './dto/create-tournament.dto';
import { UpdateTournamentDto } from './dto/update-tournament.dto';

/** Computed, request-time registration window state — never persisted. */
export enum RegistrationStatus {
  NOT_OPEN = 'not_open',
  OPEN = 'open',
  CLOSED = 'closed',
}

/** A `Tournament` entity plus fields computed at response time. */
export type TournamentResponse = Tournament & {
  teamsCount: number;
  registrationStatus: RegistrationStatus;
};

/** One team registered in a tournament — the id here IS the `tournamentTeamId` matches assign home/away to. */
export interface TournamentTeamSummary {
  tournamentTeamId: string;
  teamId: string;
  teamName: string;
  status: string;
}

/** One row of the computed (never persisted) points table — see `getPointsTable`. */
export interface PointsTableRow {
  tournamentTeamId: string;
  teamName: string;
  position: number;
  played: number;
  won: number;
  lost: number;
  tied: number;
  noResult: number;
  points: number;
  netRunRate: number;
}

/**
 * Standard cricket points convention (M1): 2 for a win, 1 for a tie, 1 for a
 * no-result, 0 for a loss. `Tournament.pointsSystem` is deliberately NOT
 * read here — per its own doc comment it's free-text notes for display, not
 * a machine-readable config, so the points formula is hard-coded instead.
 */
const POINTS_PER_WIN = 2;
const POINTS_PER_TIE = 1;
const POINTS_PER_NO_RESULT = 1;
const POINTS_PER_LOSS = 0;

// ---------------------------------------------------------------------
// Tournament awards — computed on read, same philosophy as getPointsTable
// above. See getAwards()'s doc comment for the full per-award methodology;
// the constants below are the two deliberately-simple, documented
// heuristics that drive it.
// ---------------------------------------------------------------------

/**
 * Informal cricket heuristic weighting one wicket as roughly equivalent to
 * 20 runs of batting contribution, used ONLY to rank "Player of the
 * Tournament" and (scoped to a single match) "Man of the Match". This is a
 * deliberate simplification, NOT an official ICC/BCCI formula — no single
 * universally-agreed all-rounder-contribution formula exists in real
 * cricket, and any composite is necessarily a judgment call. 20 was picked
 * because it's the most commonly cited informal ratio (a wicket in a
 * ~20-over-a-side game is "worth" about as much as a well-set batter's
 * 20-run cameo) — reasonable, not scientifically derived.
 */
const WICKET_RUN_WEIGHT = 20;

/**
 * Minimum runs AND wickets (both required, not either/or) for a player to
 * even be considered for "Best All-Rounder". Picked as reasonable minimums
 * for a typical local/club T20-ish tournament (a handful of matches) —
 * genuinely configurable-in-spirit constants, not derived from any external
 * standard, kept here (not buried inline) so a future tournament-size-aware
 * config could replace them without hunting through the method body.
 */
const ALL_ROUNDER_MIN_RUNS = 50;
const ALL_ROUNDER_MIN_WICKETS = 3;

/**
 * Regex proxy for "youth" signal inside `Player.ageCategory` — see
 * getAwards()'s "Emerging Player" section for why this free-text field is
 * the ONLY remotely-usable signal for that award in this data model, and
 * why it's still an honest best-effort rather than a rigorous definition.
 * Matches things like "U19", "U-16", "Under 19", "Junior", "Youth", "Colts".
 */
const YOUTH_AGE_CATEGORY_PATTERN = /\bu-?\d{1,2}\b|under[\s-]?\d{1,2}|junior|youth|colt/i;

/** One award's outcome — `winner` is null whenever there's genuinely no determinable winner; `reasoning` is always present and explains the formula/threshold used, or (when null) why no winner could be determined. */
export interface AwardResult {
  winner: {
    playerId: string;
    playerName: string;
    teamName: string;
    /** Human-readable stat line backing this award, e.g. "312 runs, 9 wkts (composite 492)". */
    value: string;
  } | null;
  reasoning: string;
}

/** One completed match's Man-of-the-Match entry — see getAwards() for the per-match composite definition. */
export interface MatchAwardEntry {
  matchId: string;
  playerId: string;
  playerName: string;
  teamName: string;
  value: string;
}

export interface TournamentAwardsResponse {
  playerOfTheTournament: AwardResult;
  manOfTheMatch: { reasoning: string; matches: MatchAwardEntry[] };
  bestBatsman: AwardResult;
  bestBowler: AwardResult;
  bestFielder: AwardResult;
  bestAllRounder: AwardResult;
  emergingPlayer: AwardResult;
  bestCaptain: AwardResult;
}

@Injectable()
export class TournamentsService {
  constructor(
    @InjectRepository(Tournament) private readonly tournamentRepo: Repository<Tournament>,
    @InjectRepository(TournamentTeam)
    private readonly tournamentTeamRepo: Repository<TournamentTeam>,
    @InjectRepository(Match) private readonly matchRepo: Repository<Match>,
    @InjectRepository(Innings) private readonly inningsRepo: Repository<Innings>,
    @InjectRepository(Ball) private readonly ballRepo: Repository<Ball>,
    @InjectRepository(TeamPlayer) private readonly teamPlayerRepo: Repository<TeamPlayer>,
    @InjectRepository(Player) private readonly playerRepo: Repository<Player>,
  ) {}

  // --- Ball-level helpers, duplicated (not imported) from ScoringRealtimeService's
  // private helpers of the same name — see PlayersService's identical precedent/doc
  // comment for why: that service keeps them private by design, and this codebase
  // already establishes "small pure helper duplicated across services" (this
  // class's own toDecimalOvers) rather than extracting a shared import. ---

  private static isLegalBall(ball: Pick<Ball, 'extraType'>): boolean {
    return ball.extraType !== ExtraType.WIDE && ball.extraType !== ExtraType.NO_BALL;
  }

  private static bowlerChargedRuns(ball: Pick<Ball, 'extraType' | 'runsBatter' | 'runsExtra'>): number {
    if (ball.extraType === ExtraType.BYE || ball.extraType === ExtraType.LEG_BYE) return 0;
    return ball.runsBatter + ball.runsExtra;
  }

  private static countsAsDismissalForAverage(dismissalType: DismissalType | null): boolean {
    return !!dismissalType && dismissalType !== DismissalType.RETIRED_HURT;
  }

  /**
   * Computes the registration window state for a tournament at the current
   * instant. `registrationOpensAt`/`registrationClosesAt` are date-only
   * columns (no time component), so each bound is widened to cover the
   * *entire* named day — opens-at is treated as that day's 00:00:00.000Z
   * and closes-at as that day's 23:59:59.999Z — so both the opening day and
   * the closing day themselves count as OPEN (inclusive on both ends).
   *
   * Boundary/precedence rules (deliberately chosen to resolve an ambiguity
   * in the source spec, which described "registrationOpensAt is null" as
   * both a NOT_OPEN condition and, combined with a null/future close date,
   * an OPEN condition — those can't both hold):
   *   - CLOSED takes precedence: if `registrationClosesAt` is set and now
   *     is after the end of that day, status is CLOSED regardless of the
   *     open date.
   *   - Otherwise NOT_OPEN: if `registrationOpensAt` is set and now is
   *     before the start of that day, status is NOT_OPEN.
   *   - Otherwise OPEN. This makes OPEN the default/fallback — an unset
   *     bound never blocks registration on its own (no opens date means
   *     "already open"; no closes date means "not yet closed"), which is
   *     the interpretation needed for the "opens null, closes null/future
   *     => open" case in the spec to be reachable at all.
   */
  static computeRegistrationStatus(
    tournament: Pick<Tournament, 'registrationOpensAt' | 'registrationClosesAt'>,
    now: Date = new Date(),
  ): RegistrationStatus {
    const { registrationOpensAt, registrationClosesAt } = tournament;

    if (registrationClosesAt) {
      const closesAtEndOfDay = new Date(`${registrationClosesAt}T23:59:59.999Z`);
      if (now > closesAtEndOfDay) {
        return RegistrationStatus.CLOSED;
      }
    }

    if (registrationOpensAt) {
      const opensAtStartOfDay = new Date(`${registrationOpensAt}T00:00:00.000Z`);
      if (now < opensAtStartOfDay) {
        return RegistrationStatus.NOT_OPEN;
      }
    }

    return RegistrationStatus.OPEN;
  }

  private toResponse(tournament: Tournament, teamsCount: number): TournamentResponse {
    return {
      ...tournament,
      teamsCount,
      registrationStatus: TournamentsService.computeRegistrationStatus(tournament),
    };
  }

  /** One aggregate GROUP BY query for every id, instead of a count-per-row loop. */
  private async getTeamsCountMap(tournamentIds: string[]): Promise<Map<string, number>> {
    if (tournamentIds.length === 0) {
      return new Map();
    }
    const rows = await this.tournamentTeamRepo
      .createQueryBuilder('tt')
      .select('tt.tournamentId', 'tournamentId')
      .addSelect('COUNT(*)', 'count')
      .where('tt.tournamentId IN (:...tournamentIds)', { tournamentIds })
      .groupBy('tt.tournamentId')
      .getRawMany<{ tournamentId: string; count: string }>();
    return new Map(rows.map((row) => [row.tournamentId, Number(row.count)]));
  }

  async create(
    organizationId: string,
    dto: CreateTournamentDto,
    createdByUserId: string,
  ): Promise<TournamentResponse> {
    const tournament = await this.tournamentRepo.save(
      this.tournamentRepo.create({
        ...dto,
        organizationId,
        createdByUserId,
        playerRegistrationFee:
          dto.playerRegistrationFee !== undefined ? dto.playerRegistrationFee.toFixed(2) : null,
        teamRegistrationFee:
          dto.teamRegistrationFee !== undefined ? dto.teamRegistrationFee.toFixed(2) : null,
      }),
    );
    return this.toResponse(tournament, 0);
  }

  async findAll(organizationId: string): Promise<TournamentResponse[]> {
    // Excludes the hidden per-org "Quick Match" pool tournament (see
    // Tournament.isQuickMatchPool's doc comment) — it's plumbing, never a
    // real tournament a client should list/manage.
    const tournaments = await findManyOrgScoped(this.tournamentRepo, organizationId, {
      isQuickMatchPool: false,
    });
    const teamsCountMap = await this.getTeamsCountMap(tournaments.map((t) => t.id));
    return tournaments.map((tournament) =>
      this.toResponse(tournament, teamsCountMap.get(tournament.id) ?? 0),
    );
  }

  async findOne(organizationId: string, tournamentId: string): Promise<TournamentResponse> {
    const tournament = await this.findOneEntity(organizationId, tournamentId);
    const teamsCount = await this.tournamentTeamRepo.count({ where: { tournamentId } });
    return this.toResponse(tournament, teamsCount);
  }

  /** Internal helper — returns the bare entity (no computed fields), for use by update/remove. */
  private async findOneEntity(organizationId: string, tournamentId: string): Promise<Tournament> {
    const tournament = await findOneOrgScoped(this.tournamentRepo, organizationId, {
      id: tournamentId,
    });
    if (!tournament) {
      throw new NotFoundException('Tournament not found');
    }
    return tournament;
  }

  async update(
    organizationId: string,
    tournamentId: string,
    dto: UpdateTournamentDto,
  ): Promise<TournamentResponse> {
    const tournament = await this.findOneEntity(organizationId, tournamentId);
    Object.assign(tournament, {
      ...dto,
      playerRegistrationFee:
        dto.playerRegistrationFee !== undefined
          ? dto.playerRegistrationFee.toFixed(2)
          : tournament.playerRegistrationFee,
      teamRegistrationFee:
        dto.teamRegistrationFee !== undefined
          ? dto.teamRegistrationFee.toFixed(2)
          : tournament.teamRegistrationFee,
    });
    const saved = await this.tournamentRepo.save(tournament);
    const teamsCount = await this.tournamentTeamRepo.count({ where: { tournamentId } });
    return this.toResponse(saved, teamsCount);
  }

  async remove(organizationId: string, tournamentId: string): Promise<void> {
    const tournament = await this.findOneEntity(organizationId, tournamentId);
    await this.tournamentRepo.remove(tournament);
  }

  /**
   * Lists a tournament's registered teams (`tournament_teams` rows joined to
   * `Team` for the display name). Exists so clients — the "Add/Edit match"
   * form in particular — can assign `home`/`awayTournamentTeamId` directly
   * without needing an auction session to exist first (previously the only
   * way the mobile app could resolve a tournament's teams was by reading its
   * most recent auction session's report, which meant a match couldn't be
   * given real teams until an auction had run).
   */
  async getTeams(organizationId: string, tournamentId: string): Promise<TournamentTeamSummary[]> {
    await this.findOneEntity(organizationId, tournamentId);
    const tournamentTeams = await this.tournamentTeamRepo.find({
      where: { tournamentId },
      relations: ['team'],
    });
    return tournamentTeams.map((tt) => ({
      tournamentTeamId: tt.id,
      teamId: tt.teamId,
      teamName: tt.team?.name ?? 'Unknown',
      status: tt.status,
    }));
  }

  /**
   * `Innings.totalOversBowled` is stored in cricket "overs.balls" notation
   * (e.g. "15.2" means 15 completed overs + 2 legal balls — see that
   * column's doc comment), NOT a true decimal. This converts it to a true
   * decimal over count (15 + 2/6 = 15.333...) for NRR arithmetic.
   */
  private static toDecimalOvers(oversNotation: string): number {
    const [wholeStr, ballsStr] = oversNotation.split('.');
    const whole = Number(wholeStr) || 0;
    const balls = ballsStr ? Number(ballsStr) || 0 : 0;
    return whole + balls / 6;
  }

  /**
   * Computes the points table (standings) for a tournament, entirely from
   * the current `matches`/`innings` rows — nothing is persisted, mirroring
   * `teamsCount`/`registrationStatus` above (compute-on-read from the
   * source of truth, not a materialized/cached table). Every registered
   * `TournamentTeam` gets a row, including teams that haven't played yet
   * (all-zero stats) and withdrawn teams (the spec doesn't call for
   * filtering those out of the standings display).
   *
   * Data-availability findings (documented per the task, not guessed):
   *  - `tied`: a completed match with a null `winnerTournamentTeamId` is
   *    unambiguous in this codebase — `ScoringRealtimeService.
   *    applyMatchCompletionIfNeeded` sets `resultSummary` to the literal
   *    string `'Match tied'` in that exact case and no other. So a tie is
   *    detected as `winnerTournamentTeamId === null && resultSummary ===
   *    'Match tied'`.
   *  - `noResult`: there is currently NO distinct "abandoned / no result"
   *    concept anywhere in the match/innings/scoring model — a completed
   *    match's only two outcomes are "has a winner" or "tied" (see above).
   *    There is no washed-out-match or forfeit status on `Match` today. So
   *    `noResult` is always 0 for M1; the 1-point-per-no-result rule is
   *    still implemented (see `POINTS_PER_NO_RESULT`) so it activates for
   *    free the day such a status is introduced.
   *  - Groups (`TournamentGroup` / `tournament_teams.groupId`): populated
   *    at team-registration time (see `TeamsService.registerTeamToTournament`)
   *    but not read anywhere else in the codebase — no group-scoped
   *    standings/fixture endpoint exists yet. Building per-group tables here
   *    would be speculative, so this computes a single flat table for the
   *    whole tournament.
   *
   * NRR bowled-out rule (see the innings loop below): the "credit the full
   * allotted overs" adjustment for a side bowled out early is applied
   * symmetrically to BOTH sides of that one innings — the batting team's
   * overs-faced AND the bowling team's overs-bowled both take the SAME
   * credited value, because they describe the same physical innings. This
   * matches the real ICC convention ("overs which were to be bowled but
   * were not, due to a team being all out, count as complete overs for NRR
   * purposes" — a bowling-side framing, not just a batting-side one). It
   * is NOT applied when an innings ends short for any other reason (e.g.
   * the chasing team reaches its target early) — that case uses the overs
   * ACTUALLY bowled for both sides.
   */
  async getPointsTable(organizationId: string, tournamentId: string): Promise<PointsTableRow[]> {
    await this.findOneEntity(organizationId, tournamentId);

    const tournamentTeams = await this.tournamentTeamRepo.find({
      where: { tournamentId },
      relations: ['team'],
    });
    if (tournamentTeams.length === 0) {
      return [];
    }

    const completedMatches = await this.matchRepo.find({
      where: { tournamentId, status: MatchStatus.COMPLETED },
    });

    const inningsByMatch = new Map<string, Innings[]>();
    if (completedMatches.length > 0) {
      const matchIds = completedMatches.map((m) => m.id);
      const allInnings = await this.inningsRepo.find({ where: { matchId: In(matchIds) } });
      for (const innings of allInnings) {
        const list = inningsByMatch.get(innings.matchId) ?? [];
        list.push(innings);
        inningsByMatch.set(innings.matchId, list);
      }
    }

    interface Accum {
      played: number;
      won: number;
      lost: number;
      tied: number;
      noResult: number;
      runsScored: number;
      oversFaced: number;
      runsConceded: number;
      oversBowled: number;
    }
    const statsByTeamId = new Map<string, Accum>(
      tournamentTeams.map((tt) => [
        tt.id,
        { played: 0, won: 0, lost: 0, tied: 0, noResult: 0, runsScored: 0, oversFaced: 0, runsConceded: 0, oversBowled: 0 },
      ]),
    );

    for (const match of completedMatches) {
      if (!match.homeTournamentTeamId || !match.awayTournamentTeamId) {
        continue; // defensive: a completed match always has both teams assigned in practice
      }
      const inningsPair = inningsByMatch.get(match.id) ?? [];
      // A completed match always has exactly two innings (Match.status is
      // only ever set to `completed` by applyMatchCompletionIfNeeded, which
      // requires both innings 1 and 2 to exist and be completed) — this
      // guard is defensive, not an expected path.
      const isTie = match.winnerTournamentTeamId === null && match.resultSummary === 'Match tied';

      for (const teamId of [match.homeTournamentTeamId, match.awayTournamentTeamId]) {
        const acc = statsByTeamId.get(teamId);
        if (!acc) continue; // team no longer in tournament_teams (shouldn't happen; defensive)

        acc.played += 1;
        if (match.winnerTournamentTeamId === teamId) {
          acc.won += 1;
        } else if (isTie) {
          acc.tied += 1;
        } else {
          acc.lost += 1;
        }
      }

      // NRR: iterate the match's (up to 2) innings rows directly, rather
      // than per-team, because the "overs credited" for an innings is ONE
      // number shared by both sides of it — the standard ICC convention
      // credits the FULL allotted overs, symmetrically, to BOTH (a) the
      // batting team's "overs faced" AND (b) the bowling team's "overs
      // bowled" for that same innings, whenever the batting team was
      // bowled out (all out) before using its full quota. It is NOT
      // applied when an innings ends short for any other reason (e.g. the
      // chasing team in innings 2 reaches the target before its overs run
      // out) — that case is credited with the overs ACTUALLY bowled, for
      // both sides, same as a normal fully-played innings.
      for (const innings of inningsPair) {
        const actualOvers = TournamentsService.toDecimalOvers(innings.totalOversBowled);
        const wasBowledOut = innings.totalWickets >= 10;
        const oversCredited = wasBowledOut ? (match.oversLimit ?? actualOvers) : actualOvers;

        const battingAcc = statsByTeamId.get(innings.battingTournamentTeamId);
        if (battingAcc) {
          battingAcc.runsScored += innings.totalRuns;
          battingAcc.oversFaced += oversCredited;
        }
        const bowlingAcc = statsByTeamId.get(innings.bowlingTournamentTeamId);
        if (bowlingAcc) {
          bowlingAcc.runsConceded += innings.totalRuns;
          bowlingAcc.oversBowled += oversCredited;
        }
      }
    }

    const rows = tournamentTeams.map((tt) => {
      const acc = statsByTeamId.get(tt.id)!;
      const points =
        acc.won * POINTS_PER_WIN +
        acc.tied * POINTS_PER_TIE +
        acc.noResult * POINTS_PER_NO_RESULT +
        acc.lost * POINTS_PER_LOSS;
      const runRateFor = acc.oversFaced > 0 ? acc.runsScored / acc.oversFaced : 0;
      const runRateAgainst = acc.oversBowled > 0 ? acc.runsConceded / acc.oversBowled : 0;
      const netRunRate = Number((runRateFor - runRateAgainst).toFixed(2));
      return {
        tournamentTeamId: tt.id,
        teamName: tt.team?.name ?? 'Unknown',
        played: acc.played,
        won: acc.won,
        lost: acc.lost,
        tied: acc.tied,
        noResult: acc.noResult,
        points,
        netRunRate,
      };
    });

    rows.sort((a, b) => b.points - a.points || b.netRunRate - a.netRunRate);
    return rows.map((row, index) => ({ ...row, position: index + 1 }));
  }

  /**
   * Computes tournament awards — entirely on read, from every `completed`
   * match's ball log, exactly like `getPointsTable` computes standings from
   * `matches`/`innings`. Nothing here is persisted.
   *
   * === Aggregation shape ===
   * 1. Every completed Match for the tournament, then every Innings for
   *    those matches (`WHERE matchId IN (...)`), then every non-voided Ball
   *    for those innings (`WHERE inningsId IN (...)`) — three batch queries,
   *    not a per-match loop (mirrors PlayersService.getStatistics).
   * 2. Balls are folded into a per-`teamPlayerId` accumulator (runs,
   *    dismissals, bowling figures, fielding contributions) AND, separately,
   *    a per-match-per-teamPlayerId accumulator (runs, wickets only) used
   *    exclusively for Man of the Match.
   * 3. teamPlayerId accumulators are then rolled up to the org-level
   *    `playerId` (a player could in principle hold more than one
   *    `team_players` row within one tournament, e.g. a mid-tournament
   *    team change — summed together; the "representative" team/name shown
   *    is simply the first one encountered, a documented, harmless
   *    simplification for that rare edge case).
   *
   * === Player of the Tournament / Man of the Match ===
   * Composite = runs + wickets * WICKET_RUN_WEIGHT (see that constant's doc
   * — a deliberately simple, explicitly-not-official heuristic). Player of
   * the Tournament ranks every contributing player by this composite across
   * the WHOLE tournament. Man of the Match applies the identical formula but
   * scoped to one match's figures, and is returned as one entry PER
   * completed match (not a single tournament-wide value) because there is no
   * explicit "MOM" field on `Match` — see ScoringRealtimeService/Match
   * Center precedent — so this is the closest defensible on-read
   * equivalent, letting a client show "MOM" per fixture.
   * Tie-break for both (deterministic, applied in order): composite desc,
   * runs desc, wickets desc, player full name ascending.
   *
   * === Best Batsman / Best Bowler ===
   * Best Batsman: total tournament runs desc; ties broken by batting average
   * desc (a player never dismissed — average null — is treated as having the
   * best possible average, i.e. sorts first on a tie, matching the
   * real-world convention that an unbeaten record is at least as good as any
   * finite average). Best Bowler: total tournament wickets desc; ties broken
   * by economy asc (lower is better; a null economy — no legal ball ever
   * bowled, only possible if their only "wicket" came off an illegal
   * delivery, e.g. a stumping off a wide — is treated as the WORST economy
   * so it never wins a tie it has no real figures to justify).
   *
   * === Best Fielder ===
   * catches + run-outs + stumpings (as fielder, i.e. `fielderTeamPlayerId`)
   * desc, reusing the exact fielding-figures logic pattern from
   * PlayersService.getStatistics, scoped to this tournament's balls only.
   * Ties broken by catches desc, then run-outs desc.
   *
   * === Best All-Rounder ===
   * Requires BOTH runs >= ALL_ROUNDER_MIN_RUNS AND wickets >=
   * ALL_ROUNDER_MIN_WICKETS (see those constants' doc — deliberately simple,
   * documented thresholds, not derived from any external standard). Ranks
   * qualifying players by the same composite as Player of the Tournament. If
   * NO player meets both thresholds, `winner` is null — this deliberately
   * does NOT fall back to "best of a bad set" (e.g. whoever came closest),
   * because that would silently misrepresent a genuine all-rounder
   * performance that didn't happen this tournament.
   *
   * === Emerging Player — data-availability finding (documented, not guessed) ===
   * This app's data model has no "age", "years of experience", or
   * "first tournament" concept that reliably identifies an emerging/young
   * player: `Player.dob` is optional and frequently unpopulated (see
   * CreatePlayerDto — `dob` is `@IsOptional`), and there is no
   * caps/appearances-across-time counter anywhere. The only field that
   * exists specifically to categorize a player by age-ish cohort is
   * `Player.ageCategory` — required at registration (CreatePlayerDto marks
   * it `@IsNotEmpty`) but genuinely free text ("U19", "Open", "Senior B",
   * etc. are all valid values — see player.entity.ts's own doc comment
   * calling out its personal-info fields as "deliberately not enums, to
   * avoid being prescriptive"). Given that, this uses `ageCategory` matched
   * against `YOUTH_AGE_CATEGORY_PATTERN` (U-number / "under N" / junior /
   * youth / colt, case-insensitive) as the best-effort proxy signal, and is
   * explicit that this is exactly that — a proxy, not a rigorous
   * definition. Among tournament participants whose ageCategory matches,
   * the player is ranked by the Player-of-the-Tournament composite. If NO
   * participant's ageCategory matches the pattern, `winner` is null with a
   * reasoning string explaining why, rather than fabricating a definition
   * (e.g. falling back to "youngest by dob" would silently exclude every
   * player who didn't supply a dob, which is most of them in practice).
   *
   * === Best Captain ===
   * Among `TeamPlayer.isCaptain = true` rows for this tournament's teams,
   * the winner is the captain of whichever team has the best (numerically
   * lowest) `position` in `getPointsTable`'s computed standings — captaincy
   * is judged on team results, not personal batting/bowling figures, so no
   * other tie-break is needed (points-table position is already a strict
   * total order). `winner` is null if no team in the tournament has a
   * designated captain.
   */
  async getAwards(organizationId: string, tournamentId: string): Promise<TournamentAwardsResponse> {
    await this.findOneEntity(organizationId, tournamentId);

    const noCompletedMatches = (): TournamentAwardsResponse => {
      const emptyReasoning = 'No completed matches in this tournament yet — no figures to rank.';
      const empty: AwardResult = { winner: null, reasoning: emptyReasoning };
      return {
        playerOfTheTournament: empty,
        manOfTheMatch: { reasoning: emptyReasoning, matches: [] },
        bestBatsman: empty,
        bestBowler: empty,
        bestFielder: empty,
        bestAllRounder: empty,
        emergingPlayer: empty,
        bestCaptain: empty,
      };
    };

    const completedMatches = await this.matchRepo.find({
      where: { tournamentId, status: MatchStatus.COMPLETED },
    });
    if (completedMatches.length === 0) {
      return noCompletedMatches();
    }
    const matchIds = completedMatches.map((m) => m.id);

    const inningsRows = await this.inningsRepo.find({ where: { matchId: In(matchIds) } });
    if (inningsRows.length === 0) {
      return noCompletedMatches();
    }
    const inningsIdToMatchId = new Map(inningsRows.map((i) => [i.id, i.matchId]));

    const balls = await this.ballRepo.find({
      where: { inningsId: In([...inningsIdToMatchId.keys()]), voided: false },
    });
    if (balls.length === 0) {
      return noCompletedMatches();
    }

    interface TpAgg {
      runs: number;
      timesOut: number;
      wickets: number;
      runsConceded: number;
      legalBalls: number;
      catches: number;
      runOuts: number;
      stumpings: number;
      batted: boolean;
      bowled: boolean;
    }
    const newTpAgg = (): TpAgg => ({
      runs: 0,
      timesOut: 0,
      wickets: 0,
      runsConceded: 0,
      legalBalls: 0,
      catches: 0,
      runOuts: 0,
      stumpings: 0,
      batted: false,
      bowled: false,
    });
    const tpAgg = new Map<string, TpAgg>();
    const getTp = (teamPlayerId: string): TpAgg => {
      let agg = tpAgg.get(teamPlayerId);
      if (!agg) {
        agg = newTpAgg();
        tpAgg.set(teamPlayerId, agg);
      }
      return agg;
    };

    interface MatchTpAgg {
      runs: number;
      wickets: number;
    }
    // matchId -> teamPlayerId -> { runs, wickets } — for Man of the Match only.
    const matchTpAgg = new Map<string, Map<string, MatchTpAgg>>();
    const getMatchTp = (matchId: string, teamPlayerId: string): MatchTpAgg => {
      const perMatch = matchTpAgg.get(matchId) ?? new Map<string, MatchTpAgg>();
      matchTpAgg.set(matchId, perMatch);
      let agg = perMatch.get(teamPlayerId);
      if (!agg) {
        agg = { runs: 0, wickets: 0 };
        perMatch.set(teamPlayerId, agg);
      }
      return agg;
    };

    for (const b of balls) {
      const matchId = inningsIdToMatchId.get(b.inningsId)!;

      // --- Batting ---
      const strikerAgg = getTp(b.strikerTeamPlayerId);
      strikerAgg.batted = true;
      strikerAgg.runs += b.runsBatter;
      getMatchTp(matchId, b.strikerTeamPlayerId).runs += b.runsBatter;
      if (b.isWicket && b.dismissedTeamPlayerId && TournamentsService.countsAsDismissalForAverage(b.dismissalType)) {
        getTp(b.dismissedTeamPlayerId).timesOut += 1;
      }

      // --- Bowling ---
      const bowlerAgg = getTp(b.bowlerTeamPlayerId);
      bowlerAgg.bowled = true;
      if (TournamentsService.isLegalBall(b)) bowlerAgg.legalBalls += 1;
      bowlerAgg.runsConceded += TournamentsService.bowlerChargedRuns(b);
      if (b.isWicket && b.dismissalType !== DismissalType.RUN_OUT) {
        bowlerAgg.wickets += 1;
        getMatchTp(matchId, b.bowlerTeamPlayerId).wickets += 1;
      }

      // --- Fielding (independent of who batted/bowled this ball) ---
      if (b.fielderTeamPlayerId) {
        const fielderAgg = getTp(b.fielderTeamPlayerId);
        if (b.dismissalType === DismissalType.CAUGHT) fielderAgg.catches += 1;
        else if (b.dismissalType === DismissalType.RUN_OUT) fielderAgg.runOuts += 1;
        else if (b.dismissalType === DismissalType.STUMPED) fielderAgg.stumpings += 1;
      }
    }

    // Resolve every contributing teamPlayerId -> {playerId, playerName, tournamentTeamId} in one batch query.
    const teamPlayerRows = await this.teamPlayerRepo.find({
      where: { id: In([...tpAgg.keys()]) },
      relations: ['player'],
    });
    const tpMeta = new Map(teamPlayerRows.map((tp) => [tp.id, { playerId: tp.playerId, playerName: tp.player.fullName, tournamentTeamId: tp.tournamentTeamId }]));

    const tournamentTeams = await this.tournamentTeamRepo.find({ where: { tournamentId }, relations: ['team'] });
    const teamNameByTournamentTeamId = new Map(tournamentTeams.map((tt) => [tt.id, tt.team?.name ?? 'Unknown']));

    // Roll up teamPlayerId accumulators to org-level playerId (see class doc — rare
    // multi-teamPlayer-row-per-tournament edge case handled by summing, first team wins for display).
    interface PlayerAgg extends TpAgg {
      playerId: string;
      playerName: string;
      tournamentTeamId: string;
    }
    const playerAgg = new Map<string, PlayerAgg>();
    for (const [teamPlayerId, agg] of tpAgg) {
      const meta = tpMeta.get(teamPlayerId);
      if (!meta) continue; // defensive: shouldn't happen, every ball's teamPlayerId belongs to this tournament
      let p = playerAgg.get(meta.playerId);
      if (!p) {
        p = { ...newTpAgg(), playerId: meta.playerId, playerName: meta.playerName, tournamentTeamId: meta.tournamentTeamId };
        playerAgg.set(meta.playerId, p);
      }
      p.runs += agg.runs;
      p.timesOut += agg.timesOut;
      p.wickets += agg.wickets;
      p.runsConceded += agg.runsConceded;
      p.legalBalls += agg.legalBalls;
      p.catches += agg.catches;
      p.runOuts += agg.runOuts;
      p.stumpings += agg.stumpings;
      p.batted = p.batted || agg.batted;
      p.bowled = p.bowled || agg.bowled;
    }

    const composite = (p: Pick<PlayerAgg, 'runs' | 'wickets'>) => p.runs + p.wickets * WICKET_RUN_WEIGHT;
    const average = (p: Pick<PlayerAgg, 'runs' | 'timesOut'>): number | null =>
      p.timesOut > 0 ? Number((p.runs / p.timesOut).toFixed(2)) : null;
    const economy = (p: Pick<PlayerAgg, 'runsConceded' | 'legalBalls'>): number | null =>
      p.legalBalls > 0 ? Number((p.runsConceded / (p.legalBalls / 6)).toFixed(2)) : null;
    const nameCompare = (a: PlayerAgg, b: PlayerAgg) => a.playerName.localeCompare(b.playerName);

    const toWinner = (p: PlayerAgg, value: string): AwardResult['winner'] => ({
      playerId: p.playerId,
      playerName: p.playerName,
      teamName: teamNameByTournamentTeamId.get(p.tournamentTeamId) ?? 'Unknown',
      value,
    });

    const allPlayers = [...playerAgg.values()];

    // --- Player of the Tournament ---
    let playerOfTheTournament: AwardResult;
    {
      const candidates = [...allPlayers].sort(
        (a, b) => composite(b) - composite(a) || b.runs - a.runs || b.wickets - a.wickets || nameCompare(a, b),
      );
      const top = candidates[0];
      playerOfTheTournament = top
        ? {
            winner: toWinner(top, `${top.runs} runs, ${top.wickets} wkts (composite ${composite(top)})`),
            reasoning: `Composite score = runs + wickets * ${WICKET_RUN_WEIGHT} (a simple, deliberate heuristic — not an official ICC formula), ranked across every completed match in the tournament.`,
          }
        : { winner: null, reasoning: 'No player recorded any runs or wickets in this tournament.' };
    }

    // --- Man of the Match (per completed match) ---
    const momReasoning = `Same composite formula as Player of the Tournament (runs + wickets * ${WICKET_RUN_WEIGHT}), scoped to each individual match — there is no explicit "Man of the Match" field on Match in this data model, so this is the closest defensible on-read equivalent, one entry per completed match.`;
    const manOfTheMatchEntries: MatchAwardEntry[] = [];
    for (const matchId of matchIds) {
      const perMatch = matchTpAgg.get(matchId);
      if (!perMatch || perMatch.size === 0) continue; // defensive: a completed match always has ball data
      let best: { teamPlayerId: string; runs: number; wickets: number } | null = null;
      for (const [teamPlayerId, agg] of perMatch) {
        if (
          !best ||
          agg.runs + agg.wickets * WICKET_RUN_WEIGHT > best.runs + best.wickets * WICKET_RUN_WEIGHT ||
          (agg.runs + agg.wickets * WICKET_RUN_WEIGHT === best.runs + best.wickets * WICKET_RUN_WEIGHT &&
            (agg.runs > best.runs || (agg.runs === best.runs && agg.wickets > best.wickets)))
        ) {
          best = { teamPlayerId, ...agg };
        }
      }
      if (!best) continue;
      const meta = tpMeta.get(best.teamPlayerId);
      if (!meta) continue; // defensive
      manOfTheMatchEntries.push({
        matchId,
        playerId: meta.playerId,
        playerName: meta.playerName,
        teamName: teamNameByTournamentTeamId.get(meta.tournamentTeamId) ?? 'Unknown',
        value: `${best.runs} runs, ${best.wickets} wkts`,
      });
    }

    // --- Best Batsman ---
    let bestBatsman: AwardResult;
    {
      const candidates = allPlayers
        .filter((p) => p.batted)
        .sort((a, b) => {
          if (b.runs !== a.runs) return b.runs - a.runs;
          const avgA = average(a);
          const avgB = average(b);
          const effA = avgA ?? Infinity; // never-dismissed treated as best possible average
          const effB = avgB ?? Infinity;
          if (effA !== effB) return effB - effA;
          return nameCompare(a, b);
        });
      const top = candidates[0];
      bestBatsman = top
        ? {
            winner: toWinner(top, `${top.runs} runs (avg ${average(top) ?? '—'})`),
            reasoning: 'Highest total runs across every completed match in the tournament; batting average (runs / dismissals) is the tie-break, higher is better.',
          }
        : { winner: null, reasoning: 'No player recorded a batting appearance in this tournament.' };
    }

    // --- Best Bowler ---
    let bestBowler: AwardResult;
    {
      const candidates = allPlayers
        .filter((p) => p.bowled)
        .sort((a, b) => {
          if (b.wickets !== a.wickets) return b.wickets - a.wickets;
          const ecoA = economy(a);
          const ecoB = economy(b);
          const effA = ecoA ?? Infinity; // never bowled a legal ball treated as worst possible economy
          const effB = ecoB ?? Infinity;
          if (effA !== effB) return effA - effB;
          return nameCompare(a, b);
        });
      const top = candidates[0];
      bestBowler = top
        ? {
            winner: toWinner(top, `${top.wickets} wkts (econ ${economy(top) ?? '—'})`),
            reasoning: 'Most wickets across every completed match in the tournament; economy rate (runs conceded per over) is the tie-break, lower is better.',
          }
        : { winner: null, reasoning: 'No player recorded a bowling appearance in this tournament.' };
    }

    // --- Best Fielder ---
    let bestFielder: AwardResult;
    {
      const fieldingTotal = (p: PlayerAgg) => p.catches + p.runOuts + p.stumpings;
      const candidates = allPlayers
        .filter((p) => fieldingTotal(p) > 0)
        .sort((a, b) => fieldingTotal(b) - fieldingTotal(a) || b.catches - a.catches || b.runOuts - a.runOuts || nameCompare(a, b));
      const top = candidates[0];
      bestFielder = top
        ? {
            winner: toWinner(top, `${top.catches} catches, ${top.runOuts} run-outs, ${top.stumpings} stumpings (${fieldingTotal(top)} total)`),
            reasoning: 'Most (catches + run-outs + stumpings) credited as fielder across every completed match in the tournament.',
          }
        : { winner: null, reasoning: 'No fielding dismissal (catch, run-out, or stumping) was recorded in this tournament.' };
    }

    // --- Best All-Rounder ---
    let bestAllRounder: AwardResult;
    {
      const qualifiers = allPlayers
        .filter((p) => p.runs >= ALL_ROUNDER_MIN_RUNS && p.wickets >= ALL_ROUNDER_MIN_WICKETS)
        .sort((a, b) => composite(b) - composite(a) || b.runs - a.runs || nameCompare(a, b));
      const top = qualifiers[0];
      const reasoning = `Requires at least ${ALL_ROUNDER_MIN_RUNS} runs AND at least ${ALL_ROUNDER_MIN_WICKETS} wickets in the tournament to qualify (both thresholds, not either — deliberately simple, documented cutoffs, not an external standard); qualifiers are then ranked by the same composite as Player of the Tournament (runs + wickets * ${WICKET_RUN_WEIGHT}).`;
      bestAllRounder = top
        ? { winner: toWinner(top, `${top.runs} runs, ${top.wickets} wkts (composite ${composite(top)})`), reasoning }
        : {
            winner: null,
            reasoning: `${reasoning} No player met both thresholds this tournament — deliberately returning no winner rather than picking the "best of a bad set".`,
          };
    }

    // --- Emerging Player ---
    let emergingPlayer: AwardResult;
    {
      const baseReasoning =
        'This data model has no reliable "age"/"years of experience"/"first tournament" signal (Player.dob is optional and usually unpopulated; there is no caps/appearances-over-time counter). Best-effort proxy: Player.ageCategory (required free text, e.g. "U19", "Open", "Senior") matched against youth-indicating patterns (U-number, "under N", junior, youth, colt).';
      // Look up ageCategory directly from Player rows for every contributing player.
      const contributingPlayerIds = allPlayers.map((p) => p.playerId);
      const playerRows =
        contributingPlayerIds.length > 0 ? await this.playerRepo.find({ where: { id: In(contributingPlayerIds) } }) : [];
      const ageCategoryByPlayerId = new Map(playerRows.map((pl) => [pl.id, pl.ageCategory]));
      const qualifiers = allPlayers
        .filter((p) => {
          const ageCategory = ageCategoryByPlayerId.get(p.playerId);
          return !!ageCategory && YOUTH_AGE_CATEGORY_PATTERN.test(ageCategory);
        })
        .sort((a, b) => composite(b) - composite(a) || b.runs - a.runs || nameCompare(a, b));
      const top = qualifiers[0];
      emergingPlayer = top
        ? {
            winner: toWinner(top, `${top.runs} runs, ${top.wickets} wkts (ageCategory: "${ageCategoryByPlayerId.get(top.playerId)}")`),
            reasoning: `${baseReasoning} Among players whose ageCategory matched, ranked by the same composite as Player of the Tournament. This is a proxy, not a rigorous definition — treat with appropriate skepticism.`,
          }
        : {
            winner: null,
            reasoning: `${baseReasoning} No participant's ageCategory in this tournament matched a youth-indicating pattern, so no winner is returned rather than fabricating one (e.g. falling back to dob would silently exclude most players, who never supplied one).`,
          };
    }

    // --- Best Captain ---
    let bestCaptain: AwardResult;
    {
      const tournamentTeamIds = tournamentTeams.map((tt) => tt.id);
      const captainRows =
        tournamentTeamIds.length > 0
          ? await this.teamPlayerRepo.find({
              where: { tournamentTeamId: In(tournamentTeamIds), isCaptain: true },
              relations: ['player'],
            })
          : [];
      if (captainRows.length === 0) {
        bestCaptain = {
          winner: null,
          reasoning: 'No team in this tournament has a designated captain (TeamPlayer.isCaptain is false for every roster entry).',
        };
      } else {
        const pointsTable = await this.getPointsTable(organizationId, tournamentId);
        const positionByTournamentTeamId = new Map(pointsTable.map((row) => [row.tournamentTeamId, row.position]));
        const ranked = captainRows
          .map((cp) => ({ cp, position: positionByTournamentTeamId.get(cp.tournamentTeamId) ?? Number.MAX_SAFE_INTEGER }))
          .sort((a, b) => a.position - b.position);
        const best = ranked[0];
        const row = pointsTable.find((r) => r.tournamentTeamId === best.cp.tournamentTeamId);
        bestCaptain = {
          winner: {
            playerId: best.cp.playerId,
            playerName: best.cp.player.fullName,
            teamName: teamNameByTournamentTeamId.get(best.cp.tournamentTeamId) ?? 'Unknown',
            value: row
              ? `${row.teamName} finished #${row.position} (${row.points} pts, NRR ${row.netRunRate})`
              : `Team finished #${best.position}`,
          },
          reasoning: "Captain (TeamPlayer.isCaptain) of the tournament's highest-placed team in the points table — captaincy is judged on team results, not personal batting/bowling figures.",
        };
      }
    }

    return {
      playerOfTheTournament,
      manOfTheMatch: { reasoning: momReasoning, matches: manOfTheMatchEntries },
      bestBatsman,
      bestBowler,
      bestFielder,
      bestAllRounder,
      emergingPlayer,
      bestCaptain,
    };
  }
}
