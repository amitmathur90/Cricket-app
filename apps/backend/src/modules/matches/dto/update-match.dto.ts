import { ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { IsEnum, IsOptional } from 'class-validator';
import { MatchStatus } from '../../../database/entities/match.entity';
import { CreateMatchDto } from './create-match.dto';

/**
 * Single generic partial-update DTO covering every distinct admin action in
 * the spec — "Assign teams" (home/awayTournamentTeamId), "Assign venue"
 * (venueName), "Assign umpire"/"Assign scorer", "Reschedule" (scheduledAt),
 * and status transitions — rather than one endpoint per action. A PATCH
 * `{ status: 'cancelled' }` is the soft "Cancel match" action; see
 * MatchesController for the separate hard-delete endpoint.
 */
export class UpdateMatchDto extends PartialType(CreateMatchDto) {
  @ApiPropertyOptional({ enum: MatchStatus })
  @IsOptional()
  @IsEnum(MatchStatus)
  status?: MatchStatus;
}
