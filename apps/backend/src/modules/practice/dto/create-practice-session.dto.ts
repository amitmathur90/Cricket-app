import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsEnum, IsInt, IsOptional, IsString, IsUUID, Min } from 'class-validator';
import { PracticeType } from '../../../database/entities/practice-session.entity';

/**
 * `teamId` comes from the route, not the body. `practiceType` and
 * `scheduledAt` are the only required fields — the minimum needed for a
 * session to mean anything on a calendar ("what kind of practice, and
 * when"). Coach/venue/duration/notes are all fillable later via PATCH, same
 * "cheap to create, filled in incrementally" pattern as CreateMatchDto.
 */
export class CreatePracticeSessionDto {
  @ApiProperty({ enum: PracticeType, example: PracticeType.NET_PRACTICE })
  @IsEnum(PracticeType)
  practiceType: PracticeType;

  @ApiProperty({ example: '2026-09-05T14:30:00.000Z' })
  @IsDateString()
  scheduledAt: string;

  @ApiPropertyOptional({ description: 'Coach id — must belong to the same organization' })
  @IsOptional()
  @IsUUID()
  coachId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  venueName?: string;

  @ApiPropertyOptional({ example: 90 })
  @IsOptional()
  @IsInt()
  @Min(1)
  durationMinutes?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}
