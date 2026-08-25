import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Ball } from '../../database/entities/ball.entity';
import { Innings } from '../../database/entities/innings.entity';
import { Match } from '../../database/entities/match.entity';
import { Player } from '../../database/entities/player.entity';
import { TeamPlayer } from '../../database/entities/team-player.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { PlayersController } from './players.controller';
import { PlayersService } from './players.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Player, TournamentTeam, TeamPlayer, Ball, Innings, Match]),
    NotificationsModule,
  ],
  controllers: [PlayersController],
  providers: [PlayersService],
  exports: [PlayersService],
})
export class PlayersModule {}
