import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { OfficialRole, OfficialStatus } from '../../../database/entities/official.entity';

export class CreateOfficialDto {
  @ApiProperty({ example: 'Simon Taufel' })
  @IsString()
  @IsNotEmpty()
  fullName: string;

  @ApiProperty({ enum: OfficialRole, example: OfficialRole.UMPIRE })
  @IsEnum(OfficialRole)
  role: OfficialRole;

  @ApiPropertyOptional({ example: '+91 98765 43210' })
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiPropertyOptional({ example: 'official@example.com' })
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional({ description: 'URL of the uploaded official photo (see POST .../uploads)' })
  @IsOptional()
  @IsString()
  photoUrl?: string;

  @ApiPropertyOptional({ enum: OfficialStatus, default: OfficialStatus.ACTIVE })
  @IsOptional()
  @IsEnum(OfficialStatus)
  status?: OfficialStatus;
}
