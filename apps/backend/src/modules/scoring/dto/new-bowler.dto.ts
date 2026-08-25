import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

/**
 * Selects the bowler for the next over. Must be called before the first
 * ball of a new over can be recorded (recordBall never accepts a bowler
 * itself — it always uses whichever over is currently in-progress). Also
 * enforces the standard "no consecutive overs by the same bowler" rule
 * against the immediately-preceding completed over.
 */
export class NewBowlerDto {
  @ApiProperty({ description: 'team_players id of the bowler for the next (or currently pending) over' })
  @IsUUID()
  bowlerTeamPlayerId: string;
}
