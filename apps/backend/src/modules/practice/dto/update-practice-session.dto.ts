import { ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { IsEnum, IsOptional } from 'class-validator';
import { PracticeSessionStatus } from '../../../database/entities/practice-session.entity';
import { CreatePracticeSessionDto } from './create-practice-session.dto';

/**
 * Single generic partial-update DTO — mirrors UpdateMatchDto. Covers every
 * distinct field (reassign coach, change venue/type/duration/notes,
 * reschedule) plus status transitions, including cancellation
 * (`{ status: 'cancelled' }`) as an alternative to DELETE. Practice
 * sessions are lower-stakes than matches, so unlike UpdateMatchDto's
 * companion (a soft-cancel/hard-delete split), DELETE here is a plain hard
 * delete — PATCH status is just offered as a convenience for callers who
 * prefer not to lose the row.
 */
export class UpdatePracticeSessionDto extends PartialType(CreatePracticeSessionDto) {
  @ApiPropertyOptional({ enum: PracticeSessionStatus })
  @IsOptional()
  @IsEnum(PracticeSessionStatus)
  status?: PracticeSessionStatus;
}
