import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsString } from 'class-validator';
import { PlayerVerificationStatus } from '../../../database/entities/player.entity';

export class VerifyPlayerDto {
  @ApiProperty({
    enum: PlayerVerificationStatus,
    example: PlayerVerificationStatus.VERIFIED,
    description:
      'Must be VERIFIED, APPROVED, or REJECTED — PENDING is only the initial default, not a valid transition ' +
      'target. Legal transitions: PENDING->VERIFIED, VERIFIED->APPROVED, PENDING/VERIFIED->REJECTED. ' +
      'See PlayersService.setVerification for the enforced rules.',
  })
  @IsEnum(PlayerVerificationStatus)
  status: PlayerVerificationStatus;

  @ApiPropertyOptional({ description: 'Reason, especially useful when rejecting' })
  @IsOptional()
  @IsString()
  note?: string;
}
