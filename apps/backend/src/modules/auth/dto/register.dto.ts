import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString, MinLength } from 'class-validator';

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
}
