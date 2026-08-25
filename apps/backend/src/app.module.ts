import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import configuration from './config/configuration';
import { validate } from './config/env.validation';
import { allEntities } from './database/entities';
import { AuctionModule } from './modules/auction/auction.module';
import { AuthModule } from './modules/auth/auth.module';
import { CoachesModule } from './modules/coaches/coaches.module';
import { FinanceModule } from './modules/finance/finance.module';
import { MatchesModule } from './modules/matches/matches.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { OfficialsModule } from './modules/officials/officials.module';
import { OrganizationsModule } from './modules/organizations/organizations.module';
import { PlayersModule } from './modules/players/players.module';
import { PostsModule } from './modules/posts/posts.module';
import { PracticeModule } from './modules/practice/practice.module';
import { PublicModule } from './modules/public/public.module';
import { ScoringModule } from './modules/scoring/scoring.module';
import { SponsorsModule } from './modules/sponsors/sponsors.module';
import { TeamsModule } from './modules/teams/teams.module';
import { TournamentApplicationsModule } from './modules/tournament-applications/tournament-applications.module';
import { TournamentsModule } from './modules/tournaments/tournaments.module';
import { UploadsModule } from './modules/uploads/uploads.module';
import { UsersModule } from './modules/users/users.module';
import { VenuesModule } from './modules/venues/venues.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      validate,
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres' as const,
        url: configService.get<string>('database.url'),
        entities: allEntities,
        migrations: [__dirname + '/database/migrations/*.{ts,js}'],
        synchronize: configService.get<boolean>('database.synchronize'),
        logging: configService.get<boolean>('database.logging'),
      }),
    }),
    AuthModule,
    OrganizationsModule,
    UsersModule,
    TournamentsModule,
    TeamsModule,
    PlayersModule,
    UploadsModule,
    AuctionModule,
    TournamentApplicationsModule,
    MatchesModule,
    CoachesModule,
    PracticeModule,
    ScoringModule,
    VenuesModule,
    OfficialsModule,
    SponsorsModule,
    FinanceModule,
    NotificationsModule,
    PostsModule,
    PublicModule,
  ],
})
export class AppModule {}
