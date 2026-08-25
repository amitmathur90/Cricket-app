import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsString } from 'class-validator';
import { TournamentApplicationStatus } from '../../../database/entities/tournament-application.entity';

export class ReviewTournamentApplicationDto {
  @ApiProperty({
    enum: TournamentApplicationStatus,
    example: TournamentApplicationStatus.APPROVED,
    description:
      'Must be APPROVED or REJECTED — PENDING is only the initial default, not a valid transition target',
  })
  @IsEnum(TournamentApplicationStatus)
  status: TournamentApplicationStatus;

  @ApiPropertyOptional({ description: 'Reason, especially useful when rejecting' })
  @IsOptional()
  @IsString()
  note?: string;
}
