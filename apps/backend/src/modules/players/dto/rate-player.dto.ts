import { ApiProperty } from '@nestjs/swagger';
import { IsNumber, Max, Min } from 'class-validator';

export class RatePlayerDto {
  @ApiProperty({ example: 4.5, minimum: 0, maximum: 5 })
  @IsNumber()
  @Min(0)
  @Max(5)
  rating: number;
}
