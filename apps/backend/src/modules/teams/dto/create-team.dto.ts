import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class CreateTeamDto {
  @ApiProperty({ example: 'Thunder Strikers' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  name: string;

  @ApiPropertyOptional({ example: 'TSK' })
  @IsOptional()
  @IsString()
  @MaxLength(16)
  shortCode?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(512)
  logoUrl?: string;

  @ApiPropertyOptional({ description: 'User id of the team owner, if any' })
  @IsOptional()
  @IsUUID()
  ownerUserId?: string;
}
