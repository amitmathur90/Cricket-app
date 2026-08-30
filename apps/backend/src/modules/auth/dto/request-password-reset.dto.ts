import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class RequestPasswordResetDto {
  @ApiProperty({
    example: 'amit@example.com',
    description: 'The account’s registered email or phone number',
  })
  @IsString()
  @IsNotEmpty()
  identifier: string;
}
