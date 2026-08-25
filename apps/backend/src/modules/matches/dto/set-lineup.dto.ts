import { ApiProperty } from '@nestjs/swagger';
import { IsArray, IsUUID } from 'class-validator';

/**
 * Full-replace lineup submission for one team, for one match: the client
 * sends the complete desired Playing XI + substitute lists every time,
 * rather than incremental add/remove calls. Simpler to reason about and
 * matches how a Flutter "Select Playing XI" screen naturally works (the
 * whole screen's state is submitted on save).
 *
 * Deliberately NOT validated to be exactly 11 `playingTeamPlayerIds` here —
 * see MatchLineupService.setLineup for the reasoning: the backend accepts
 * any valid subset of the team's roster (including a partial, in-progress
 * selection), and the "must pick exactly 11" rule is left to the Flutter UI
 * to enforce before it calls this endpoint with a "final" lineup.
 */
export class SetLineupDto {
  @ApiProperty({ type: [String], description: 'team_players ids selected for the Playing XI' })
  @IsArray()
  @IsUUID('4', { each: true })
  playingTeamPlayerIds: string[];

  @ApiProperty({ type: [String], description: 'team_players ids selected as substitutes' })
  @IsArray()
  @IsUUID('4', { each: true })
  substituteTeamPlayerIds: string[];
}
