import { ApiProperty } from '@nestjs/swagger';
import { IsString } from 'class-validator';

export class RefreshTokenDto {
  @ApiProperty({ description: 'Opaque refresh token issued at login/refresh/select-org time' })
  @IsString()
  refreshToken: string;
}
