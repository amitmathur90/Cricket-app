import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsEnum, IsInt, IsOptional, Max, Min } from 'class-validator';

/** Which PlayerStatisticsSummary field to sort the org-wide leaderboard by — see PlayersService.getRankings. */
export enum RankingMetric {
  RUNS = 'runs',
  WICKETS = 'wickets',
  AVERAGE = 'average',
  ECONOMY = 'economy',
}

/** Sane upper bound so a careless/huge `limit` can't force an unbounded response. */
export const MAX_RANKINGS_LIMIT = 100;
export const DEFAULT_RANKINGS_LIMIT = 20;

export class PlayerRankingsQueryDto {
  @ApiPropertyOptional({
    enum: RankingMetric,
    default: RankingMetric.RUNS,
    description: 'Metric to sort by. runs/wickets/average sort descending (higher is better); economy sorts ascending (lower is better).',
  })
  @IsOptional()
  @IsEnum(RankingMetric)
  metric?: RankingMetric;

  @ApiPropertyOptional({ default: DEFAULT_RANKINGS_LIMIT, minimum: 1, maximum: MAX_RANKINGS_LIMIT })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(MAX_RANKINGS_LIMIT)
  limit?: number;
}
