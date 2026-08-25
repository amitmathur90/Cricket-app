import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';

export class BidIncrementRuleDto {
  @ApiPropertyOptional({
    nullable: true,
    description: 'Tier ceiling — this increment applies while the current bid is below this value. Use null for the catch-all top tier.',
  })
  @IsOptional()
  @IsNumber()
  @Min(0)
  upTo?: number | null;

  @ApiProperty({ description: 'Minimum bid step while in this tier' })
  @IsNumber()
  @Min(1)
  increment: number;
}

export class CreateAuctionSessionDto {
  @ApiProperty({ example: 'Main Auction — Day 1' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiPropertyOptional({
    type: [BidIncrementRuleDto],
    description: 'Optional tiered bid-increment schedule. Omit to use the default (5% of current bid, rounded).',
  })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BidIncrementRuleDto)
  bidIncrementRules?: BidIncrementRuleDto[];
}
