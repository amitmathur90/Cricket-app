import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

/**
 * Starts the second innings. The batting/bowling teams are auto-derived by
 * swapping innings 1's teams — only the new opening pair + bowler need to
 * be supplied.
 */
export class StartInningsDto {
  @ApiProperty({ description: "team_players id — this innings' opening striker" })
  @IsUUID()
  openingStrikerTeamPlayerId: string;

  @ApiProperty({ description: "team_players id — this innings' opening non-striker" })
  @IsUUID()
  openingNonStrikerTeamPlayerId: string;

  @ApiProperty({ description: "team_players id — this innings' opening bowler" })
  @IsUUID()
  openingBowlerTeamPlayerId: string;
}
