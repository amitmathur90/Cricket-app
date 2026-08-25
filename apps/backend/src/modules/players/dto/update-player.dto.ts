import { ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString } from 'class-validator';
import { CreatePlayerDto } from './create-player.dto';

/** All CreatePlayerDto fields, optional — plus availability, which is only ever set via update. */
export class UpdatePlayerDto extends PartialType(CreatePlayerDto) {
  /** @deprecated Superseded by isAvailableFor{Tournaments,Matches,Practice} — kept for the existing single-toggle UI. */
  @ApiPropertyOptional({
    description:
      'Deprecated single-flag availability toggle, kept for the existing UI. Prefer the granular isAvailableFor* flags below.',
  })
  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;

  /** @deprecated See isAvailable. */
  @ApiPropertyOptional({ description: 'Why the player is unavailable, when isAvailable is false' })
  @IsOptional()
  @IsString()
  unavailabilityReason?: string;

  @ApiPropertyOptional({ description: 'Whether the player is available to be picked for tournaments' })
  @IsOptional()
  @IsBoolean()
  isAvailableForTournaments?: boolean;

  @ApiPropertyOptional({ description: 'Whether the player is available to be picked for matches' })
  @IsOptional()
  @IsBoolean()
  isAvailableForMatches?: boolean;

  @ApiPropertyOptional({ description: 'Whether the player is available for practice sessions' })
  @IsOptional()
  @IsBoolean()
  isAvailableForPractice?: boolean;
}
