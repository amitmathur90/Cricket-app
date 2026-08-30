import { ApiProperty } from '@nestjs/swagger';
import { IsString, MinLength } from 'class-validator';

export class ResetPasswordDto {
  @ApiProperty({ description: 'The opaque token returned by POST /auth/forgot-password/verify-otp' })
  @IsString()
  resetToken: string;

  @ApiProperty({ example: 'N3wS3curePassw0rd!', minLength: 8 })
  @IsString()
  @MinLength(8)
  newPassword: string;
}
