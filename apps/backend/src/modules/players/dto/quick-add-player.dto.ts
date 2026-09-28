import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

/**
 * Minimal-friction "add a player by phone number" — backs the Quick Match
 * roster flow (find-or-create a Player by phone, then add straight to a
 * tournament-team's roster in one call), as opposed to the full
 * CreatePlayerDto form. fullName is only used if a new Player is created;
 * an existing match by phone keeps its existing name.
 */
export class QuickAddPlayerDto {
  @ApiProperty({ example: '9876543210' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiPropertyOptional({ example: 'New Player', description: 'Used only when creating a brand-new player' })
  @IsOptional()
  @IsString()
  fullName?: string;
}
