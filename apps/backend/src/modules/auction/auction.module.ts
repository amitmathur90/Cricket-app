import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuctionBid } from '../../database/entities/auction-bid.entity';
import { AuctionPlayerPool } from '../../database/entities/auction-player-pool.entity';
import { AuctionSession } from '../../database/entities/auction-session.entity';
import { Player } from '../../database/entities/player.entity';
import { PurseLedger } from '../../database/entities/purse-ledger.entity';
import { TeamPlayer } from '../../database/entities/team-player.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { AuctionGateway } from './auction.gateway';
import { AuctionRealtimeService } from './auction-realtime.service';
import { AuctionController, PlayerPurchaseHistoryController } from './auction.controller';
import { AuctionService } from './auction.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      AuctionSession,
      AuctionPlayerPool,
      AuctionBid,
      PurseLedger,
      TeamPlayer,
      Player,
      Tournament,
      TournamentTeam,
    ]),
    // AuctionRealtimeService fires notifications on auction-session-start/
    // lot-sold events (see NotificationsModule's doc comment for the
    // event-triggered-notification pattern every other feature module here
    // follows) — this import was missing (pre-existing bug found while
    // getting the dev server to boot for this task's verification, fixed
    // here as the one-line, established-pattern fix; unrelated to the
    // Player Statistics awards/rankings work this task otherwise covers).
    NotificationsModule,
    // Registered directly here (rather than importing AuthModule) since
    // AuthModule doesn't export its JwtModule — the gateway only needs
    // JwtService.verify() with the same access-token secret used everywhere
    // else, so this stays a self-contained, identically-configured copy.
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('jwt.accessSecret') as string,
        signOptions: { expiresIn: configService.get<string>('jwt.accessTtl') },
      }),
    }),
  ],
  controllers: [AuctionController, PlayerPurchaseHistoryController],
  providers: [AuctionService, AuctionRealtimeService, AuctionGateway],
  exports: [AuctionService, AuctionRealtimeService],
})
export class AuctionModule {}
