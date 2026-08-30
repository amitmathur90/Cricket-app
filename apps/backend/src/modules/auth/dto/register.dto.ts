import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';

export class RegisterDto {
  @ApiProperty({ example: 'amit@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'S3curePassw0rd!', minLength: 8 })
  @IsString()
  @MinLength(8)
  password: string;

  @ApiProperty({ example: 'Amit Mathur' })
  @IsString()
  @IsNotEmpty()
  fullName: string;

  @ApiPropertyOptional({
    example: '+919876543210',
    description: 'Optional — lets "Forgot password" be looked up by phone as well as email',
  })
  @IsOptional()
  @IsString()
  phone?: string;
}
