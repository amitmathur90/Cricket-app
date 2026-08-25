import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsDateString,
  IsEmail,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import { TournamentFormat } from '../../../database/entities/tournament.entity';

export class CreateTournamentDto {
  @ApiProperty({ example: 'Summer Premier League 2026' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ enum: TournamentFormat, example: TournamentFormat.T20 })
  @IsEnum(TournamentFormat)
  format: TournamentFormat;

  @ApiProperty({ example: '2026-09-01' })
  @IsDateString()
  startDate: string;

  @ApiProperty({ example: '2026-09-15' })
  @IsDateString()
  endDate: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  auctionEnabled?: boolean;

  // --- Basic info ---

  @ApiPropertyOptional({ description: 'URL of the uploaded tournament logo (see POST .../uploads)' })
  @IsOptional()
  @IsString()
  logoUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  organizerName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsEmail()
  contactEmail?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  contactPhone?: string;

  // --- Tournament details ---

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  location?: string;

  @ApiPropertyOptional({ description: 'Target/max number of teams for this tournament' })
  @IsOptional()
  @IsInt()
  @Min(1)
  numberOfTeams?: number;

  @ApiPropertyOptional({ description: 'Max squad size per team' })
  @IsOptional()
  @IsInt()
  @Min(1)
  maxPlayersPerTeam?: number;

  // --- Rules ---

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  tournamentRules?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  matchRules?: string;

  @ApiPropertyOptional({ description: 'Free-text points system, e.g. "2 pts win, 1 pt tie"' })
  @IsOptional()
  @IsString()
  pointsSystem?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  tieBreakerRules?: string;

  // --- Registration ---

  @ApiPropertyOptional({ example: '2026-08-01' })
  @IsOptional()
  @IsDateString()
  registrationOpensAt?: string;

  @ApiPropertyOptional({ example: '2026-08-25' })
  @IsOptional()
  @IsDateString()
  registrationClosesAt?: string;

  @ApiPropertyOptional({ description: 'Per-player registration fee' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  playerRegistrationFee?: number;

  @ApiPropertyOptional({ description: 'Per-team registration fee' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  teamRegistrationFee?: number;
}
