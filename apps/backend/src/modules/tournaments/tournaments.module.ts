import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Ball } from '../../database/entities/ball.entity';
import { Innings } from '../../database/entities/innings.entity';
import { Match } from '../../database/entities/match.entity';
import { Player } from '../../database/entities/player.entity';
import { TeamPlayer } from '../../database/entities/team-player.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { TournamentsController } from './tournaments.controller';
import { TournamentsService } from './tournaments.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Tournament, TournamentTeam, Match, Innings, Ball, TeamPlayer, Player]),
  ],
  controllers: [TournamentsController],
  providers: [TournamentsService],
  exports: [TournamentsService],
})
export class TournamentsModule {}
