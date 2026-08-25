import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsOptional, IsString, IsUUID } from 'class-validator';

/**
 * All fields optional — the spec treats "Create match" as distinct from
 * "Assign teams"/"Assign venue"/"Assign umpire"/"Assign scorer"/"Reschedule",
 * so a bare `POST {}` must succeed and produce an empty, TBD-vs-TBD,
 * scheduled-status match that gets filled in later via PATCH.
 */
export class CreateMatchDto {
  @ApiPropertyOptional({ description: 'Home team — must be a tournament_teams row in this tournament' })
  @IsOptional()
  @IsUUID()
  homeTournamentTeamId?: string;

  @ApiPropertyOptional({ description: 'Away team — must be a tournament_teams row in this tournament' })
  @IsOptional()
  @IsUUID()
  awayTournamentTeamId?: string;

  @ApiPropertyOptional({ example: '2026-09-05T14:30:00.000Z' })
  @IsOptional()
  @IsDateString()
  scheduledAt?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  venueName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  umpireName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  scorerName?: string;

  // --- Optional real-record assignment (dual-field approach, see Match entity doc) ---
  // Alongside the free-text fields above, a match may optionally point at a
  // real Venue/Official row from the venues/officials modules. Both can be
  // set independently; the free-text fields are never overwritten by these.

  @ApiPropertyOptional({ description: 'Must be a `venues` row belonging to this organization' })
  @IsOptional()
  @IsUUID()
  venueId?: string;

  @ApiPropertyOptional({ description: 'Must be an `officials` row (role=umpire) belonging to this organization' })
  @IsOptional()
  @IsUUID()
  umpireOfficialId?: string;

  @ApiPropertyOptional({ description: 'Must be an `officials` row (role=scorer) belonging to this organization' })
  @IsOptional()
  @IsUUID()
  scorerOfficialId?: string;

  @ApiPropertyOptional({
    description: 'Must be an `officials` row (role=match_referee) belonging to this organization',
  })
  @IsOptional()
  @IsUUID()
  matchRefereeOfficialId?: string;
}
