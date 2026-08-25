import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { OrgRole } from '../../common/enums/org-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { OrgScopeGuard } from '../../common/guards/org-scope.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AuthenticatedUser } from '../../common/types/authenticated-user';
import { CreateFinanceTransactionDto } from './dto/create-finance-transaction.dto';
import { DashboardQueryDto } from './dto/dashboard-query.dto';
import { QueryFinanceTransactionsDto } from './dto/query-finance-transactions.dto';
import { TournamentScopeQueryDto } from './dto/tournament-scope-query.dto';
import { UpdateFinanceTransactionDto } from './dto/update-finance-transaction.dto';
import { FinanceService } from './finance.service';

const ADMIN_ROLES = [OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN];

@ApiTags('finance')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/finance')
export class FinanceController {
  constructor(private readonly financeService: FinanceService) {}

  @Post('transactions')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Record a manual finance transaction (sponsorship/expense/other income)' })
  create(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Body() dto: CreateFinanceTransactionDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.financeService.create(organizationId, dto, user.userId);
  }

  @Get('transactions')
  @ApiOperation({ summary: 'List finance transactions, optionally filtered' })
  findAll(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Query() query: QueryFinanceTransactionsDto,
  ) {
    return this.financeService.findAll(organizationId, query);
  }

  @Get('transactions/:transactionId')
  @ApiOperation({ summary: 'Get a finance transaction by id (also serves as its printable record)' })
  findOne(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('transactionId', ParseUUIDPipe) transactionId: string,
  ) {
    return this.financeService.findOne(organizationId, transactionId);
  }

  @Patch('transactions/:transactionId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Update a finance transaction' })
  update(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('transactionId', ParseUUIDPipe) transactionId: string,
    @Body() dto: UpdateFinanceTransactionDto,
  ) {
    return this.financeService.update(organizationId, transactionId, dto);
  }

  @Delete('transactions/:transactionId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Delete a finance transaction' })
  remove(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('transactionId', ParseUUIDPipe) transactionId: string,
  ) {
    return this.financeService.remove(organizationId, transactionId);
  }

  @Get('dashboard')
  @ApiOperation({
    summary:
      'Revenue/expense dashboard — registration and auction revenue derived on read, sponsorship/other/expenses ' +
      'from recorded transactions (+ Sponsor.amount where that module is present). Omit tournamentId to aggregate org-wide.',
  })
  getDashboard(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Query() query: DashboardQueryDto,
  ) {
    return this.financeService.getDashboard(organizationId, query.tournamentId);
  }

  @Get('team-fees')
  @ApiOperation({
    summary:
      "Per-registered-team registration fee owed for a tournament. 'paid'/'paidAt' are honest placeholders " +
      '(always false/null) — no payment-tracking data exists anywhere in this codebase yet.',
  })
  getTeamFees(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Query() query: TournamentScopeQueryDto,
  ) {
    return this.financeService.getTeamFees(organizationId, query.tournamentId);
  }

  @Get('player-fees')
  @ApiOperation({
    summary:
      "Per-registered-player registration fee owed for a tournament. 'paid'/'paidAt' are honest placeholders " +
      '(always false/null) — no payment-tracking data exists anywhere in this codebase yet.',
  })
  getPlayerFees(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Query() query: TournamentScopeQueryDto,
  ) {
    return this.financeService.getPlayerFees(organizationId, query.tournamentId);
  }
}
