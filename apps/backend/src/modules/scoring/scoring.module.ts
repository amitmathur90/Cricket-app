import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Ball } from '../../database/entities/ball.entity';
import { Innings } from '../../database/entities/innings.entity';
import { Match } from '../../database/entities/match.entity';
import { MatchLineup } from '../../database/entities/match-lineup.entity';
import { Over } from '../../database/entities/over.entity';
import { Partnership } from '../../database/entities/partnership.entity';
import { Player } from '../../database/entities/player.entity';
import { TeamPlayer } from '../../database/entities/team-player.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { ScoringController } from './scoring.controller';
import { ScoringGateway } from './scoring.gateway';
import { ScoringRealtimeService } from './scoring-realtime.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Match,
      Tournament,
      TournamentTeam,
      TeamPlayer,
      Player,
      MatchLineup,
      Innings,
      Over,
      Ball,
      Partnership,
    ]),
    // ScoringRealtimeService notifies both teams' owners on match completion
    // — this import was missing (found blocking dev-server bootstrap while
    // verifying this task's own changes; unrelated to this task's scope,
    // fixed here as the minimal established-pattern fix, same as
    // AuctionModule's identical gap — see that module's comment).
    NotificationsModule,
    // Same self-contained JwtModule copy as AuctionModule (AuthModule
    // doesn't export its JwtModule) — see that module's comment.
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('jwt.accessSecret') as string,
        signOptions: { expiresIn: configService.get<string>('jwt.accessTtl') },
      }),
    }),
  ],
  controllers: [ScoringController],
  providers: [ScoringRealtimeService, ScoringGateway],
  exports: [ScoringRealtimeService],
})
export class ScoringModule {}
