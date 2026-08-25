import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { CoachStatus } from '../../../database/entities/coach.entity';

export class CreateCoachDto {
  @ApiProperty({ example: 'Rahul Dravid' })
  @IsString()
  @IsNotEmpty()
  fullName: string;

  @ApiPropertyOptional({ example: '+91 98765 43210' })
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiPropertyOptional({ example: 'coach@example.com' })
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional({ example: 'Batting coach', description: 'Free text, not a fixed enum' })
  @IsOptional()
  @IsString()
  specialization?: string;

  @ApiPropertyOptional({ description: 'URL of the uploaded coach photo (see POST .../uploads)' })
  @IsOptional()
  @IsString()
  photoUrl?: string;

  @ApiPropertyOptional({ enum: CoachStatus, default: CoachStatus.ACTIVE })
  @IsOptional()
  @IsEnum(CoachStatus)
  status?: CoachStatus;
}
