import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsEnum, IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';
import {
  FinanceTransactionCategory,
  FinanceTransactionType,
} from '../../../database/entities/finance-transaction.entity';

export class CreateFinanceTransactionDto {
  @ApiPropertyOptional({
    description: 'Scope this entry to one tournament; omit for an org-wide entry',
  })
  @IsOptional()
  @IsUUID()
  tournamentId?: string;

  @ApiProperty({ enum: FinanceTransactionCategory, example: FinanceTransactionCategory.GROUND_EXPENSE })
  @IsEnum(FinanceTransactionCategory)
  category: FinanceTransactionCategory;

  @ApiProperty({
    enum: FinanceTransactionType,
    example: FinanceTransactionType.EXPENSE,
    description: 'Must match the category — see FINANCE_CATEGORY_TYPE (e.g. sponsorship is always income)',
  })
  @IsEnum(FinanceTransactionType)
  type: FinanceTransactionType;

  @ApiProperty({ example: 15000 })
  @IsNumber()
  @Min(0)
  amount: number;

  @ApiPropertyOptional({ example: 'Ground rental for finals day' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ example: '2026-09-10', description: 'Date the transaction is attributed to' })
  @IsDateString()
  referenceDate: string;
}
