import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

/** Used by team-fees/player-fees — unlike the dashboard, tournamentId is required (fees are per-tournament). */
export class TournamentScopeQueryDto {
  @ApiProperty()
  @IsUUID()
  tournamentId: string;
}
