import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Player } from '../../database/entities/player.entity';
import { TournamentApplication } from '../../database/entities/tournament-application.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { PlayersModule } from '../players/players.module';
import { TournamentApplicationsController } from './tournament-applications.controller';
import { TournamentApplicationsService } from './tournament-applications.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([TournamentApplication, Tournament, Player]),
    PlayersModule,
    NotificationsModule,
  ],
  controllers: [TournamentApplicationsController],
  providers: [TournamentApplicationsService],
  exports: [TournamentApplicationsService],
})
export class TournamentApplicationsModule {}
