import { Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { AuthenticatedUser } from '../../common/types/authenticated-user';
import { JwtAccessPayload } from '../auth/strategies/jwt.strategy';
import { NewBowlerDto } from './dto/new-bowler.dto';
import { RecordBallDto } from './dto/record-ball.dto';
import { StartInningsDto } from './dto/start-innings.dto';
import { StartMatchDto } from './dto/start-match.dto';
import { ScoringRealtimeService } from './scoring-realtime.service';

/**
 * Second WebSocket gateway in this app, structurally identical to
 * AuctionGateway (same namespace/room/handshake-auth pattern — see that
 * file's doc comment for the rationale, unchanged here): one room per match
 * (`match:{matchId}`), manual JWT verification on handshake (Nest guards
 * don't run on the WS upgrade), and all business logic delegated to
 * ScoringRealtimeService so REST-triggered and WS-triggered mutations go
 * through the exact same code path.
 *
 * Every client->server payload includes `organizationId` alongside
 * `matchId` (rather than deriving org from a server-side session lookup
 * the way AuctionGateway derives it from the auction session) because a
 * match's tenancy isn't otherwise resolvable from the socket alone before
 * the match is loaded — ScoringRealtimeService still independently
 * verifies the caller's JWT `activeOrgId` against the match's actual
 * tournament.organizationId, so a client cannot spoof this value into
 * gaining cross-tenant access.
 */
@WebSocketGateway({ namespace: '/scoring', cors: { origin: '*' } })
export class ScoringGateway implements OnModuleInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;

  private readonly logger = new Logger(ScoringGateway.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly realtimeService: ScoringRealtimeService,
  ) {}

  onModuleInit(): void {
    this.realtimeService.onBroadcast((evt) => {
      this.server.to(`match:${evt.matchId}`).emit(evt.type, evt.payload);
    });
  }

  handleConnection(socket: Socket): void {
    try {
      const token = socket.handshake.auth?.token as string | undefined;
      if (!token) {
        throw new Error('Missing auth token');
      }
      const payload = this.jwtService.verify<JwtAccessPayload>(token, {
        secret: this.configService.get<string>('jwt.accessSecret'),
      });
      const user: AuthenticatedUser = {
        userId: payload.sub,
        isSuperAdmin: payload.isSuperAdmin,
        activeOrgId: payload.activeOrgId ?? null,
        role: payload.role ?? null,
      };
      socket.data.user = user;
    } catch (err) {
      this.logger.warn(`Rejecting unauthenticated socket ${socket.id}: ${(err as Error).message}`);
      socket.emit('scoring.error', { message: 'Unauthorized' });
      socket.disconnect(true);
    }
  }

  handleDisconnect(_socket: Socket): void {
    // Same as AuctionGateway: no session state hangs off the socket itself
    // (it all lives in Postgres), so nothing else to do on disconnect.
  }

  private getUser(socket: Socket): AuthenticatedUser | undefined {
    return socket.data.user as AuthenticatedUser | undefined;
  }

  /** Join a match's room and receive a full state snapshot (reconnect recovery). */
  @SubscribeMessage('scoring.join')
  async handleJoin(
    @ConnectedSocket() socket: Socket,
    @MessageBody() body: { organizationId: string; matchId: string },
  ): Promise<void> {
    const user = this.getUser(socket);
    if (!user) {
      socket.emit('scoring.error', { message: 'Unauthorized' });
      return;
    }
    try {
      const state = await this.realtimeService.getLiveState(body.organizationId, body.matchId);
      await socket.join(`match:${body.matchId}`);
      socket.emit('scoring.stateSync', state);
    } catch (err) {
      socket.emit('scoring.error', { message: (err as Error).message });
    }
  }

  @SubscribeMessage('scoring.startMatch')
  async handleStartMatch(
    @ConnectedSocket() socket: Socket,
    @MessageBody() body: { organizationId: string; matchId: string } & StartMatchDto,
  ): Promise<void> {
    const user = this.getUser(socket);
    if (!user) {
      socket.emit('scoring.error', { message: 'Unauthorized' });
      return;
    }
    const { organizationId, matchId, ...dto } = body;
    try {
      await this.realtimeService.startMatch(user, organizationId, matchId, dto);
    } catch (err) {
      socket.emit('scoring.error', { message: (err as Error).message });
    }
  }

  @SubscribeMessage('scoring.startInnings')
  async handleStartInnings(
    @ConnectedSocket() socket: Socket,
    @MessageBody() body: { organizationId: string; matchId: string } & StartInningsDto,
  ): Promise<void> {
    const user = this.getUser(socket);
    if (!user) {
      socket.emit('scoring.error', { message: 'Unauthorized' });
      return;
    }
    const { organizationId, matchId, ...dto } = body;
    try {
      await this.realtimeService.startInnings(user, organizationId, matchId, dto);
    } catch (err) {
      socket.emit('scoring.error', { message: (err as Error).message });
    }
  }

  @SubscribeMessage('scoring.newBowler')
  async handleNewBowler(
    @ConnectedSocket() socket: Socket,
    @MessageBody() body: { organizationId: string; matchId: string } & NewBowlerDto,
  ): Promise<void> {
    const user = this.getUser(socket);
    if (!user) {
      socket.emit('scoring.error', { message: 'Unauthorized' });
      return;
    }
    const { organizationId, matchId, ...dto } = body;
    try {
      await this.realtimeService.newBowler(user, organizationId, matchId, dto);
    } catch (err) {
      socket.emit('scoring.error', { message: (err as Error).message });
    }
  }

  @SubscribeMessage('scoring.recordBall')
  async handleRecordBall(
    @ConnectedSocket() socket: Socket,
    @MessageBody() body: { organizationId: string; matchId: string } & RecordBallDto,
  ): Promise<void> {
    const user = this.getUser(socket);
    if (!user) {
      socket.emit('scoring.error', { message: 'Unauthorized' });
      return;
    }
    const { organizationId, matchId, ...dto } = body;
    try {
      await this.realtimeService.recordBall(user, organizationId, matchId, dto);
      // Success is broadcast to the whole room via the onBroadcast relay
      // above (scoring.ballRecorded, + inningsCompleted/matchCompleted as
      // applicable) — nothing more to send this socket.
    } catch (err) {
      // Failure goes ONLY to the requesting socket, never the room, and
      // never mutates state (recordBall throws before persisting anything).
      socket.emit('scoring.error', { message: (err as Error).message });
    }
  }

  @SubscribeMessage('scoring.undoLastBall')
  async handleUndoLastBall(
    @ConnectedSocket() socket: Socket,
    @MessageBody() body: { organizationId: string; matchId: string },
  ): Promise<void> {
    const user = this.getUser(socket);
    if (!user) {
      socket.emit('scoring.error', { message: 'Unauthorized' });
      return;
    }
    try {
      await this.realtimeService.undoLastBall(user, body.organizationId, body.matchId);
    } catch (err) {
      socket.emit('scoring.error', { message: (err as Error).message });
    }
  }

  @SubscribeMessage('scoring.endInnings')
  async handleEndInnings(
    @ConnectedSocket() socket: Socket,
    @MessageBody() body: { organizationId: string; matchId: string },
  ): Promise<void> {
    const user = this.getUser(socket);
    if (!user) {
      socket.emit('scoring.error', { message: 'Unauthorized' });
      return;
    }
    try {
      await this.realtimeService.endInnings(user, body.organizationId, body.matchId);
    } catch (err) {
      socket.emit('scoring.error', { message: (err as Error).message });
    }
  }
}
