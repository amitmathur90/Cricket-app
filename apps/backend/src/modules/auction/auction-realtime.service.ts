import { BadRequestException, ForbiddenException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { EventEmitter } from 'events';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { OrgRole } from '../../common/enums/org-role.enum';
import { AuthenticatedUser } from '../../common/types/authenticated-user';
import { AcquisitionType, TeamPlayer } from '../../database/entities/team-player.entity';
import { AuctionBid } from '../../database/entities/auction-bid.entity';
import { AuctionPlayerPool, AuctionPoolStatus } from '../../database/entities/auction-player-pool.entity';
import { AuctionSession, AuctionSessionStatus } from '../../database/entities/auction-session.entity';
import { NotificationType } from '../../database/entities/notification.entity';
import { PurseLedger, PurseLedgerType } from '../../database/entities/purse-ledger.entity';
import { Team } from '../../database/entities/team.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { computeMinIncrement } from './auction-bid-increment.util';

/** Initial countdown for a freshly-opened lot. */
const LOT_DURATION_MS = 30_000;
/** Every accepted bid resets the countdown to this many ms from now (anti-sniping). */
const REBID_EXTENSION_MS = 10_000;
/** Floor applied when resuming a paused session so a near-zero remainder isn't instantly re-expired. */
const MIN_RESUME_MS = 5_000;

export type AuctionBroadcastEventType =
  | 'auction.playerUp'
  | 'auction.bidPlaced'
  | 'auction.bidUndone'
  | 'auction.playerSold'
  | 'auction.playerUnsold'
  | 'auction.stateSync'
  | 'auction.error';

export interface AuctionBroadcastEvent {
  type: AuctionBroadcastEventType;
  sessionId: string;
  payload: unknown;
}

export interface PlaceBidInput {
  auctionSessionId: string;
  teamId: string;
  amount: number;
}

/**
 * Owns the server-authoritative auction lifecycle: starting/pausing/
 * resuming sessions, accepting bids, and resolving lots (on timer expiry
 * or manual admin override) — advancing to the next lot / completing the
 * session automatically. Both AuctionController (REST: start/pause/
 * resume/next-lot) and AuctionGateway (WS: placeBid, join) call into this
 * single service so REST-triggered and timer-triggered transitions go
 * through the exact same code path.
 *
 * Concurrency: every mutation of a session's "current lot" state
 * (placeBid, resolveLot) runs inside a DB transaction that takes a
 * `SELECT ... FOR UPDATE` row lock on the auction_sessions row first. This
 * makes two near-simultaneous bids for the same lot — or a bid racing the
 * lot's own expiry timer — fully serialized: whichever request acquires
 * the lock first commits its effect (new leading bid, or lot resolution)
 * before the second is even evaluated, so the second sees fresh state and
 * either fails validation cleanly or (for the timer) re-checks whether the
 * deadline already moved. A DB lock was chosen over an in-process mutex
 * because the "current lot" fields already live in Postgres as the
 * source of truth (needed for REST reads / reconnect state-sync anyway),
 * so locking there covers both this single-instance process AND any
 * future horizontally-scaled deployment for free.
 *
 * Lot timers themselves, however, ARE in-process (`setTimeout` per live
 * session, in `timers`) — fine for this single-instance dev deployment.
 * Scaling horizontally would need the timer/scheduling responsibility
 * moved to a shared scheduler (e.g. a Redis-backed delayed job) so only
 * one instance fires the expiry for a given session; not built here.
 */
@Injectable()
export class AuctionRealtimeService {
  private readonly logger = new Logger(AuctionRealtimeService.name);
  private readonly emitter = new EventEmitter();
  private readonly timers = new Map<string, NodeJS.Timeout>();
  private readonly pausedRemainingMs = new Map<string, number>();

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    @InjectRepository(AuctionSession) private readonly sessionRepo: Repository<AuctionSession>,
    @InjectRepository(AuctionPlayerPool) private readonly poolRepo: Repository<AuctionPlayerPool>,
    @InjectRepository(TournamentTeam) private readonly tournamentTeamRepo: Repository<TournamentTeam>,
    private readonly notificationsService: NotificationsService,
  ) {
    this.emitter.setMaxListeners(50);
  }

  /** Subscribe to broadcast events (AuctionGateway relays these onto the Socket.IO room). */
  onBroadcast(handler: (evt: AuctionBroadcastEvent) => void): void {
    this.emitter.on('broadcast', handler);
  }

  private broadcast(evt: AuctionBroadcastEvent): void {
    this.emitter.emit('broadcast', evt);
  }

  private assertOrgAccess(user: AuthenticatedUser, organizationId: string): void {
    if (user.isSuperAdmin) return;
    if (!user.activeOrgId || user.activeOrgId !== organizationId) {
      throw new ForbiddenException('Organization scope mismatch');
    }
  }

  private assertBidderRole(user: AuthenticatedUser): void {
    if (user.isSuperAdmin) return;
    const allowed: OrgRole[] = [OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN, OrgRole.TEAM_OWNER];
    if (!user.role || !allowed.includes(user.role)) {
      throw new ForbiddenException('Only team owners or org/tournament admins may bid');
    }
  }

  private async getOrgScopedSession(organizationId: string, sessionId: string): Promise<AuctionSession> {
    const session = await this.sessionRepo.findOne({ where: { id: sessionId }, relations: ['tournament'] });
    if (!session || session.tournament.organizationId !== organizationId) {
      throw new NotFoundException('Auction session not found');
    }
    return session;
  }

  private clearTimer(sessionId: string): void {
    const handle = this.timers.get(sessionId);
    if (handle) {
      clearTimeout(handle);
      this.timers.delete(sessionId);
    }
  }

  private scheduleLotTimer(sessionId: string, endsAt: Date): void {
    this.clearTimer(sessionId);
    const delay = Math.max(0, endsAt.getTime() - Date.now());
    const handle = setTimeout(() => {
      this.resolveLot(sessionId).catch((err) =>
        this.logger.error(`Failed to auto-resolve lot for session ${sessionId}: ${(err as Error).message}`),
      );
    }, delay);
    this.timers.set(sessionId, handle);
  }

  private async buildStateSyncPayload(manager: EntityManager, session: AuctionSession) {
    const teams = await manager.find(TournamentTeam, {
      where: { tournamentId: session.tournamentId },
      relations: ['team'],
    });
    const remainingPoolCount = await manager.count(AuctionPlayerPool, {
      where: { auctionSessionId: session.id, status: AuctionPoolStatus.PENDING },
    });

    let currentLot: unknown = null;
    if (session.currentPlayerId) {
      const poolEntry = await manager.findOne(AuctionPlayerPool, {
        where: { auctionSessionId: session.id, playerId: session.currentPlayerId },
        relations: ['player'],
      });
      if (poolEntry) {
        currentLot = {
          poolEntryId: poolEntry.id,
          player: {
            id: poolEntry.player.id,
            fullName: poolEntry.player.fullName,
            role: poolEntry.player.role,
            photoUrl: poolEntry.player.photoUrl,
          },
          basePrice: poolEntry.basePrice,
          currentBidAmount: session.currentBidAmount,
          currentBidTeamId: session.currentBidTeamId,
          currentLotEndsAt: session.currentLotEndsAt,
        };
      }
    }

    return {
      session: {
        id: session.id,
        name: session.name,
        status: session.status,
        tournamentId: session.tournamentId,
      },
      currentLot,
      remainingPoolCount,
      teams: teams.map((t) => ({
        tournamentTeamId: t.id,
        teamName: t.team.name,
        purseTotal: t.purseTotal,
        purseRemaining: t.purseRemaining,
      })),
    };
  }

  /** Full current-state snapshot for reconnect recovery — sent on room join. */
  async getStateSync(user: AuthenticatedUser, sessionId: string) {
    const session = await this.sessionRepo.findOne({ where: { id: sessionId }, relations: ['tournament'] });
    if (!session) throw new NotFoundException('Auction session not found');
    this.assertOrgAccess(user, session.tournament.organizationId);
    return this.buildStateSyncPayload(this.dataSource.manager, session);
  }

  /** Admin-only: moves a scheduled session to live and opens the first pending lot. */
  async startSession(organizationId: string, sessionId: string): Promise<AuctionSession> {
    const session = await this.getOrgScopedSession(organizationId, sessionId);
    if (session.status !== AuctionSessionStatus.SCHEDULED) {
      throw new BadRequestException(`Cannot start a session in status "${session.status}"`);
    }

    const firstLot = await this.poolRepo.findOne({
      where: { auctionSessionId: sessionId, status: AuctionPoolStatus.PENDING },
      order: { lotOrder: 'ASC' },
      relations: ['player'],
    });
    if (!firstLot) {
      throw new BadRequestException('Auction pool is empty; add players before starting');
    }

    firstLot.status = AuctionPoolStatus.IN_PROGRESS;
    await this.poolRepo.save(firstLot);

    session.status = AuctionSessionStatus.LIVE;
    session.startedAt = new Date();
    session.currentPlayerId = firstLot.playerId;
    session.currentBidAmount = firstLot.basePrice;
    session.currentBidTeamId = null;
    const endsAt = new Date(Date.now() + LOT_DURATION_MS);
    session.currentLotEndsAt = endsAt;
    const saved = await this.sessionRepo.save(session);

    this.broadcast({
      type: 'auction.playerUp',
      sessionId,
      payload: {
        poolEntryId: firstLot.id,
        player: {
          id: firstLot.player.id,
          fullName: firstLot.player.fullName,
          role: firstLot.player.role,
          photoUrl: firstLot.player.photoUrl,
        },
        basePrice: firstLot.basePrice,
        currentLotEndsAt: endsAt,
      },
    });
    this.scheduleLotTimer(sessionId, endsAt);

    // Fire-and-forget-shaped but awaited: notify every registered team's
    // owner in this tournament that the auction has gone live.
    const registeredTeams = await this.tournamentTeamRepo.find({
      where: { tournamentId: session.tournamentId },
      relations: ['team'],
    });
    const ownerUserIds = registeredTeams.map((t) => t.team?.ownerUserId).filter((id): id is string => !!id);
    await this.notificationsService.notify(organizationId, ownerUserIds, {
      type: NotificationType.AUCTION_ANNOUNCEMENT,
      title: 'Auction started',
      message: `The auction session "${session.name}" is now live.`,
      relatedEntityType: 'auction_session',
      relatedEntityId: sessionId,
    });

    return saved;
  }

  async pauseSession(organizationId: string, sessionId: string): Promise<AuctionSession> {
    const session = await this.getOrgScopedSession(organizationId, sessionId);
    if (session.status !== AuctionSessionStatus.LIVE) {
      throw new BadRequestException('Session is not live');
    }
    this.clearTimer(sessionId);
    if (session.currentLotEndsAt) {
      this.pausedRemainingMs.set(sessionId, Math.max(0, session.currentLotEndsAt.getTime() - Date.now()));
    }
    session.status = AuctionSessionStatus.PAUSED;
    const saved = await this.sessionRepo.save(session);
    this.broadcast({
      type: 'auction.stateSync',
      sessionId,
      payload: await this.buildStateSyncPayload(this.dataSource.manager, saved),
    });
    return saved;
  }

  async resumeSession(organizationId: string, sessionId: string): Promise<AuctionSession> {
    const session = await this.getOrgScopedSession(organizationId, sessionId);
    if (session.status !== AuctionSessionStatus.PAUSED) {
      throw new BadRequestException('Session is not paused');
    }
    const remaining = Math.max(this.pausedRemainingMs.get(sessionId) ?? LOT_DURATION_MS, MIN_RESUME_MS);
    this.pausedRemainingMs.delete(sessionId);

    session.status = AuctionSessionStatus.LIVE;
    if (session.currentPlayerId) {
      const endsAt = new Date(Date.now() + remaining);
      session.currentLotEndsAt = endsAt;
      const saved = await this.sessionRepo.save(session);
      this.scheduleLotTimer(sessionId, endsAt);
      this.broadcast({
        type: 'auction.stateSync',
        sessionId,
        payload: await this.buildStateSyncPayload(this.dataSource.manager, saved),
      });
      return saved;
    }

    const saved = await this.sessionRepo.save(session);
    this.broadcast({
      type: 'auction.stateSync',
      sessionId,
      payload: await this.buildStateSyncPayload(this.dataSource.manager, saved),
    });
    return saved;
  }

  /** Manual admin escape hatch — force-resolves the current lot right now instead of waiting for the timer. */
  async manualNextLot(organizationId: string, sessionId: string): Promise<AuctionSession> {
    const session = await this.getOrgScopedSession(organizationId, sessionId);
    if (session.status !== AuctionSessionStatus.LIVE) {
      throw new BadRequestException('Session is not live');
    }
    await this.resolveLot(sessionId, { force: true });
    return this.getOrgScopedSession(organizationId, sessionId);
  }

  /**
   * Places a bid, server-authoritatively. Validates session/team/amount
   * inside a row-locked transaction, persists the bid + updated leading
   * bid, then (after commit) reschedules the lot timer and broadcasts.
   * On any validation failure it throws before mutating anything — the
   * caller (gateway) is responsible for routing the error back to just
   * the requesting socket, not the room.
   */
  async placeBid(user: AuthenticatedUser, input: PlaceBidInput): Promise<void> {
    const { auctionSessionId, teamId, amount } = input;
    if (!(amount > 0)) {
      throw new BadRequestException('Bid amount must be positive');
    }

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    let broadcastPayload: Record<string, unknown> | null = null;
    let newEndsAt: Date | null = null;

    try {
      const session = await queryRunner.manager.findOne(AuctionSession, {
        where: { id: auctionSessionId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!session) throw new NotFoundException('Auction session not found');

      const tournament = await queryRunner.manager.findOne(Tournament, {
        where: { id: session.tournamentId },
      });
      if (!tournament) throw new NotFoundException('Tournament not found');
      this.assertOrgAccess(user, tournament.organizationId);
      this.assertBidderRole(user);

      if (session.status !== AuctionSessionStatus.LIVE) {
        throw new BadRequestException('Auction session is not live');
      }
      if (!session.currentPlayerId || !session.currentLotEndsAt) {
        throw new BadRequestException('No lot is currently under the hammer');
      }
      if (session.currentLotEndsAt.getTime() <= Date.now()) {
        throw new BadRequestException('Bidding window for this lot has closed');
      }

      const team = await queryRunner.manager.findOne(TournamentTeam, {
        where: { id: teamId },
        relations: ['team'],
      });
      if (!team) throw new NotFoundException('Team not found');
      if (team.tournamentId !== session.tournamentId) {
        throw new BadRequestException('Team is not registered in this tournament');
      }
      if (user.role === OrgRole.TEAM_OWNER && !user.isSuperAdmin && team.team.ownerUserId !== user.userId) {
        throw new ForbiddenException('You may only bid on behalf of your own team');
      }
      if (team.purseRemaining === null) {
        throw new BadRequestException('Team has no purse configured for this tournament and is not eligible to bid');
      }

      const poolEntry = await queryRunner.manager.findOne(AuctionPlayerPool, {
        where: { auctionSessionId, playerId: session.currentPlayerId },
      });
      if (!poolEntry) throw new NotFoundException('Current lot not found in pool');

      const currentBid =
        session.currentBidAmount !== null ? parseFloat(session.currentBidAmount) : parseFloat(poolEntry.basePrice);
      const minIncrement = computeMinIncrement(currentBid, session.bidIncrementRules);
      const minAcceptable = currentBid + minIncrement;

      if (amount < minAcceptable) {
        throw new BadRequestException(`Bid must be at least ${minAcceptable.toFixed(2)}`);
      }
      if (parseFloat(team.purseRemaining) < amount) {
        throw new BadRequestException('Bid exceeds remaining purse');
      }

      const bidCount = await queryRunner.manager.count(AuctionBid, {
        where: { auctionPlayerPoolId: poolEntry.id },
      });
      const bidSequence = bidCount + 1;

      await queryRunner.manager.save(
        queryRunner.manager.create(AuctionBid, {
          auctionSessionId,
          auctionPlayerPoolId: poolEntry.id,
          teamId: team.id,
          bidAmount: amount.toFixed(2),
          bidSequence,
        }),
      );

      newEndsAt = new Date(Date.now() + REBID_EXTENSION_MS);
      session.currentBidAmount = amount.toFixed(2);
      session.currentBidTeamId = team.id;
      session.currentLotEndsAt = newEndsAt;
      await queryRunner.manager.save(AuctionSession, session);

      broadcastPayload = {
        auctionSessionId,
        poolEntryId: poolEntry.id,
        teamId: team.id,
        teamName: team.team.name,
        amount: amount.toFixed(2),
        bidSequence,
        currentLotEndsAt: newEndsAt,
      };

      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }

    if (broadcastPayload && newEndsAt) {
      this.scheduleLotTimer(auctionSessionId, newEndsAt);
      this.broadcast({ type: 'auction.bidPlaced', sessionId: auctionSessionId, payload: broadcastPayload });
    }
  }

  /**
   * Admin-only: rolls back the most recent bid on the session's current
   * lot. Runs under the same row-locked transaction pattern as placeBid so
   * it can't race a concurrent bid or the lot's own timer expiry.
   *
   * The undone bid is never hard-deleted — that would silently rewrite
   * history (the bid really was placed). Instead it's marked
   * voided/voidedAt, and the session's currentBidAmount/currentBidTeamId
   * are recomputed from the next-most-recent non-voided bid on the lot,
   * or reset to "no bidder" (currentBidAmount = lot base price,
   * currentBidTeamId = null) if that was the only bid.
   */
  async undoLastBid(organizationId: string, sessionId: string): Promise<AuctionSession> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    let broadcastPayload: Record<string, unknown> | null = null;

    try {
      const session = await queryRunner.manager.findOne(AuctionSession, {
        where: { id: sessionId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!session) throw new NotFoundException('Auction session not found');

      const tournament = await queryRunner.manager.findOne(Tournament, {
        where: { id: session.tournamentId },
      });
      if (!tournament || tournament.organizationId !== organizationId) {
        throw new NotFoundException('Auction session not found');
      }

      if (session.status !== AuctionSessionStatus.LIVE) {
        throw new BadRequestException('Auction session is not live');
      }
      if (!session.currentPlayerId) {
        throw new BadRequestException('No lot is currently under the hammer');
      }

      const poolEntry = await queryRunner.manager.findOne(AuctionPlayerPool, {
        where: { auctionSessionId: sessionId, playerId: session.currentPlayerId },
      });
      if (!poolEntry) throw new NotFoundException('Current lot not found in pool');

      const lastBid = await queryRunner.manager.findOne(AuctionBid, {
        where: { auctionPlayerPoolId: poolEntry.id, voided: false },
        order: { bidSequence: 'DESC' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!lastBid) {
        throw new BadRequestException('No bids have been placed on the current lot');
      }

      lastBid.voided = true;
      lastBid.voidedAt = new Date();
      await queryRunner.manager.save(AuctionBid, lastBid);

      const previousBid = await queryRunner.manager.findOne(AuctionBid, {
        where: { auctionPlayerPoolId: poolEntry.id, voided: false },
        order: { bidSequence: 'DESC' },
        relations: ['team', 'team.team'],
      });

      if (previousBid) {
        session.currentBidAmount = previousBid.bidAmount;
        session.currentBidTeamId = previousBid.teamId;
      } else {
        session.currentBidAmount = poolEntry.basePrice;
        session.currentBidTeamId = null;
      }
      await queryRunner.manager.save(AuctionSession, session);

      broadcastPayload = {
        auctionSessionId: sessionId,
        poolEntryId: poolEntry.id,
        undoneBid: {
          teamId: lastBid.teamId,
          amount: lastBid.bidAmount,
          bidSequence: lastBid.bidSequence,
        },
        currentBidAmount: session.currentBidAmount,
        currentBidTeamId: session.currentBidTeamId,
        currentBidTeamName: previousBid?.team?.team?.name ?? null,
        currentLotEndsAt: session.currentLotEndsAt,
      };

      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }

    if (broadcastPayload) {
      this.broadcast({ type: 'auction.bidUndone', sessionId, payload: broadcastPayload });
    }
    return this.getOrgScopedSession(organizationId, sessionId);
  }

  /**
   * Resolves the current lot — sold (to the leading bidder) or unsold —
   * and advances to the next pending lot, or completes the session if
   * none remain. Called by the per-session timer on natural expiry, and
   * by manualNextLot() with `force: true` to override immediately.
   *
   * Row-locks the session first; if a bid landed and extended
   * currentLotEndsAt between the timer firing and the lock being
   * acquired, an unforced call backs off and reschedules to the fresh
   * deadline instead of resolving early.
   */
  private async resolveLot(sessionId: string, opts: { force?: boolean } = {}): Promise<void> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    const events: Array<{ type: AuctionBroadcastEventType; payload: unknown }> = [];
    let nextEndsAt: Date | null = null;
    let rescheduleOnly = false;

    try {
      const session = await queryRunner.manager.findOne(AuctionSession, {
        where: { id: sessionId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!session || session.status !== AuctionSessionStatus.LIVE || !session.currentPlayerId) {
        await queryRunner.commitTransaction();
        return;
      }

      if (!opts.force && session.currentLotEndsAt && session.currentLotEndsAt.getTime() > Date.now()) {
        nextEndsAt = session.currentLotEndsAt;
        rescheduleOnly = true;
        await queryRunner.commitTransaction();
        this.scheduleLotTimer(sessionId, nextEndsAt);
        return;
      }

      const poolEntry = await queryRunner.manager.findOne(AuctionPlayerPool, {
        where: { auctionSessionId: sessionId, playerId: session.currentPlayerId },
      });
      if (!poolEntry) {
        await queryRunner.commitTransaction();
        return;
      }

      if (session.currentBidTeamId && session.currentBidAmount) {
        // Postgres refuses FOR UPDATE across an outer join, so lock the bare
        // row first (no `relations`) and fetch the joined Team name after.
        const team = await queryRunner.manager.findOne(TournamentTeam, {
          where: { id: session.currentBidTeamId },
          lock: { mode: 'pessimistic_write' },
        });
        if (!team) throw new Error('Winning team disappeared mid-auction');
        const teamBrand = await queryRunner.manager.findOne(Team, { where: { id: team.teamId } });

        poolEntry.status = AuctionPoolStatus.SOLD;
        poolEntry.finalPrice = session.currentBidAmount;
        poolEntry.soldToTeamId = team.id;
        await queryRunner.manager.save(AuctionPlayerPool, poolEntry);

        const debit = parseFloat(session.currentBidAmount);
        const remainingAfter = (parseFloat(team.purseRemaining ?? '0') - debit).toFixed(2);
        team.purseRemaining = remainingAfter;
        await queryRunner.manager.save(TournamentTeam, team);

        await queryRunner.manager.save(
          queryRunner.manager.create(PurseLedger, {
            tournamentTeamId: team.id,
            auctionSessionId: sessionId,
            playerId: poolEntry.playerId,
            amount: session.currentBidAmount,
            type: PurseLedgerType.DEBIT,
          }),
        );

        // Auction results become real rosters: upsert the team_players row.
        const existingRosterEntry = await queryRunner.manager.findOne(TeamPlayer, {
          where: { tournamentTeamId: team.id, playerId: poolEntry.playerId },
        });
        if (existingRosterEntry) {
          existingRosterEntry.acquisitionType = AcquisitionType.AUCTION;
          existingRosterEntry.acquiredPrice = session.currentBidAmount;
          await queryRunner.manager.save(TeamPlayer, existingRosterEntry);
        } else {
          await queryRunner.manager.save(
            queryRunner.manager.create(TeamPlayer, {
              tournamentTeamId: team.id,
              playerId: poolEntry.playerId,
              acquisitionType: AcquisitionType.AUCTION,
              acquiredPrice: session.currentBidAmount,
            }),
          );
        }

        events.push({
          type: 'auction.playerSold',
          payload: {
            playerId: poolEntry.playerId,
            poolEntryId: poolEntry.id,
            finalPrice: poolEntry.finalPrice,
            soldToTeamId: team.id,
            soldToTeamName: teamBrand?.name ?? null,
            purseRemaining: remainingAfter,
          },
        });
      } else {
        poolEntry.status = AuctionPoolStatus.UNSOLD;
        await queryRunner.manager.save(AuctionPlayerPool, poolEntry);
        events.push({
          type: 'auction.playerUnsold',
          payload: { playerId: poolEntry.playerId, poolEntryId: poolEntry.id },
        });
      }

      const next = await queryRunner.manager.findOne(AuctionPlayerPool, {
        where: { auctionSessionId: sessionId, status: AuctionPoolStatus.PENDING },
        order: { lotOrder: 'ASC' },
        relations: ['player'],
      });

      if (next) {
        next.status = AuctionPoolStatus.IN_PROGRESS;
        await queryRunner.manager.save(AuctionPlayerPool, next);

        session.currentPlayerId = next.playerId;
        session.currentBidAmount = next.basePrice;
        session.currentBidTeamId = null;
        nextEndsAt = new Date(Date.now() + LOT_DURATION_MS);
        session.currentLotEndsAt = nextEndsAt;
        await queryRunner.manager.save(AuctionSession, session);

        events.push({
          type: 'auction.playerUp',
          payload: {
            poolEntryId: next.id,
            player: {
              id: next.player.id,
              fullName: next.player.fullName,
              role: next.player.role,
              photoUrl: next.player.photoUrl,
            },
            basePrice: next.basePrice,
            currentLotEndsAt: nextEndsAt,
          },
        });
      } else {
        session.status = AuctionSessionStatus.COMPLETED;
        session.currentPlayerId = null;
        session.currentBidAmount = null;
        session.currentBidTeamId = null;
        session.currentLotEndsAt = null;
        session.endedAt = new Date();
        await queryRunner.manager.save(AuctionSession, session);
        events.push({
          type: 'auction.stateSync',
          payload: await this.buildStateSyncPayload(queryRunner.manager, session),
        });
      }

      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }

    if (rescheduleOnly) {
      return;
    }

    for (const evt of events) {
      this.broadcast({ type: evt.type, sessionId, payload: evt.payload });
    }
    if (nextEndsAt) {
      this.scheduleLotTimer(sessionId, nextEndsAt);
    } else {
      this.clearTimer(sessionId);
    }
  }
}
