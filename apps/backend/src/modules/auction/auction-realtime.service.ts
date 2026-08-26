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
 * resuming sessions, accepting bids, and resolving lots via explicit
 * admin action — markSold/markUnsold finalize the current lot's outcome,
 * advanceToNextLot then moves to the next pending lot (or completes the
 * session). There is deliberately no timer anywhere in this class: no lot
 * ever auto-resolves and no session ever auto-advances. Both
 * AuctionController (REST: start/pause/resume/mark-sold/mark-unsold/
 * next-lot) and AuctionGateway (WS: placeBid, join) call into this single
 * service.
 *
 * Concurrency: every mutation of a session's "current lot" state
 * (placeBid, markSold, markUnsold, advanceToNextLot) runs inside a DB
 * transaction that takes a `SELECT ... FOR UPDATE` row lock on the
 * auction_sessions row first, so two near-simultaneous admin actions (or a
 * bid racing an admin's mark-sold click) are fully serialized: whichever
 * request acquires the lock first commits its effect before the second is
 * even evaluated. A DB lock was chosen over an in-process mutex because
 * the "current lot" fields already live in Postgres as the source of
 * truth (needed for REST reads / reconnect state-sync anyway), so locking
 * there covers both this single-instance process AND any future
 * horizontally-scaled deployment for free.
 */
@Injectable()
export class AuctionRealtimeService {
  private readonly logger = new Logger(AuctionRealtimeService.name);
  private readonly emitter = new EventEmitter();

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

  /** Counts a team's current roster size against the session's configured
   * cap (if any) — used both to reject a bid from an already-full team and
   * to surface "SQUAD FULL" in state-sync payloads. Returns false (not
   * full) when maxSquadSize is unset. */
  private async isSquadFull(
    manager: EntityManager,
    session: AuctionSession,
    tournamentTeamId: string,
  ): Promise<boolean> {
    if (session.maxSquadSize == null) return false;
    const count = await manager.count(TeamPlayer, { where: { tournamentTeamId } });
    return count >= session.maxSquadSize;
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
          /** True once the admin has clicked SOLD/UNSOLD for this lot —
           * the UI shows the sold/unsold confirmation and a "Next Player"
           * button once this flips true, rather than the bidding controls. */
          resolved: poolEntry.status !== AuctionPoolStatus.IN_PROGRESS,
        };
      }
    }

    return {
      session: {
        id: session.id,
        name: session.name,
        status: session.status,
        tournamentId: session.tournamentId,
        durationMinutes: session.durationMinutes,
        maxSquadSize: session.maxSquadSize,
        // Combined with durationMinutes, lets a client compute and display
        // an overall "auction time remaining" countdown (startedAt +
        // durationMinutes). Purely informational — nothing here enforces it.
        startedAt: session.startedAt,
      },
      currentLot,
      remainingPoolCount,
      teams: await Promise.all(
        teams.map(async (t) => ({
          tournamentTeamId: t.id,
          teamName: t.team.name,
          purseTotal: t.purseTotal,
          purseRemaining: t.purseRemaining,
          squadFull: await this.isSquadFull(manager, session, t.id),
        })),
      ),
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

    // "Every team receives the configured default points" — applied once,
    // here, rather than at team-registration time, so it reflects this
    // session's settings even if teams registered before the session (or
    // its defaultTeamPoints) existed.
    const registeredTeams = await this.tournamentTeamRepo.find({
      where: { tournamentId: session.tournamentId },
      relations: ['team'],
    });
    if (session.defaultTeamPoints != null) {
      for (const team of registeredTeams) {
        team.purseTotal = session.defaultTeamPoints;
        team.purseRemaining = session.defaultTeamPoints;
      }
      await this.tournamentTeamRepo.save(registeredTeams);
    }

    session.status = AuctionSessionStatus.LIVE;
    session.startedAt = new Date();
    session.currentPlayerId = firstLot.playerId;
    session.currentBidAmount = firstLot.basePrice;
    session.currentBidTeamId = null;
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
      },
    });

    // Notify every registered team's owner in this tournament that the
    // auction has gone live.
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

  /** Freezes bidding — placeBid checks session.status === LIVE, so a
   * PAUSED session simply rejects new bids until resumed. No timer to
   * stop; this is purely a status flip + broadcast. */
  async pauseSession(organizationId: string, sessionId: string): Promise<AuctionSession> {
    const session = await this.getOrgScopedSession(organizationId, sessionId);
    if (session.status !== AuctionSessionStatus.LIVE) {
      throw new BadRequestException('Session is not live');
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
    session.status = AuctionSessionStatus.LIVE;
    const saved = await this.sessionRepo.save(session);
    this.broadcast({
      type: 'auction.stateSync',
      sessionId,
      payload: await this.buildStateSyncPayload(this.dataSource.manager, saved),
    });
    return saved;
  }

  /** Admin marks the current lot SOLD to whoever the leading bidder is —
   * requires a current bid. Deducts the winning team's purse, upserts the
   * roster, and marks the pool entry SOLD, but does NOT advance to the
   * next lot; that's a separate explicit advanceToNextLot() call, so the
   * UI can show a "Player Sold" confirmation before moving on. */
  async markSold(organizationId: string, sessionId: string): Promise<AuctionSession> {
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
      const tournament = await queryRunner.manager.findOne(Tournament, { where: { id: session.tournamentId } });
      if (!tournament || tournament.organizationId !== organizationId) {
        throw new NotFoundException('Auction session not found');
      }
      if (session.status !== AuctionSessionStatus.LIVE) {
        throw new BadRequestException('Auction session is not live');
      }
      if (!session.currentPlayerId) {
        throw new BadRequestException('No lot is currently under the hammer');
      }
      if (!session.currentBidTeamId || !session.currentBidAmount) {
        throw new BadRequestException('No bids have been placed on this lot — mark it UNSOLD instead');
      }

      const poolEntry = await queryRunner.manager.findOne(AuctionPlayerPool, {
        where: { auctionSessionId: sessionId, playerId: session.currentPlayerId },
      });
      if (!poolEntry) throw new NotFoundException('Current lot not found in pool');
      if (poolEntry.status !== AuctionPoolStatus.IN_PROGRESS) {
        throw new BadRequestException('This lot has already been resolved');
      }

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

      broadcastPayload = {
        playerId: poolEntry.playerId,
        poolEntryId: poolEntry.id,
        finalPrice: poolEntry.finalPrice,
        soldToTeamId: team.id,
        soldToTeamName: teamBrand?.name ?? null,
        purseRemaining: remainingAfter,
      };

      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }

    if (broadcastPayload) {
      this.broadcast({ type: 'auction.playerSold', sessionId, payload: broadcastPayload });
    }
    return this.getOrgScopedSession(organizationId, sessionId);
  }

  /** Admin marks the current lot UNSOLD — always allowed regardless of
   * whether there's a current leading bid (an admin can override and
   * decline to sell even with active bids). No purse ever moves for an
   * UNSOLD lot. Does not advance; see markSold's doc comment. */
  async markUnsold(organizationId: string, sessionId: string): Promise<AuctionSession> {
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
      const tournament = await queryRunner.manager.findOne(Tournament, { where: { id: session.tournamentId } });
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
      if (poolEntry.status !== AuctionPoolStatus.IN_PROGRESS) {
        throw new BadRequestException('This lot has already been resolved');
      }

      poolEntry.status = AuctionPoolStatus.UNSOLD;
      await queryRunner.manager.save(AuctionPlayerPool, poolEntry);

      broadcastPayload = { playerId: poolEntry.playerId, poolEntryId: poolEntry.id };

      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }

    if (broadcastPayload) {
      this.broadcast({ type: 'auction.playerUnsold', sessionId, payload: broadcastPayload });
    }
    return this.getOrgScopedSession(organizationId, sessionId);
  }

  /** Admin clicks "Next Player" — moves to the next pending lot, or
   * completes the session if none remain. Requires the current lot to
   * already be resolved (SOLD/UNSOLD via the methods above), so a lot can
   * never be skipped past without an explicit outcome recorded. */
  async advanceToNextLot(organizationId: string, sessionId: string): Promise<AuctionSession> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    let event: { type: AuctionBroadcastEventType; payload: unknown } | null = null;

    try {
      const session = await queryRunner.manager.findOne(AuctionSession, {
        where: { id: sessionId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!session) throw new NotFoundException('Auction session not found');
      const tournament = await queryRunner.manager.findOne(Tournament, { where: { id: session.tournamentId } });
      if (!tournament || tournament.organizationId !== organizationId) {
        throw new NotFoundException('Auction session not found');
      }
      if (session.status !== AuctionSessionStatus.LIVE) {
        throw new BadRequestException('Auction session is not live');
      }

      if (session.currentPlayerId) {
        const current = await queryRunner.manager.findOne(AuctionPlayerPool, {
          where: { auctionSessionId: sessionId, playerId: session.currentPlayerId },
        });
        if (current && current.status === AuctionPoolStatus.IN_PROGRESS) {
          throw new BadRequestException('Mark the current lot SOLD or UNSOLD before advancing');
        }
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
        await queryRunner.manager.save(AuctionSession, session);

        event = {
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
          },
        };
      } else {
        session.status = AuctionSessionStatus.COMPLETED;
        session.currentPlayerId = null;
        session.currentBidAmount = null;
        session.currentBidTeamId = null;
        session.endedAt = new Date();
        await queryRunner.manager.save(AuctionSession, session);
        event = {
          type: 'auction.stateSync',
          payload: await this.buildStateSyncPayload(queryRunner.manager, session),
        };
      }

      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }

    if (event) {
      this.broadcast({ type: event.type, sessionId, payload: event.payload });
    }
    return this.getOrgScopedSession(organizationId, sessionId);
  }

  /**
   * Places a bid, server-authoritatively. Validates session/team/amount
   * inside a row-locked transaction, persists the bid + updated leading
   * bid, then broadcasts. There is no bidding-window deadline — a lot
   * stays open to bids until the admin manually marks it SOLD/UNSOLD (see
   * markSold/markUnsold). On any validation failure it throws before
   * mutating anything — the caller (gateway) is responsible for routing
   * the error back to just the requesting socket, not the room.
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
      if (!session.currentPlayerId) {
        throw new BadRequestException('No lot is currently under the hammer');
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
      if (await this.isSquadFull(queryRunner.manager, session, team.id)) {
        throw new BadRequestException('SQUAD FULL — this team has reached its maximum roster size');
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

      session.currentBidAmount = amount.toFixed(2);
      session.currentBidTeamId = team.id;
      await queryRunner.manager.save(AuctionSession, session);

      broadcastPayload = {
        auctionSessionId,
        poolEntryId: poolEntry.id,
        teamId: team.id,
        teamName: team.team.name,
        amount: amount.toFixed(2),
        bidSequence,
      };

      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }

    if (broadcastPayload) {
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

}
