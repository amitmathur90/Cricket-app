import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class RequestMobileLoginOtpDto {
  @ApiProperty({ example: '9876543210', description: "The account's registered mobile number" })
  @IsString()
  @IsNotEmpty()
  phone: string;
}
