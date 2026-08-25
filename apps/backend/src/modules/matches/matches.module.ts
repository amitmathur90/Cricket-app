import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MatchLineup } from '../../database/entities/match-lineup.entity';
import { Match } from '../../database/entities/match.entity';
import { Official } from '../../database/entities/official.entity';
import { TeamPlayer } from '../../database/entities/team-player.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { Venue } from '../../database/entities/venue.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { MatchLineupController } from './match-lineup.controller';
import { MatchLineupService } from './match-lineup.service';
import { MatchesController } from './matches.controller';
import { MatchesService } from './matches.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Match, Tournament, TournamentTeam, TeamPlayer, MatchLineup, Venue, Official]),
    NotificationsModule,
  ],
  controllers: [MatchesController, MatchLineupController],
  providers: [MatchesService, MatchLineupService],
  exports: [MatchesService, MatchLineupService],
})
export class MatchesModule {}
