import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUUID } from 'class-validator';

export class DashboardQueryDto {
  @ApiPropertyOptional({
    description: 'Scope the dashboard to one tournament; omit to aggregate across the whole org',
  })
  @IsOptional()
  @IsUUID()
  tournamentId?: string;
}
