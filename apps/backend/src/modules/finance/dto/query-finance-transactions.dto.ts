import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsEnum, IsOptional, IsUUID } from 'class-validator';
import {
  FinanceTransactionCategory,
  FinanceTransactionType,
} from '../../../database/entities/finance-transaction.entity';

export class QueryFinanceTransactionsDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  tournamentId?: string;

  @ApiPropertyOptional({ enum: FinanceTransactionCategory })
  @IsOptional()
  @IsEnum(FinanceTransactionCategory)
  category?: FinanceTransactionCategory;

  @ApiPropertyOptional({ enum: FinanceTransactionType })
  @IsOptional()
  @IsEnum(FinanceTransactionType)
  type?: FinanceTransactionType;

  @ApiPropertyOptional({ example: '2026-01-01', description: 'Inclusive lower bound on referenceDate' })
  @IsOptional()
  @IsDateString()
  from?: string;

  @ApiPropertyOptional({ example: '2026-12-31', description: 'Inclusive upper bound on referenceDate' })
  @IsOptional()
  @IsDateString()
  to?: string;
}
