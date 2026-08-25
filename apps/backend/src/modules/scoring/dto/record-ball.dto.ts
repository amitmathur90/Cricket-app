import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  MaxLength,
} from 'class-validator';
import { DismissalType, ExtraType } from '../../../database/entities/ball.entity';

/**
 * Submits one delivery. Deliberately does NOT accept striker/non-striker/
 * bowler — those are always server-derived (from the innings' live cursor
 * and the current in-progress over) so a client can never desync them by
 * submitting a stale value; see ScoringRealtimeService.recordBall.
 *
 * `runs` is the count of runs physically run by the batters off this
 * delivery — its meaning depends on `extraType`:
 *   - undefined/null (a normal delivery): credited as batter runs.
 *   - 'no_ball': credited as batter runs, IN ADDITION to the automatic
 *     +1 no-ball penalty (which is always added as an extra regardless of
 *     `runs`).
 *   - 'bye' / 'leg_bye': credited as extras (never batter runs).
 *   - 'wide': credited as extras, IN ADDITION to the automatic +1 wide
 *     penalty. Byes-on-a-wide are a rare edge case the spec explicitly
 *     says not to over-engineer, so this is intentionally the full extent
 *     of wide handling.
 *   - 'penalty': credited as extras; a penalty ball still consumes a legal
 *     over-slot in this data model (the spec doesn't detail penalty-run
 *     over-advancement semantics, so it's treated the same as bye/leg_bye
 *     for that purpose — a documented M1 simplification).
 */
export class RecordBallDto {
  @ApiPropertyOptional({ default: 0, description: 'Runs physically run by the batters off this delivery' })
  @IsOptional()
  @IsInt()
  @Min(0)
  runs?: number;

  @ApiPropertyOptional({ enum: ExtraType, nullable: true })
  @IsOptional()
  @IsEnum(ExtraType)
  extraType?: ExtraType;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isWicket?: boolean;

  @ApiPropertyOptional({ enum: DismissalType, nullable: true })
  @IsOptional()
  @IsEnum(DismissalType)
  dismissalType?: DismissalType;

  @ApiPropertyOptional({
    description:
      'Required only for a run_out (the dismissed player is not always the striker). For every other ' +
      'dismissal type the striker is dismissed by definition and this is inferred automatically.',
  })
  @IsOptional()
  @IsUUID()
  dismissedTeamPlayerId?: string;

  @ApiPropertyOptional({ description: 'team_players id of the fielder credited, if applicable' })
  @IsOptional()
  @IsUUID()
  fielderTeamPlayerId?: string;

  @ApiPropertyOptional({
    description:
      "Required when isWicket is true AND this is not the innings' 10th wicket — the incoming batter " +
      "(must be an unused member of the batting team's Playing XI).",
  })
  @IsOptional()
  @IsUUID()
  nextBatterTeamPlayerId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  commentaryText?: string;
}
