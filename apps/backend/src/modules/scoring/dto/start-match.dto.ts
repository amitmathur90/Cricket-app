import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsOptional, IsUUID, Min } from 'class-validator';

/**
 * Starts the match (Match.status -> live) and, in the same call, the first
 * innings including its opening pair and first over's bowler — toss-calling
 * itself is out of scope (the spec explicitly says so), so the caller just
 * states who's batting first as a fait accompli.
 */
export class StartMatchDto {
  @ApiProperty({ description: 'tournament_teams id of the team batting first' })
  @IsUUID()
  battingFirstTournamentTeamId: string;

  @ApiPropertyOptional({
    description:
      "Overs limit for the match (e.g. 20 for T20). Defaults from the tournament's format when omitted.",
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  oversLimit?: number;

  @ApiProperty({ description: "team_players id — the batting-first team's opening striker" })
  @IsUUID()
  openingStrikerTeamPlayerId: string;

  @ApiProperty({ description: "team_players id — the batting-first team's opening non-striker" })
  @IsUUID()
  openingNonStrikerTeamPlayerId: string;

  @ApiProperty({ description: "team_players id — the bowling-first team's opening bowler" })
  @IsUUID()
  openingBowlerTeamPlayerId: string;
}
