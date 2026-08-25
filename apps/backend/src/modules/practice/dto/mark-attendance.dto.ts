import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsEnum, IsUUID, ValidateNested } from 'class-validator';
import { PracticeAttendanceStatus } from '../../../database/entities/practice-attendance.entity';

export class AttendanceEntryDto {
  @ApiProperty({ description: 'Player id — any org-level player, no roster/tournament membership check' })
  @IsUUID()
  playerId: string;

  @ApiProperty({ enum: PracticeAttendanceStatus })
  @IsEnum(PracticeAttendanceStatus)
  status: PracticeAttendanceStatus;
}

/**
 * Bulk upsert body — the realistic "take attendance for the whole session"
 * use case. Marking a single player is just a one-element `entries` array,
 * so there's no separate single-mark shape to branch on. Each entry is
 * create-or-update per (practiceSessionId, playerId): see
 * PracticeAttendanceService.markAttendance.
 */
export class MarkAttendanceDto {
  @ApiProperty({ type: [AttendanceEntryDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => AttendanceEntryDto)
  entries: AttendanceEntryDto[];
}
