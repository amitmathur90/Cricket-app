import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class UpdateMeDto {
  @ApiPropertyOptional({ example: 'Amit Mathur' })
  @IsOptional()
  @IsString()
  fullName?: string;

  @ApiPropertyOptional({
    example: '+919876543210',
    description: 'Lets "Forgot password" be looked up by phone as well as email',
  })
  @IsOptional()
  @IsString()
  phone?: string;
}
