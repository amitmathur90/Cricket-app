import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../../common/decorators/roles.decorator';
import { OrgRole } from '../../common/enums/org-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { OrgScopeGuard } from '../../common/guards/org-scope.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AuctionRealtimeService } from './auction-realtime.service';
import { AuctionService } from './auction.service';
import { AddToPoolDto } from './dto/add-to-pool.dto';
import { CreateAuctionSessionDto } from './dto/create-auction-session.dto';

const ADMIN_ROLES = [OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN];

@ApiTags('auction')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/tournaments/:tournamentId/auction-sessions')
export class AuctionController {
  constructor(
    private readonly auctionService: AuctionService,
    private readonly realtimeService: AuctionRealtimeService,
  ) {}

  @Post()
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Create an auction session for a tournament' })
  create(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @Body() dto: CreateAuctionSessionDto,
  ) {
    return this.auctionService.create(organizationId, tournamentId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List auction sessions for a tournament' })
  findAll(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
  ) {
    return this.auctionService.findAll(organizationId, tournamentId);
  }

  @Get(':sessionId')
  @ApiOperation({ summary: 'Get one auction session with its current state' })
  findOne(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
  ) {
    return this.auctionService.findOne(organizationId, sessionId);
  }

  @Post(':sessionId/pool')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: "Bulk-add players to a session's lot pool" })
  addToPool(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
    @Body() dto: AddToPoolDto,
  ) {
    return this.auctionService.addToPool(organizationId, sessionId, dto);
  }

  @Get(':sessionId/pool')
  @ApiOperation({ summary: 'List the pool for a session, ordered by lot order' })
  listPool(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
  ) {
    return this.auctionService.listPool(organizationId, sessionId);
  }

  @Post(':sessionId/start')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Start the session — opens the first pending lot' })
  start(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
  ) {
    return this.realtimeService.startSession(organizationId, sessionId);
  }

  @Post(':sessionId/pause')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Pause a live session (freezes the lot countdown)' })
  pause(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
  ) {
    return this.realtimeService.pauseSession(organizationId, sessionId);
  }

  @Post(':sessionId/resume')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Resume a paused session' })
  resume(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
  ) {
    return this.realtimeService.resumeSession(organizationId, sessionId);
  }

  @Post(':sessionId/mark-sold')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({
    summary:
      'Mark the current lot SOLD to the leading bidder — deducts their purse and adds the player to their ' +
      'roster. Requires a current bid; does not advance to the next lot (call next-lot separately).',
  })
  markSold(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
  ) {
    return this.realtimeService.markSold(organizationId, sessionId);
  }

  @Post(':sessionId/mark-unsold')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({
    summary:
      'Mark the current lot UNSOLD — allowed with or without a current bid (admin override). No purse moves. ' +
      'Does not advance to the next lot (call next-lot separately).',
  })
  markUnsold(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
  ) {
    return this.realtimeService.markUnsold(organizationId, sessionId);
  }

  @Post(':sessionId/next-lot')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({
    summary:
      'Advance to the next pending lot (or complete the session if none remain). Requires the current lot to ' +
      'already be marked SOLD/UNSOLD.',
  })
  nextLot(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
  ) {
    return this.realtimeService.advanceToNextLot(organizationId, sessionId);
  }

  @Post(':sessionId/undo-last-bid')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({
    summary:
      "Admin escape hatch: roll back the most recent bid on the session's current lot (voids the bid row and " +
      'recomputes the current-bid state; does not touch bid history for other lots)',
  })
  undoLastBid(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
  ) {
    return this.realtimeService.undoLastBid(organizationId, sessionId);
  }

  @Get(':sessionId/bids')
  @ApiOperation({ summary: 'Full bid history for the session, optionally filtered by playerId' })
  listBids(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
    @Query('playerId') playerId?: string,
  ) {
    return this.auctionService.listBids(organizationId, sessionId, playerId);
  }

  @Get(':sessionId/report')
  @ApiOperation({ summary: 'Auction report: per-team spend/purse summary and per-player outcomes' })
  getReport(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
  ) {
    return this.auctionService.getReport(organizationId, sessionId);
  }
}

/**
 * Separate controller (same auction module) for the player-purchase-history
 * spec item, since it's keyed by player rather than by session and sits
 * under a different route prefix (organizations/:organizationId/players).
 */
@ApiTags('auction')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/players')
export class PlayerPurchaseHistoryController {
  constructor(private readonly auctionService: AuctionService) {}

  @Get(':playerId/purchase-history')
  @ApiOperation({ summary: 'All auction bid/sale history for a player across every session they appeared in' })
  getPurchaseHistory(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('playerId', ParseUUIDPipe) playerId: string,
  ) {
    return this.auctionService.getPlayerPurchaseHistory(organizationId, playerId);
  }
}
