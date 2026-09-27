import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Length, Matches } from 'class-validator';

export class VerifyMobileLoginOtpDto {
  @ApiProperty({ example: '9876543210' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiProperty({ example: '1234', description: 'Renflair sends a 4-digit code, unlike the 6-digit email OTPs' })
  @IsString()
  @Length(4, 4)
  @Matches(/^\d{4}$/, { message: 'otp must be a 4-digit code' })
  otp: string;
}
