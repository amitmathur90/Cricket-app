import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsEmail,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';
import { PlayerRole } from '../../../database/entities/player.entity';

export class CreatePlayerDto {
  @ApiProperty({ example: 'Virat Kohli' })
  @IsString()
  @IsNotEmpty()
  fullName: string;

  @ApiPropertyOptional({ description: 'Link this player profile to an existing user account' })
  @IsOptional()
  @IsUUID()
  userId?: string;

  @ApiPropertyOptional({ example: '1988-11-05' })
  @IsOptional()
  @IsDateString()
  dob?: string;

  // --- Personal information ---

  @ApiPropertyOptional({ example: 'male', description: 'Free text, not a fixed enum' })
  @IsOptional()
  @IsString()
  gender?: string;

  @ApiPropertyOptional({ example: '+91 98765 43210' })
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiPropertyOptional({ example: 'player@example.com' })
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional({ example: '221B Baker Street, Mumbai' })
  @IsOptional()
  @IsString()
  address?: string;

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

  @ApiPropertyOptional({
    example: '5 years club cricket',
    description: 'Free-text experience description',
  })
  @IsOptional()
  @IsString()
  experience?: string;

  @ApiPropertyOptional({ example: 'Opening batsman / slip fielder' })
  @IsOptional()
  @IsString()
  preferredPosition?: string;

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

  @ApiPropertyOptional({
    description: 'URL of an uploaded proof-of-address document (see POST .../uploads)',
  })
  @IsOptional()
  @IsString()
  addressProofUrl?: string;

  @ApiPropertyOptional({
    type: [String],
    description: 'URLs of other supporting documents (certificates, prior-team letters, etc.)',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  otherDocumentUrls?: string[];

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
