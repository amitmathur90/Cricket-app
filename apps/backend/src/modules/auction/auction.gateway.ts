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
import { AuctionRealtimeService, PlaceBidInput } from './auction-realtime.service';

/**
 * First WebSocket gateway in this app. One room per auction session
 * (`auction:{auctionSessionId}`). Auth mirrors JwtAuthGuard's logic but is
 * done manually here since Nest guards don't run on the WS handshake the
 * same way — the client passes its access token via
 * `socket.handshake.auth.token` (the standard Socket.IO pattern), which we
 * verify and decode into the same AuthenticatedUser shape used by REST,
 * stashed on `socket.data.user` for every subsequent event on that socket.
 *
 * All actual business logic (validation, persistence, purse debits, lot
 * advancement) lives in AuctionRealtimeService — this class is just the
 * transport: decode/authorize, delegate, and relay broadcasts.
 */
@WebSocketGateway({ namespace: '/auction', cors: { origin: '*' } })
export class AuctionGateway implements OnModuleInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;

  private readonly logger = new Logger(AuctionGateway.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly realtimeService: AuctionRealtimeService,
  ) {}

  onModuleInit(): void {
    this.realtimeService.onBroadcast((evt) => {
      this.server.to(`auction:${evt.sessionId}`).emit(evt.type, evt.payload);
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
      socket.emit('auction.error', { message: 'Unauthorized' });
      socket.disconnect(true);
    }
  }

  handleDisconnect(_socket: Socket): void {
    // Socket.IO auto-leaves rooms on disconnect; no session state hangs off
    // the socket itself (it all lives in Postgres), so nothing else to do.
  }

  /** Join an auction session's room and receive a full state snapshot (reconnect recovery). */
  @SubscribeMessage('auction.join')
  async handleJoin(
    @ConnectedSocket() socket: Socket,
    @MessageBody() body: { auctionSessionId: string },
  ): Promise<void> {
    const user = socket.data.user as AuthenticatedUser | undefined;
    if (!user) {
      socket.emit('auction.error', { message: 'Unauthorized' });
      return;
    }
    try {
      const state = await this.realtimeService.getStateSync(user, body.auctionSessionId);
      await socket.join(`auction:${body.auctionSessionId}`);
      socket.emit('auction.stateSync', state);
    } catch (err) {
      socket.emit('auction.error', { message: (err as Error).message });
    }
  }

  @SubscribeMessage('auction.placeBid')
  async handlePlaceBid(@ConnectedSocket() socket: Socket, @MessageBody() body: PlaceBidInput): Promise<void> {
    const user = socket.data.user as AuthenticatedUser | undefined;
    if (!user) {
      socket.emit('auction.error', { message: 'Unauthorized' });
      return;
    }
    try {
      await this.realtimeService.placeBid(user, body);
      // Success is broadcast to the whole room via the onBroadcast relay
      // above (auction.bidPlaced) — nothing more to send this socket.
    } catch (err) {
      // Failure goes ONLY to the requesting socket, never the room, and
      // never mutates state (placeBid throws before persisting anything).
      socket.emit('auction.error', { message: (err as Error).message });
    }
  }
}
