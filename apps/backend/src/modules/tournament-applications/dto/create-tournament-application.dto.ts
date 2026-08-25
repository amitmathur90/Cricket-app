import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { PlayerRole } from '../../../database/entities/player.entity';

/**
 * Same shape as CreatePlayerDto, minus `userId`/`dob`: `userId` is forced to
 * the calling (authenticated) user rather than caller-supplied, and `dob`
 * isn't collected in this self-service flow. If the caller already has a
 * Player profile in this org, these fields are ignored entirely and the
 * existing profile is reused as-is — see TournamentApplicationsService.apply.
 */
export class CreateTournamentApplicationDto {
  @ApiProperty({ example: 'Virat Kohli' })
  @IsString()
  @IsNotEmpty()
  fullName: string;

  @ApiProperty({ enum: PlayerRole, example: PlayerRole.BATSMAN })
  @IsEnum(PlayerRole)
  role: PlayerRole;

  @ApiPropertyOptional({ example: 'Right-hand bat' })
  @IsOptional()
  @IsString()
  battingStyle?: string;

  @ApiPropertyOptional({ example: 'Right-arm medium' })
  @IsOptional()
  @IsString()
  bowlingStyle?: string;

  @ApiProperty({ description: 'URL of the uploaded player photo (see POST .../uploads)' })
  @IsString()
  @IsNotEmpty()
  photoUrl: string;

  @ApiProperty({
    description: 'URL of the uploaded ID document, e.g. passport/Aadhaar (see POST .../uploads)',
  })
  @IsString()
  @IsNotEmpty()
  idDocumentUrl: string;

  @ApiProperty({ example: 'U19', description: 'Age category / group, e.g. U16, U19, Senior, Open' })
  @IsString()
  @IsNotEmpty()
  ageCategory: string;

  @ApiProperty({ description: 'Free-text summary of prior teams/tournaments/statistics' })
  @IsString()
  @IsNotEmpty()
  previousStatsNotes: string;

  @ApiPropertyOptional({ description: 'Auction base price' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  basePrice?: number;
}
