import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsUUID, Min } from 'class-validator';

export class RegisterTeamToTournamentDto {
  @ApiPropertyOptional({ description: 'Optional tournament group to place this team in' })
  @IsOptional()
  @IsUUID()
  groupId?: string;

  @ApiPropertyOptional({ description: 'Starting auction purse for this team in this tournament' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  purseTotal?: number;
}
