import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateVenueUnavailabilityDto {
  @ApiProperty({ example: '2026-09-10', description: 'ISO date (YYYY-MM-DD) the venue is unavailable' })
  @IsDateString()
  @IsNotEmpty()
  date: string;

  @ApiPropertyOptional({ example: 'Maintenance' })
  @IsOptional()
  @IsString()
  reason?: string;
}
