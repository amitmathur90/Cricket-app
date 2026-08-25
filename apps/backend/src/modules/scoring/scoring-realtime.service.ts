import { BadRequestException, ForbiddenException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { EventEmitter } from 'events';
import { DataSource, EntityManager, In } from 'typeorm';
import { OrgRole } from '../../common/enums/org-role.enum';
import { AuthenticatedUser } from '../../common/types/authenticated-user';
import { Ball, DismissalType, ExtraType } from '../../database/entities/ball.entity';
import { Innings, InningsStatus } from '../../database/entities/innings.entity';
import { Match, MatchStatus } from '../../database/entities/match.entity';
import { MatchLineup, MatchLineupRole } from '../../database/entities/match-lineup.entity';
import { NotificationType } from '../../database/entities/notification.entity';
import { Over, OverStatus } from '../../database/entities/over.entity';
import { Partnership } from '../../database/entities/partnership.entity';
import { Player } from '../../database/entities/player.entity';
import { TeamPlayer } from '../../database/entities/team-player.entity';
import { Tournament, TournamentFormat } from '../../database/entities/tournament.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { NewBowlerDto } from './dto/new-bowler.dto';
import { RecordBallDto } from './dto/record-ball.dto';
import { StartInningsDto } from './dto/start-innings.dto';
import { StartMatchDto } from './dto/start-match.dto';

export type ScoringBroadcastEventType =
  | 'scoring.inningsStarted'
  | 'scoring.ballRecorded'
  | 'scoring.ballUndone'
  | 'scoring.newBowlerSet'
  | 'scoring.inningsCompleted'
  | 'scoring.matchCompleted'
  | 'scoring.stateSync';

export interface ScoringBroadcastEvent {
  type: ScoringBroadcastEventType;
  matchId: string;
  payload: unknown;
}

const SCORER_ROLES: OrgRole[] = [OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN, OrgRole.TEAM_OWNER, OrgRole.SCORER];

const FORMAT_DEFAULT_OVERS: Record<TournamentFormat, number> = {
  [TournamentFormat.T20]: 20,
  [TournamentFormat.ODI]: 50,
  [TournamentFormat.T10]: 10,
  [TournamentFormat.CUSTOM]: 20,
};

/**
 * Owns the server-authoritative scoring lifecycle for a match: starting the
 * match/first innings, recording/undoing balls, selecting bowlers, ending
 * innings, and completing the match — structurally mirroring
 * AuctionRealtimeService (see that file's doc comment for the rationale
 * behind the plain-EventEmitter broadcast bridge and the DB-row-lock
 * concurrency pattern, both reused here unchanged).
 *
 * === Core design: the ball log is the only source of truth ===
 *
 * `Innings.totalRuns/totalWickets/totalOversBowled/extrasTotal`,
 * `Over.runsConceded/wickets/isMaiden/status`, `Partnership.*`, and the
 * innings' "live cursor" (`currentStriker/currentNonStrikerTeamPlayerId`)
 * are never hand-mutated. Every one of them is rebuilt from scratch, on
 * every state change, by `recomputeInningsAggregates` — a single fold over
 * the innings' non-voided `Ball` rows in `sequenceNumber` order. Both
 * `recordBall` (insert one new Ball, then recompute) and `undoLastBall`
 * (void one Ball, then recompute) share this exact same recompute path, so
 * there is no separate "reverse" logic to keep in sync with the forward
 * logic — the single most common source of undo bugs in this kind of
 * system. This is safe because each `Ball` row is an immutable historical
 * fact once inserted (its striker/non-striker/bowler/runs/extras/wicket
 * fields are fixed at insert time and never rewritten) — see ball.entity.ts.
 *
 * === Concurrency ===
 *
 * Every mutation (`startMatch`, `startInnings`, `newBowler`, `recordBall`,
 * `undoLastBall`, `endInnings`) runs inside a DB transaction that
 * `SELECT ... FOR UPDATE`s the match row (before any innings exists) or the
 * relevant innings row (once one does) first — identical in spirit to
 * AuctionRealtimeService's session-row lock.
 */
@Injectable()
export class ScoringRealtimeService {
  private readonly logger = new Logger(ScoringRealtimeService.name);
  private readonly emitter = new EventEmitter();

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly notificationsService: NotificationsService,
  ) {
    this.emitter.setMaxListeners(50);
  }

  /**
   * Notifies both teams' owners (`Team.ownerUserId`) when a match completes
   * — called after commit, once `match.resultSummary` has been derived by
   * `applyMatchCompletionIfNeeded`. Mirrors MatchesService.notifyScheduleChange:
   * whichever owner(s) happen to be set get notified; no owner set on
   * either side is a silent no-op, not an error.
   */
  private async notifyMatchResult(organizationId: string, match: Match): Promise<void> {
    const tournamentTeamIds = [match.homeTournamentTeamId, match.awayTournamentTeamId].filter(
      (id): id is string => !!id,
    );
    if (tournamentTeamIds.length === 0) {
      return;
    }
    const tournamentTeams = await this.dataSource.manager.find(TournamentTeam, {
      where: { id: In(tournamentTeamIds) },
      relations: ['team'],
    });
    const ownerUserIds = tournamentTeams.map((tt) => tt.team?.ownerUserId).filter((id): id is string => !!id);
    await this.notificationsService.notify(organizationId, ownerUserIds, {
      type: NotificationType.MATCH_RESULT,
      title: 'Match result',
      message: match.resultSummary ?? 'The match has ended.',
      relatedEntityType: 'match',
      relatedEntityId: match.id,
    });
  }

  onBroadcast(handler: (evt: ScoringBroadcastEvent) => void): void {
    this.emitter.on('broadcast', handler);
  }

  private broadcast(evt: ScoringBroadcastEvent): void {
    this.emitter.emit('broadcast', evt);
  }

  // ---------------------------------------------------------------------
  // Auth / scoping helpers
  // ---------------------------------------------------------------------

  private assertOrgAccess(user: AuthenticatedUser, organizationId: string): void {
    if (user.isSuperAdmin) return;
    if (!user.activeOrgId || user.activeOrgId !== organizationId) {
      throw new ForbiddenException('Organization scope mismatch');
    }
  }

  private assertScorerRole(user: AuthenticatedUser): void {
    if (user.isSuperAdmin) return;
    if (!user.role || !SCORER_ROLES.includes(user.role)) {
      throw new ForbiddenException('Only team owners, scorers, or org/tournament admins may score a match');
    }
  }

  private async getOrgScopedMatch(manager: EntityManager, organizationId: string, matchId: string): Promise<Match> {
    const match = await manager.findOne(Match, { where: { id: matchId }, relations: ['tournament'] });
    if (!match || match.tournament.organizationId !== organizationId) {
      throw new NotFoundException('Match not found');
    }
    return match;
  }

  private async assertPlayingLineup(
    manager: EntityManager,
    matchId: string,
    tournamentTeamId: string,
    teamPlayerId: string,
    label: string,
  ): Promise<void> {
    const teamPlayer = await manager.findOne(TeamPlayer, { where: { id: teamPlayerId } });
    if (!teamPlayer || teamPlayer.tournamentTeamId !== tournamentTeamId) {
      throw new BadRequestException(`${label} must be a team_players row belonging to the correct team`);
    }
    const lineup = await manager.findOne(MatchLineup, {
      where: { matchId, teamPlayerId, role: MatchLineupRole.PLAYING },
    });
    if (!lineup) {
      throw new BadRequestException(`${label} must be part of this match's Playing XI`);
    }
  }

  // ---------------------------------------------------------------------
  // Ball-level cricket-rules helpers (pure functions over a Ball's fields)
  // ---------------------------------------------------------------------

  /** Splits a scorer-submitted `runs` count into batter/extra runs per the ball's extraType. */
  private splitRuns(runs: number, extraType: ExtraType | null): { runsBatter: number; runsExtra: number } {
    switch (extraType) {
      case ExtraType.WIDE:
        return { runsBatter: 0, runsExtra: 1 + runs };
      case ExtraType.NO_BALL:
        return { runsBatter: runs, runsExtra: 1 };
      case ExtraType.BYE:
      case ExtraType.LEG_BYE:
      case ExtraType.PENALTY:
        return { runsBatter: 0, runsExtra: runs };
      default:
        return { runsBatter: runs, runsExtra: 0 };
    }
  }

  /** Wide/no-ball don't advance the over; every other delivery (including byes/leg-byes) does. */
  private isLegalBall(ball: Pick<Ball, 'extraType'>): boolean {
    return ball.extraType !== ExtraType.WIDE && ball.extraType !== ExtraType.NO_BALL;
  }

  /** Runs conceded against the bowler's figures — excludes byes/leg-byes (never charged to the bowler). */
  private bowlerChargedRuns(ball: Pick<Ball, 'extraType' | 'runsBatter' | 'runsExtra'>): number {
    if (ball.extraType === ExtraType.BYE || ball.extraType === ExtraType.LEG_BYE) return 0;
    return ball.runsBatter + ball.runsExtra;
  }

  /** Runs that count toward strike-rotation (odd/even) — the runs actually run by the batters. */
  private rotationRuns(ball: Pick<Ball, 'extraType' | 'runsBatter' | 'runsExtra'>): number {
    switch (ball.extraType) {
      case ExtraType.WIDE:
        return 0; // simplification per spec: wides don't trigger rotation (byes-on-a-wide out of scope)
      case ExtraType.NO_BALL:
        return ball.runsBatter;
      case ExtraType.BYE:
      case ExtraType.LEG_BYE:
      case ExtraType.PENALTY:
        return ball.runsExtra;
      default:
        return ball.runsBatter;
    }
  }

  // ---------------------------------------------------------------------
  // The core recompute — see class doc.
  // ---------------------------------------------------------------------

  /**
   * Rebuilds Innings totals + live cursor, every Over's aggregate columns,
   * and every Partnership row for one innings, purely from its non-voided
   * Ball rows. Also derives (and persists) whether the innings should now
   * be `completed` (10 wickets / overs limit reached / — for innings 2 —
   * target reached) UNLESS it was already completed and this recompute is
   * running with `preserveIfManuallyCompleted: true` (used so an unrelated
   * ball edit doesn't silently reopen a manually-ended innings — see
   * `endInnings`).
   */
  private async recomputeInningsAggregates(
    manager: EntityManager,
    inningsId: string,
    opts: { preserveIfManuallyCompleted?: boolean } = {},
  ): Promise<Innings> {
    const innings = await manager.findOneOrFail(Innings, { where: { id: inningsId } });
    const match = await manager.findOneOrFail(Match, { where: { id: innings.matchId } });
    const balls = await manager.find(Ball, {
      where: { inningsId, voided: false },
      order: { sequenceNumber: 'ASC' },
    });
    const overs = await manager.find(Over, { where: { inningsId } });
    const overStats = new Map<string, { runsConceded: number; wickets: number; legalBalls: number }>();
    for (const o of overs) overStats.set(o.id, { runsConceded: 0, wickets: 0, legalBalls: 0 });

    let totalRuns = 0;
    let totalWickets = 0;
    let extrasTotal = 0;
    let legalBalls = 0;

    type OpenPartnership = { batter1: string; batter2: string; startSeq: number; runs: number; ballsFaced: number };
    let current: OpenPartnership | null = null;
    const closedPartnerships: Array<OpenPartnership & { endSeq: number | null }> = [];
    let lastBall: Ball | null = null;

    const pairKey = (a: string, b: string) => [a, b].sort().join('|');

    for (const ball of balls) {
      totalRuns += ball.runsBatter + ball.runsExtra;
      if (ball.extraType) extrasTotal += ball.runsExtra;
      if (ball.isWicket) totalWickets += 1;

      const legal = this.isLegalBall(ball);
      if (legal) legalBalls += 1;

      const os = overStats.get(ball.overId);
      if (os) {
        os.runsConceded += this.bowlerChargedRuns(ball);
        if (ball.isWicket) os.wickets += 1;
        if (legal) os.legalBalls += 1;
      }

      const key = pairKey(ball.strikerTeamPlayerId, ball.nonStrikerTeamPlayerId);
      if (!current || pairKey(current.batter1, current.batter2) !== key) {
        if (current) {
          closedPartnerships.push({ ...current, endSeq: lastBall!.sequenceNumber });
        }
        current = { batter1: ball.strikerTeamPlayerId, batter2: ball.nonStrikerTeamPlayerId, startSeq: ball.sequenceNumber, runs: 0, ballsFaced: 0 };
      }
      current.runs += ball.runsBatter + ball.runsExtra;
      if (legal) current.ballsFaced += 1;

      lastBall = ball;
    }
    if (current) {
      closedPartnerships.push({ ...current, endSeq: null });
    }

    // Persist Over aggregates (rows are never deleted — only their derived columns change).
    for (const o of overs) {
      const stats = overStats.get(o.id)!;
      o.runsConceded = stats.runsConceded;
      o.wickets = stats.wickets;
      o.status = stats.legalBalls >= 6 ? OverStatus.COMPLETED : OverStatus.IN_PROGRESS;
      o.isMaiden = o.status === OverStatus.COMPLETED && stats.runsConceded === 0;
    }
    if (overs.length > 0) {
      await manager.save(Over, overs);
    }

    // Partnerships are cheap to fully rebuild (an innings has at most a few dozen).
    await manager.delete(Partnership, { inningsId });
    if (closedPartnerships.length > 0) {
      await manager.insert(
        Partnership,
        closedPartnerships.map((p) => ({
          inningsId,
          batter1TeamPlayerId: p.batter1,
          batter2TeamPlayerId: p.batter2,
          startBallSequence: p.startSeq,
          endBallSequence: p.endSeq,
          runs: p.runs,
          ballsFaced: p.ballsFaced,
        })),
      );
    }

    // Live cursor: apply the rotation/dismissal/over-end effect of the last ball.
    let currentStriker: string | null = innings.currentStrikerTeamPlayerId;
    let currentNonStriker: string | null = innings.currentNonStrikerTeamPlayerId;
    if (lastBall) {
      let strikerEnd: string | null = lastBall.strikerTeamPlayerId;
      let nonStrikerEnd: string | null = lastBall.nonStrikerTeamPlayerId;

      if (this.rotationRuns(lastBall) % 2 === 1) {
        [strikerEnd, nonStrikerEnd] = [nonStrikerEnd, strikerEnd];
      }
      if (lastBall.isWicket) {
        const dismissedId = lastBall.dismissalType === DismissalType.RUN_OUT ? lastBall.dismissedTeamPlayerId : strikerEnd;
        if (dismissedId === strikerEnd) {
          strikerEnd = lastBall.nextBatterTeamPlayerId;
        } else if (dismissedId === nonStrikerEnd) {
          nonStrikerEnd = lastBall.nextBatterTeamPlayerId;
        }
      }
      const overForLastBall = overs.find((o) => o.id === lastBall!.overId);
      if (this.isLegalBall(lastBall) && overForLastBall?.status === OverStatus.COMPLETED) {
        [strikerEnd, nonStrikerEnd] = [nonStrikerEnd, strikerEnd];
      }
      currentStriker = totalWickets >= 10 ? null : strikerEnd;
      currentNonStriker = totalWickets >= 10 ? null : nonStrikerEnd;
    }

    innings.totalRuns = totalRuns;
    innings.totalWickets = totalWickets;
    innings.extrasTotal = extrasTotal;
    innings.totalOversBowled = (Math.floor(legalBalls / 6) + (legalBalls % 6) / 10).toFixed(1);
    innings.currentStrikerTeamPlayerId = currentStriker;
    innings.currentNonStrikerTeamPlayerId = currentNonStriker;

    if (!(opts.preserveIfManuallyCompleted && innings.status === InningsStatus.COMPLETED)) {
      const legalBallsLimit = (match.oversLimit ?? 20) * 6;
      let derivedCompleted = totalWickets >= 10 || legalBalls >= legalBallsLimit;
      if (!derivedCompleted && innings.inningsNumber === 2) {
        const innings1 = await manager.findOne(Innings, { where: { matchId: match.id, inningsNumber: 1 } });
        if (innings1 && totalRuns > innings1.totalRuns) {
          derivedCompleted = true; // chasing team has reached the target
        }
      }
      innings.status = derivedCompleted ? InningsStatus.COMPLETED : InningsStatus.IN_PROGRESS;
    }

    await manager.save(Innings, innings);
    return innings;
  }

  /**
   * After an innings-2 status change (completion, or an undo reopening it),
   * (re)derives and persists the match result, or reverts Match to `live`
   * if innings 2 is no longer complete. Returns true if the match is (now)
   * completed.
   */
  private async applyMatchCompletionIfNeeded(manager: EntityManager, match: Match, innings2: Innings): Promise<boolean> {
    if (innings2.status !== InningsStatus.COMPLETED) {
      if (match.status === MatchStatus.COMPLETED) {
        match.status = MatchStatus.LIVE;
        match.resultSummary = null;
        match.winnerTournamentTeamId = null;
        await manager.save(Match, match);
      }
      return false;
    }

    const innings1 = await manager.findOneOrFail(Innings, { where: { matchId: match.id, inningsNumber: 1 } });
    const team1 = await manager.findOneOrFail(TournamentTeam, { where: { id: innings1.battingTournamentTeamId }, relations: ['team'] });
    const team2 = await manager.findOneOrFail(TournamentTeam, { where: { id: innings2.battingTournamentTeamId }, relations: ['team'] });

    let winnerTournamentTeamId: string | null;
    let resultSummary: string;
    if (innings2.totalRuns > innings1.totalRuns) {
      const wicketsRemaining = 10 - innings2.totalWickets;
      winnerTournamentTeamId = team2.id;
      resultSummary = `${team2.team.name} won by ${wicketsRemaining} wicket${wicketsRemaining === 1 ? '' : 's'}`;
    } else if (innings1.totalRuns > innings2.totalRuns) {
      const runMargin = innings1.totalRuns - innings2.totalRuns;
      winnerTournamentTeamId = team1.id;
      resultSummary = `${team1.team.name} won by ${runMargin} run${runMargin === 1 ? '' : 's'}`;
    } else {
      winnerTournamentTeamId = null;
      resultSummary = 'Match tied';
    }

    match.status = MatchStatus.COMPLETED;
    match.winnerTournamentTeamId = winnerTournamentTeamId;
    match.resultSummary = resultSummary;
    await manager.save(Match, match);
    return true;
  }

  // ---------------------------------------------------------------------
  // Lifecycle actions
  // ---------------------------------------------------------------------

  async startMatch(user: AuthenticatedUser, organizationId: string, matchId: string, dto: StartMatchDto) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      // Postgres refuses FOR UPDATE across an outer join, so lock the bare
      // Match row first (no `relations`) and fetch the joined Tournament
      // separately — same pattern AuctionRealtimeService.resolveLot uses.
      const match = await queryRunner.manager.findOne(Match, {
        where: { id: matchId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!match) {
        throw new NotFoundException('Match not found');
      }
      const tournament = await queryRunner.manager.findOneOrFail(Tournament, { where: { id: match.tournamentId } });
      if (tournament.organizationId !== organizationId) {
        throw new NotFoundException('Match not found');
      }
      this.assertOrgAccess(user, organizationId);
      this.assertScorerRole(user);

      if (match.status !== MatchStatus.SCHEDULED) {
        throw new BadRequestException(`Cannot start scoring for a match in status "${match.status}"`);
      }
      if (!match.homeTournamentTeamId || !match.awayTournamentTeamId) {
        throw new BadRequestException('Match must have both home and away teams assigned before scoring can start');
      }
      const { battingFirstTournamentTeamId } = dto;
      if (
        battingFirstTournamentTeamId !== match.homeTournamentTeamId &&
        battingFirstTournamentTeamId !== match.awayTournamentTeamId
      ) {
        throw new BadRequestException('battingFirstTournamentTeamId must be this match\'s home or away team');
      }
      const bowlingFirstTournamentTeamId =
        battingFirstTournamentTeamId === match.homeTournamentTeamId ? match.awayTournamentTeamId : match.homeTournamentTeamId;

      await this.assertPlayingLineup(
        queryRunner.manager,
        matchId,
        battingFirstTournamentTeamId,
        dto.openingStrikerTeamPlayerId,
        'openingStrikerTeamPlayerId',
      );
      await this.assertPlayingLineup(
        queryRunner.manager,
        matchId,
        battingFirstTournamentTeamId,
        dto.openingNonStrikerTeamPlayerId,
        'openingNonStrikerTeamPlayerId',
      );
      if (dto.openingStrikerTeamPlayerId === dto.openingNonStrikerTeamPlayerId) {
        throw new BadRequestException('openingStrikerTeamPlayerId and openingNonStrikerTeamPlayerId must differ');
      }
      await this.assertPlayingLineup(
        queryRunner.manager,
        matchId,
        bowlingFirstTournamentTeamId,
        dto.openingBowlerTeamPlayerId,
        'openingBowlerTeamPlayerId',
      );

      const oversLimit = dto.oversLimit ?? FORMAT_DEFAULT_OVERS[tournament.format];
      match.status = MatchStatus.LIVE;
      match.oversLimit = oversLimit;
      await queryRunner.manager.save(Match, match);

      const innings = await queryRunner.manager.save(
        queryRunner.manager.create(Innings, {
          matchId,
          inningsNumber: 1,
          battingTournamentTeamId: battingFirstTournamentTeamId,
          bowlingTournamentTeamId: bowlingFirstTournamentTeamId,
          status: InningsStatus.IN_PROGRESS,
          currentStrikerTeamPlayerId: dto.openingStrikerTeamPlayerId,
          currentNonStrikerTeamPlayerId: dto.openingNonStrikerTeamPlayerId,
        }),
      );
      await queryRunner.manager.save(
        queryRunner.manager.create(Over, {
          inningsId: innings.id,
          overNumber: 1,
          bowlerTeamPlayerId: dto.openingBowlerTeamPlayerId,
          status: OverStatus.IN_PROGRESS,
        }),
      );

      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }

    const state = await this.getLiveState(organizationId, matchId);
    this.broadcast({ type: 'scoring.inningsStarted', matchId, payload: state });
    return state;
  }

  async startInnings(user: AuthenticatedUser, organizationId: string, matchId: string, dto: StartInningsDto) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const match = await queryRunner.manager.findOne(Match, {
        where: { id: matchId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!match) {
        throw new NotFoundException('Match not found');
      }
      const tournament = await queryRunner.manager.findOneOrFail(Tournament, { where: { id: match.tournamentId } });
      if (tournament.organizationId !== organizationId) {
        throw new NotFoundException('Match not found');
      }
      this.assertOrgAccess(user, organizationId);
      this.assertScorerRole(user);

      const innings1 = await queryRunner.manager.findOne(Innings, { where: { matchId, inningsNumber: 1 } });
      if (!innings1 || innings1.status !== InningsStatus.COMPLETED) {
        throw new BadRequestException('The first innings must be completed before starting the second');
      }
      const existingInnings2 = await queryRunner.manager.findOne(Innings, { where: { matchId, inningsNumber: 2 } });
      if (existingInnings2) {
        throw new BadRequestException('The second innings has already started');
      }

      const battingTournamentTeamId = innings1.bowlingTournamentTeamId;
      const bowlingTournamentTeamId = innings1.battingTournamentTeamId;

      await this.assertPlayingLineup(
        queryRunner.manager,
        matchId,
        battingTournamentTeamId,
        dto.openingStrikerTeamPlayerId,
        'openingStrikerTeamPlayerId',
      );
      await this.assertPlayingLineup(
        queryRunner.manager,
        matchId,
        battingTournamentTeamId,
        dto.openingNonStrikerTeamPlayerId,
        'openingNonStrikerTeamPlayerId',
      );
      if (dto.openingStrikerTeamPlayerId === dto.openingNonStrikerTeamPlayerId) {
        throw new BadRequestException('openingStrikerTeamPlayerId and openingNonStrikerTeamPlayerId must differ');
      }
      await this.assertPlayingLineup(
        queryRunner.manager,
        matchId,
        bowlingTournamentTeamId,
        dto.openingBowlerTeamPlayerId,
        'openingBowlerTeamPlayerId',
      );

      const innings2 = await queryRunner.manager.save(
        queryRunner.manager.create(Innings, {
          matchId,
          inningsNumber: 2,
          battingTournamentTeamId,
          bowlingTournamentTeamId,
          status: InningsStatus.IN_PROGRESS,
          currentStrikerTeamPlayerId: dto.openingStrikerTeamPlayerId,
          currentNonStrikerTeamPlayerId: dto.openingNonStrikerTeamPlayerId,
        }),
      );
      await queryRunner.manager.save(
        queryRunner.manager.create(Over, {
          inningsId: innings2.id,
          overNumber: 1,
          bowlerTeamPlayerId: dto.openingBowlerTeamPlayerId,
          status: OverStatus.IN_PROGRESS,
        }),
      );

      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }

    const state = await this.getLiveState(organizationId, matchId);
    this.broadcast({ type: 'scoring.inningsStarted', matchId, payload: state });
    return state;
  }

  /** Finds the innings currently accepting balls (status=in_progress) for a match, or null. */
  private async getCurrentInnings(manager: EntityManager, matchId: string, lock: boolean): Promise<Innings | null> {
    return manager.findOne(Innings, {
      where: { matchId, status: InningsStatus.IN_PROGRESS },
      order: { inningsNumber: 'DESC' },
      ...(lock ? { lock: { mode: 'pessimistic_write' as const } } : {}),
    });
  }

  async newBowler(user: AuthenticatedUser, organizationId: string, matchId: string, dto: NewBowlerDto) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    let inningsId = '';
    try {
      const match = await this.getOrgScopedMatch(queryRunner.manager, organizationId, matchId);
      this.assertOrgAccess(user, organizationId);
      this.assertScorerRole(user);

      const innings = await this.getCurrentInnings(queryRunner.manager, matchId, true);
      if (!innings) {
        throw new BadRequestException('No innings is currently in progress for this match');
      }
      inningsId = innings.id;

      const overs = await queryRunner.manager.find(Over, { where: { inningsId: innings.id }, order: { overNumber: 'ASC' } });
      const latest = overs[overs.length - 1];
      const previousCompleted = latest?.status === OverStatus.IN_PROGRESS ? overs[overs.length - 2] : latest;

      await this.assertPlayingLineup(
        queryRunner.manager,
        matchId,
        innings.bowlingTournamentTeamId,
        dto.bowlerTeamPlayerId,
        'bowlerTeamPlayerId',
      );
      if (previousCompleted && previousCompleted.bowlerTeamPlayerId === dto.bowlerTeamPlayerId) {
        throw new BadRequestException('The same bowler cannot bowl two overs in a row');
      }

      if (latest && latest.status === OverStatus.IN_PROGRESS) {
        const ballCount = await queryRunner.manager.count(Ball, { where: { overId: latest.id, voided: false } });
        if (ballCount > 0) {
          throw new BadRequestException('The current over is still in progress — cannot change its bowler now');
        }
        latest.bowlerTeamPlayerId = dto.bowlerTeamPlayerId;
        await queryRunner.manager.save(Over, latest);
      } else {
        await queryRunner.manager.save(
          queryRunner.manager.create(Over, {
            inningsId: innings.id,
            overNumber: (latest?.overNumber ?? 0) + 1,
            bowlerTeamPlayerId: dto.bowlerTeamPlayerId,
            status: OverStatus.IN_PROGRESS,
          }),
        );
      }

      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }

    const state = await this.getLiveState(organizationId, matchId);
    this.broadcast({ type: 'scoring.newBowlerSet', matchId, payload: state });
    return state;
  }

  async recordBall(user: AuthenticatedUser, organizationId: string, matchId: string, dto: RecordBallDto) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    let inningsCompleted = false;
    let matchCompleted = false;
    let completedInningsNumber = 0;
    let completedMatch: Match | null = null;

    try {
      await this.getOrgScopedMatch(queryRunner.manager, organizationId, matchId);
      this.assertOrgAccess(user, organizationId);
      this.assertScorerRole(user);

      const match = await queryRunner.manager.findOneOrFail(Match, { where: { id: matchId } });
      completedMatch = match;
      const innings = await this.getCurrentInnings(queryRunner.manager, matchId, true);
      if (!innings) {
        throw new BadRequestException('No innings is currently in progress for this match');
      }
      if (!innings.currentStrikerTeamPlayerId || !innings.currentNonStrikerTeamPlayerId) {
        throw new BadRequestException('Innings has no batters at the crease — this should not happen');
      }

      const currentOver = await queryRunner.manager.findOne(Over, {
        where: { inningsId: innings.id, status: OverStatus.IN_PROGRESS },
      });
      if (!currentOver) {
        throw new BadRequestException("Call newBowler to select the next over's bowler before recording a ball");
      }

      const runs = dto.runs ?? 0;
      const extraType = dto.extraType ?? null;
      const { runsBatter, runsExtra } = this.splitRuns(runs, extraType);
      const isWicket = dto.isWicket ?? false;

      let dismissedTeamPlayerId: string | null = null;
      let nextBatterTeamPlayerId: string | null = null;
      if (isWicket) {
        if (!dto.dismissalType) {
          throw new BadRequestException('dismissalType is required when isWicket is true');
        }
        if (dto.dismissalType === DismissalType.RUN_OUT) {
          if (!dto.dismissedTeamPlayerId) {
            throw new BadRequestException('dismissedTeamPlayerId is required for a run_out (not always the striker)');
          }
          if (
            dto.dismissedTeamPlayerId !== innings.currentStrikerTeamPlayerId &&
            dto.dismissedTeamPlayerId !== innings.currentNonStrikerTeamPlayerId
          ) {
            throw new BadRequestException('dismissedTeamPlayerId must be the current striker or non-striker');
          }
          dismissedTeamPlayerId = dto.dismissedTeamPlayerId;
        } else {
          if (dto.dismissedTeamPlayerId && dto.dismissedTeamPlayerId !== innings.currentStrikerTeamPlayerId) {
            throw new BadRequestException('This dismissal type always dismisses the striker');
          }
          dismissedTeamPlayerId = innings.currentStrikerTeamPlayerId;
        }

        const wicketsAfter = innings.totalWickets + 1;
        if (wicketsAfter < 10) {
          if (!dto.nextBatterTeamPlayerId) {
            throw new BadRequestException('nextBatterTeamPlayerId is required (this is not the 10th wicket)');
          }
          if (dto.nextBatterTeamPlayerId === innings.currentStrikerTeamPlayerId || dto.nextBatterTeamPlayerId === innings.currentNonStrikerTeamPlayerId) {
            throw new BadRequestException('nextBatterTeamPlayerId must not already be at the crease');
          }
          await this.assertPlayingLineup(
            queryRunner.manager,
            matchId,
            innings.battingTournamentTeamId,
            dto.nextBatterTeamPlayerId,
            'nextBatterTeamPlayerId',
          );
          const alreadyOut = await queryRunner.manager.count(Ball, {
            where: { inningsId: innings.id, voided: false, dismissedTeamPlayerId: dto.nextBatterTeamPlayerId },
          });
          if (alreadyOut > 0) {
            throw new BadRequestException('nextBatterTeamPlayerId has already been dismissed in this innings');
          }
          nextBatterTeamPlayerId = dto.nextBatterTeamPlayerId;
        } else if (dto.nextBatterTeamPlayerId) {
          throw new BadRequestException('nextBatterTeamPlayerId must be omitted on the innings-ending 10th wicket');
        }
      }

      // ballNumberInOver is the LEGAL-ball slot (see ball.entity.ts doc): a
      // wide/no-ball at slot N and the legal delivery that eventually
      // completes slot N are both numbered N.
      const totalBallsInOver = await queryRunner.manager.find(Ball, {
        where: { overId: currentOver.id, voided: false },
      });
      const legalCount = totalBallsInOver.filter((b) => this.isLegalBall(b)).length;
      const ballNumberInOver = legalCount + 1;

      const maxSeq = await queryRunner.manager
        .createQueryBuilder(Ball, 'b')
        .select('MAX(b.sequence_number)', 'max')
        .where('b.innings_id = :inningsId', { inningsId: innings.id })
        .getRawOne<{ max: number | null }>();
      const sequenceNumber = (maxSeq?.max ?? 0) + 1;

      await queryRunner.manager.save(
        queryRunner.manager.create(Ball, {
          inningsId: innings.id,
          overId: currentOver.id,
          ballNumberInOver,
          strikerTeamPlayerId: innings.currentStrikerTeamPlayerId,
          nonStrikerTeamPlayerId: innings.currentNonStrikerTeamPlayerId,
          bowlerTeamPlayerId: currentOver.bowlerTeamPlayerId,
          runsBatter,
          runsExtra,
          extraType,
          isWicket,
          dismissalType: isWicket ? (dto.dismissalType ?? null) : null,
          dismissedTeamPlayerId,
          fielderTeamPlayerId: dto.fielderTeamPlayerId ?? null,
          nextBatterTeamPlayerId,
          commentaryText: dto.commentaryText ?? null,
          sequenceNumber,
          voided: false,
        }),
      );

      const beforeStatus = innings.status;
      const updatedInnings = await this.recomputeInningsAggregates(queryRunner.manager, innings.id);
      if (beforeStatus === InningsStatus.IN_PROGRESS && updatedInnings.status === InningsStatus.COMPLETED) {
        inningsCompleted = true;
        completedInningsNumber = updatedInnings.inningsNumber;
        if (updatedInnings.inningsNumber === 2) {
          matchCompleted = await this.applyMatchCompletionIfNeeded(queryRunner.manager, match, updatedInnings);
        }
      }

      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }

    const state = await this.getLiveState(organizationId, matchId);
    this.broadcast({ type: 'scoring.ballRecorded', matchId, payload: state });
    if (inningsCompleted) {
      this.broadcast({ type: 'scoring.inningsCompleted', matchId, payload: { inningsNumber: completedInningsNumber, state } });
    }
    if (matchCompleted && completedMatch) {
      this.broadcast({ type: 'scoring.matchCompleted', matchId, payload: state });
      await this.notifyMatchResult(organizationId, completedMatch);
    }
    return state;
  }

  /**
   * Voids the most recent ball recorded for the match and recomputes all
   * derived state from scratch (see class doc). Scoped to the LATEST
   * innings (by inningsNumber) for the match, since that's necessarily
   * where the most recent ball lives.
   *
   * Known limitation (documented, not a bug): if `newBowler` has already
   * been called for the over AFTER the one containing the last ball (i.e.
   * a next-over bowler has been pre-selected but no ball bowled to them
   * yet), undo is refused — unwinding across that boundary would leave two
   * simultaneously in-progress overs. The scorer must record at least one
   * ball of the new over (then undo that instead) or accept the correction
   * stands. This mirrors AuctionRealtimeService.undoLastBid's scope (undo
   * only the most recent action on the CURRENT lot/over).
   */
  async undoLastBall(user: AuthenticatedUser, organizationId: string, matchId: string) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      await this.getOrgScopedMatch(queryRunner.manager, organizationId, matchId);
      this.assertOrgAccess(user, organizationId);
      this.assertScorerRole(user);

      const match = await queryRunner.manager.findOneOrFail(Match, { where: { id: matchId } });
      const innings = await queryRunner.manager.findOne(Innings, {
        where: { matchId },
        order: { inningsNumber: 'DESC' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!innings) {
        throw new BadRequestException('No innings exists for this match yet');
      }

      const lastBall = await queryRunner.manager.findOne(Ball, {
        where: { inningsId: innings.id, voided: false },
        order: { sequenceNumber: 'DESC' },
      });
      if (!lastBall) {
        throw new BadRequestException('No balls have been recorded for the current innings');
      }

      const overs = await queryRunner.manager.find(Over, { where: { inningsId: innings.id }, order: { overNumber: 'DESC' } });
      const latestOver = overs[0];
      if (latestOver && latestOver.id !== lastBall.overId) {
        throw new BadRequestException(
          'Cannot undo: a new over has already been started since this ball was recorded',
        );
      }

      lastBall.voided = true;
      lastBall.voidedAt = new Date();
      await queryRunner.manager.save(Ball, lastBall);

      const updatedInnings = await this.recomputeInningsAggregates(queryRunner.manager, innings.id);
      if (updatedInnings.inningsNumber === 2) {
        await this.applyMatchCompletionIfNeeded(queryRunner.manager, match, updatedInnings);
      }

      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }

    const state = await this.getLiveState(organizationId, matchId);
    this.broadcast({ type: 'scoring.ballUndone', matchId, payload: state });
    return state;
  }

  /** Manual early end of the currently in-progress innings (declaration-equivalent / early stoppage). */
  async endInnings(user: AuthenticatedUser, organizationId: string, matchId: string) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    let inningsNumber = 0;
    let matchCompleted = false;
    let completedMatch: Match | null = null;
    try {
      await this.getOrgScopedMatch(queryRunner.manager, organizationId, matchId);
      this.assertOrgAccess(user, organizationId);
      this.assertScorerRole(user);

      const match = await queryRunner.manager.findOneOrFail(Match, { where: { id: matchId } });
      completedMatch = match;
      const innings = await this.getCurrentInnings(queryRunner.manager, matchId, true);
      if (!innings) {
        throw new BadRequestException('No innings is currently in progress for this match');
      }

      let updated = await this.recomputeInningsAggregates(queryRunner.manager, innings.id);
      updated.status = InningsStatus.COMPLETED;
      updated = await queryRunner.manager.save(Innings, updated);
      inningsNumber = updated.inningsNumber;

      if (updated.inningsNumber === 2) {
        matchCompleted = await this.applyMatchCompletionIfNeeded(queryRunner.manager, match, updated);
      }

      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }

    const state = await this.getLiveState(organizationId, matchId);
    this.broadcast({ type: 'scoring.inningsCompleted', matchId, payload: { inningsNumber, state } });
    if (matchCompleted && completedMatch) {
      this.broadcast({ type: 'scoring.matchCompleted', matchId, payload: state });
      await this.notifyMatchResult(organizationId, completedMatch);
    }
    return state;
  }

  // ---------------------------------------------------------------------
  // Read models
  // ---------------------------------------------------------------------

  private async playerLabel(manager: EntityManager, teamPlayerId: string | null): Promise<{ teamPlayerId: string; fullName: string } | null> {
    if (!teamPlayerId) return null;
    const tp = await manager.findOne(TeamPlayer, { where: { id: teamPlayerId }, relations: ['player'] });
    return tp ? { teamPlayerId, fullName: tp.player.fullName } : null;
  }

  /** Runs/balls/4s/6s/dismissal for one batter within one innings, computed live from `balls`. */
  private async battingFiguresFor(manager: EntityManager, inningsId: string, teamPlayerId: string) {
    const balls = await manager.find(Ball, {
      where: { inningsId, voided: false, strikerTeamPlayerId: teamPlayerId },
    });
    const runs = balls.reduce((sum, b) => sum + b.runsBatter, 0);
    const ballsFaced = balls.filter((b) => b.extraType !== ExtraType.WIDE).length;
    const fours = balls.filter((b) => b.runsBatter === 4).length;
    const sixes = balls.filter((b) => b.runsBatter === 6).length;
    const dismissal = await manager.findOne(Ball, {
      where: { inningsId, voided: false, isWicket: true, dismissedTeamPlayerId: teamPlayerId },
    });
    return {
      runs,
      ballsFaced,
      fours,
      sixes,
      strikeRate: ballsFaced > 0 ? Number(((runs / ballsFaced) * 100).toFixed(2)) : 0,
      isOut: !!dismissal,
      dismissalType: dismissal?.dismissalType ?? null,
    };
  }

  /** Overs/runs/wickets/economy/maidens for one bowler within one innings. */
  private async bowlingFiguresFor(manager: EntityManager, inningsId: string, teamPlayerId: string) {
    const balls = await manager.find(Ball, { where: { inningsId, voided: false, bowlerTeamPlayerId: teamPlayerId } });
    const legalCount = balls.filter((b) => this.isLegalBall(b)).length;
    const runsConceded = balls.reduce((sum, b) => sum + this.bowlerChargedRuns(b), 0);
    const wickets = balls.filter((b) => b.isWicket && b.dismissalType !== DismissalType.RUN_OUT).length;
    const maidens = await manager.count(Over, {
      where: { inningsId, bowlerTeamPlayerId: teamPlayerId, isMaiden: true, status: OverStatus.COMPLETED },
    });
    const oversDisplay = Number(`${Math.floor(legalCount / 6)}.${legalCount % 6}`);
    return {
      overs: oversDisplay,
      runsConceded,
      wickets,
      maidens,
      economy: legalCount > 0 ? Number((runsConceded / (legalCount / 6)).toFixed(2)) : 0,
    };
  }

  private async buildInningsSnapshot(manager: EntityManager, innings: Innings) {
    const recentBallsDesc = await manager.find(Ball, {
      where: { inningsId: innings.id, voided: false },
      order: { sequenceNumber: 'DESC' },
      take: 12,
    });
    const recentBalls = recentBallsDesc.reverse();
    const recentBallsResolved = await Promise.all(
      recentBalls.map(async (b) => ({
        sequenceNumber: b.sequenceNumber,
        overNumber: (await manager.findOne(Over, { where: { id: b.overId } }))?.overNumber ?? null,
        ballNumberInOver: b.ballNumberInOver,
        runsBatter: b.runsBatter,
        runsExtra: b.runsExtra,
        extraType: b.extraType,
        isWicket: b.isWicket,
        dismissalType: b.dismissalType,
        commentaryText: b.commentaryText,
      })),
    );

    const currentOver = await manager.findOne(Over, { where: { inningsId: innings.id, status: OverStatus.IN_PROGRESS } });
    const activePartnership = await manager
      .createQueryBuilder(Partnership, 'p')
      .where('p.innings_id = :inningsId', { inningsId: innings.id })
      .andWhere('p.end_ball_sequence IS NULL')
      .getOne();

    const [striker, nonStriker, bowler] = await Promise.all([
      this.playerLabel(manager, innings.currentStrikerTeamPlayerId),
      this.playerLabel(manager, innings.currentNonStrikerTeamPlayerId),
      currentOver ? this.playerLabel(manager, currentOver.bowlerTeamPlayerId) : null,
    ]);

    const [strikerFigures, nonStrikerFigures, bowlerFigures] = await Promise.all([
      innings.currentStrikerTeamPlayerId ? this.battingFiguresFor(manager, innings.id, innings.currentStrikerTeamPlayerId) : null,
      innings.currentNonStrikerTeamPlayerId ? this.battingFiguresFor(manager, innings.id, innings.currentNonStrikerTeamPlayerId) : null,
      currentOver ? this.bowlingFiguresFor(manager, innings.id, currentOver.bowlerTeamPlayerId) : null,
    ]);

    return {
      inningsId: innings.id,
      inningsNumber: innings.inningsNumber,
      battingTournamentTeamId: innings.battingTournamentTeamId,
      bowlingTournamentTeamId: innings.bowlingTournamentTeamId,
      status: innings.status,
      totalRuns: innings.totalRuns,
      totalWickets: innings.totalWickets,
      totalOversBowled: innings.totalOversBowled,
      extrasTotal: innings.extrasTotal,
      striker: striker ? { ...striker, ...strikerFigures } : null,
      nonStriker: nonStriker ? { ...nonStriker, ...nonStrikerFigures } : null,
      currentOver: currentOver
        ? {
            overNumber: currentOver.overNumber,
            bowler,
            runsConceded: currentOver.runsConceded,
            wickets: currentOver.wickets,
            status: currentOver.status,
            bowlerInningsFigures: bowlerFigures,
          }
        : null,
      currentPartnership: activePartnership
        ? {
            batter1: await this.playerLabel(manager, activePartnership.batter1TeamPlayerId),
            batter2: await this.playerLabel(manager, activePartnership.batter2TeamPlayerId),
            runs: activePartnership.runs,
            ballsFaced: activePartnership.ballsFaced,
          }
        : null,
      recentBalls: recentBallsResolved,
    };
  }

  /** Full current-state snapshot — used by REST GET /live-state AND the WS stateSync/join/broadcast payloads. */
  async getLiveState(organizationId: string, matchId: string) {
    const manager = this.dataSource.manager;
    const match = await this.getOrgScopedMatch(manager, organizationId, matchId);
    const inningsList = await manager.find(Innings, { where: { matchId }, order: { inningsNumber: 'ASC' } });
    const inningsSnapshots = await Promise.all(inningsList.map((i) => this.buildInningsSnapshot(manager, i)));

    return {
      match: {
        id: match.id,
        status: match.status,
        oversLimit: match.oversLimit,
        homeTournamentTeamId: match.homeTournamentTeamId,
        awayTournamentTeamId: match.awayTournamentTeamId,
        resultSummary: match.resultSummary,
        winnerTournamentTeamId: match.winnerTournamentTeamId,
      },
      innings: inningsSnapshots,
    };
  }

  /** Full ball-by-ball-derived scorecard for the match: batting/bowling figures per player, per innings. */
  async getScorecard(organizationId: string, matchId: string) {
    const manager = this.dataSource.manager;
    const match = await this.getOrgScopedMatch(manager, organizationId, matchId);
    const inningsList = await manager.find(Innings, { where: { matchId }, order: { inningsNumber: 'ASC' } });

    const inningsCards = await Promise.all(
      inningsList.map(async (innings) => {
        const balls = await manager.find(Ball, { where: { inningsId: innings.id, voided: false }, order: { sequenceNumber: 'ASC' } });

        const battingOrder: string[] = [];
        for (const b of balls) {
          if (!battingOrder.includes(b.strikerTeamPlayerId)) battingOrder.push(b.strikerTeamPlayerId);
          if (!battingOrder.includes(b.nonStrikerTeamPlayerId)) battingOrder.push(b.nonStrikerTeamPlayerId);
        }
        const batting = await Promise.all(
          battingOrder.map(async (teamPlayerId) => {
            const label = await this.playerLabel(manager, teamPlayerId);
            const figures = await this.battingFiguresFor(manager, innings.id, teamPlayerId);
            return { ...label, ...figures };
          }),
        );

        const bowlerIds = [...new Set((await manager.find(Over, { where: { inningsId: innings.id } })).map((o) => o.bowlerTeamPlayerId))];
        const bowling = await Promise.all(
          bowlerIds.map(async (teamPlayerId) => {
            const label = await this.playerLabel(manager, teamPlayerId);
            const figures = await this.bowlingFiguresFor(manager, innings.id, teamPlayerId);
            return { ...label, ...figures };
          }),
        );

        return {
          inningsId: innings.id,
          inningsNumber: innings.inningsNumber,
          battingTournamentTeamId: innings.battingTournamentTeamId,
          bowlingTournamentTeamId: innings.bowlingTournamentTeamId,
          status: innings.status,
          totalRuns: innings.totalRuns,
          totalWickets: innings.totalWickets,
          totalOversBowled: innings.totalOversBowled,
          extrasTotal: innings.extrasTotal,
          batting,
          bowling,
        };
      }),
    );

    return {
      match: {
        id: match.id,
        status: match.status,
        resultSummary: match.resultSummary,
        winnerTournamentTeamId: match.winnerTournamentTeamId,
      },
      innings: inningsCards,
    };
  }
}
