import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsEnum, IsInt, IsNumber, IsOptional, Min } from 'class-validator';
import { AcquisitionType } from '../../../database/entities/team-player.entity';

export class AddToRosterDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  jerseyNumber?: number;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isCaptain?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isWicketkeeper?: boolean;

  @ApiPropertyOptional({ enum: AcquisitionType, default: AcquisitionType.DIRECT_SIGNING })
  @IsOptional()
  @IsEnum(AcquisitionType)
  acquisitionType?: AcquisitionType;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  acquiredPrice?: number;
}
