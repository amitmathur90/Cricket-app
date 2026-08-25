import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsOptional, Min } from 'class-validator';

/**
 * General roster-entry update — the gap left by `PlayersController.addToRoster`
 * being create-only. Covers everything settable at creation that should also
 * be editable afterward: captain/vice-captain flags, jersey number, and the
 * wicketkeeper flag. Captain/vice-captain exclusivity (at most one of each per
 * `tournament_team`, and a player can't hold both simultaneously) is enforced
 * server-side in TeamsService, not here.
 */
export class UpdateRosterEntryDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isCaptain?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isViceCaptain?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  jerseyNumber?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isWicketkeeper?: boolean;
}
