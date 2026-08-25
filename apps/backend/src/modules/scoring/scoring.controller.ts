import { Body, Controller, Get, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { OrgRole } from '../../common/enums/org-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { OrgScopeGuard } from '../../common/guards/org-scope.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AuthenticatedUser } from '../../common/types/authenticated-user';
import { NewBowlerDto } from './dto/new-bowler.dto';
import { RecordBallDto } from './dto/record-ball.dto';
import { StartInningsDto } from './dto/start-innings.dto';
import { StartMatchDto } from './dto/start-match.dto';
import { ScoringRealtimeService } from './scoring-realtime.service';

const SCORER_ROLES = [OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN, OrgRole.TEAM_OWNER, OrgRole.SCORER];

/**
 * REST surface for the scoring engine, alongside ScoringGateway — mirrors
 * AuctionController's pattern of exposing every realtime-service mutation
 * over REST too (not just WS), so admin tooling/Postman/tests can drive
 * scoring without a socket connection. Every handler here delegates to the
 * exact same ScoringRealtimeService methods the gateway calls, so REST- and
 * WS-triggered mutations are always identical in behavior and both
 * broadcast to the match's room.
 *
 * Per the spec, REST is the fallback source of truth (GET /live-state /
 * GET /scorecard) and WS is the low-latency delta stream — but the mutating
 * actions are deliberately available on both transports for parity with
 * the auction module's precedent.
 */
@ApiTags('scoring')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/tournaments/:tournamentId/matches/:matchId/scoring')
export class ScoringController {
  constructor(private readonly realtimeService: ScoringRealtimeService) {}

  @Post('start')
  @Roles(...SCORER_ROLES)
  @ApiOperation({
    summary:
      'Starts scoring for the match: sets Match.status=live, records who bats first (toss-calling is out of ' +
      "scope), and creates the first innings with its opening pair + first over's bowler",
  })
  start(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('matchId', ParseUUIDPipe) matchId: string,
    @Body() dto: StartMatchDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.realtimeService.startMatch(user, organizationId, matchId, dto);
  }

  @Post('start-innings')
  @Roles(...SCORER_ROLES)
  @ApiOperation({ summary: 'Starts the second innings (batting/bowling teams auto-swapped from the first)' })
  startInnings(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('matchId', ParseUUIDPipe) matchId: string,
    @Body() dto: StartInningsDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.realtimeService.startInnings(user, organizationId, matchId, dto);
  }

  @Post('new-bowler')
  @Roles(...SCORER_ROLES)
  @ApiOperation({ summary: "Selects the bowler for the next over (required before that over's first ball)" })
  newBowler(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('matchId', ParseUUIDPipe) matchId: string,
    @Body() dto: NewBowlerDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.realtimeService.newBowler(user, organizationId, matchId, dto);
  }

  @Post('record-ball')
  @Roles(...SCORER_ROLES)
  @ApiOperation({ summary: 'Records one delivery — the primary scoring action' })
  recordBall(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('matchId', ParseUUIDPipe) matchId: string,
    @Body() dto: RecordBallDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.realtimeService.recordBall(user, organizationId, matchId, dto);
  }

  @Post('undo-last-ball')
  @Roles(...SCORER_ROLES)
  @ApiOperation({
    summary:
      'Correction: voids the most recently recorded ball and recomputes innings/over/partnership state from ' +
      'the remaining ball log (does not just delete the row) — scoped to the current over, see service doc',
  })
  undoLastBall(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('matchId', ParseUUIDPipe) matchId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.realtimeService.undoLastBall(user, organizationId, matchId);
  }

  @Post('end-innings')
  @Roles(...SCORER_ROLES)
  @ApiOperation({ summary: 'Manual early end of the current innings (declaration-equivalent / early stoppage)' })
  endInnings(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('matchId', ParseUUIDPipe) matchId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.realtimeService.endInnings(user, organizationId, matchId);
  }

  @Get('live-state')
  @ApiOperation({
    summary:
      'Full current-state snapshot (REST fallback for the WS scoring.stateSync event) — innings totals, ' +
      "current over, both batters' live figures, current partnership, last ~12 balls",
  })
  getLiveState(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('matchId', ParseUUIDPipe) matchId: string,
  ) {
    return this.realtimeService.getLiveState(organizationId, matchId);
  }

  @Get('scorecard')
  @ApiOperation({
    summary:
      'Full match scorecard — batting and bowling figures per player, per innings, computed live from the ' +
      'ball-by-ball log (not a materialized table — see ScoringRealtimeService doc)',
  })
  getScorecard(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('matchId', ParseUUIDPipe) matchId: string,
  ) {
    return this.realtimeService.getScorecard(organizationId, matchId);
  }
}
