import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsInt, IsNumber, IsUUID, Min, ValidateNested } from 'class-validator';

export class AddPoolEntryDto {
  @ApiProperty({ description: 'Player id (must belong to the same organization)' })
  @IsUUID()
  playerId: string;

  @ApiProperty({ description: 'Starting/base price for this player lot' })
  @IsNumber()
  @Min(0)
  basePrice: number;

  @ApiProperty({ description: 'Position in the running order (lower goes first)' })
  @IsInt()
  @Min(1)
  lotOrder: number;
}

export class AddToPoolDto {
  @ApiProperty({ type: [AddPoolEntryDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => AddPoolEntryDto)
  entries: AddPoolEntryDto[];
}
