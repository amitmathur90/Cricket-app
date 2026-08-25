import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsInt, IsNotEmpty, IsOptional, IsString, Min } from 'class-validator';
import { VenueStatus } from '../../../database/entities/venue.entity';

export class CreateVenueDto {
  @ApiProperty({ example: 'Central Cricket Ground' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiPropertyOptional({ example: 'Sector 21, Chandigarh' })
  @IsOptional()
  @IsString()
  location?: string;

  @ApiPropertyOptional({ example: 5000 })
  @IsOptional()
  @IsInt()
  @Min(0)
  capacity?: number;

  @ApiPropertyOptional({ example: 'Turf', description: 'Free text, not a fixed enum' })
  @IsOptional()
  @IsString()
  pitchType?: string;

  @ApiPropertyOptional({ example: 'Parking, Floodlights, Pavilion' })
  @IsOptional()
  @IsString()
  facilities?: string;

  @ApiPropertyOptional({ description: 'URL of the uploaded venue photo (see POST .../uploads)' })
  @IsOptional()
  @IsString()
  photoUrl?: string;

  @ApiPropertyOptional({ enum: VenueStatus, default: VenueStatus.ACTIVE })
  @IsOptional()
  @IsEnum(VenueStatus)
  status?: VenueStatus;
}
