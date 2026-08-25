import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsNumberString,
  IsOptional,
  IsString,
} from 'class-validator';
import { SponsorStatus } from '../../../database/entities/sponsor.entity';

export class CreateSponsorDto {
  @ApiProperty({ example: 'Acme Sports Pvt Ltd' })
  @IsString()
  @IsNotEmpty()
  companyName: string;

  @ApiPropertyOptional({ description: 'URL of the uploaded sponsor logo (see POST .../uploads)' })
  @IsOptional()
  @IsString()
  logoUrl?: string;

  @ApiPropertyOptional({ example: 'Title Sponsor', description: 'Free text, not a fixed enum' })
  @IsOptional()
  @IsString()
  packageName?: string;

  @ApiPropertyOptional({ example: '500000.00' })
  @IsOptional()
  @IsNumberString()
  amount?: string;

  @ApiPropertyOptional({ example: '2026-01-01' })
  @IsOptional()
  @IsDateString()
  contractStartDate?: string;

  @ApiPropertyOptional({ example: '2026-12-31' })
  @IsOptional()
  @IsDateString()
  contractEndDate?: string;

  @ApiPropertyOptional({ enum: SponsorStatus, default: SponsorStatus.ACTIVE })
  @IsOptional()
  @IsEnum(SponsorStatus)
  status?: SponsorStatus;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  visibleOnWebsite?: boolean;

  @ApiPropertyOptional({ default: false, description: 'Immediately actionable: a future Flutter screen can show sponsor logos where this is true' })
  @IsOptional()
  @IsBoolean()
  visibleOnApp?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  visibleOnMatchScreen?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  visibleOnScoreboard?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  visibleOnSocialMedia?: boolean;
}
