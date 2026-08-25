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
import { Roles } from '../../common/decorators/roles.decorator';
import { OrgRole } from '../../common/enums/org-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { OrgScopeGuard } from '../../common/guards/org-scope.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AddToRosterDto } from './dto/add-to-roster.dto';
import { CreatePlayerDto } from './dto/create-player.dto';
import { PlayerRankingsQueryDto } from './dto/player-rankings-query.dto';
import { RatePlayerDto } from './dto/rate-player.dto';
import { UpdatePlayerDto } from './dto/update-player.dto';
import { VerifyPlayerDto } from './dto/verify-player.dto';
import { PlayersService } from './players.service';

@ApiTags('players')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/players')
export class PlayersController {
  constructor(private readonly playersService: PlayersService) {}

  @Post()
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({ summary: 'Create an org-level player profile' })
  create(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Body() dto: CreatePlayerDto,
  ) {
    return this.playersService.create(organizationId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List org-level players' })
  findAll(@Param('organizationId', ParseUUIDPipe) organizationId: string) {
    return this.playersService.findAll(organizationId);
  }

  @Get('rankings')
  @ApiOperation({
    summary:
      'Org-wide player leaderboard, sorted by the requested metric (runs/wickets/average desc, economy asc) ' +
      'with 1-based position numbers. Reuses the exact same aggregation as GET .../statistics, computed for ' +
      "every player in the org at once — see PlayersService.getRankings for the N-calls-vs-single-query " +
      'tradeoff note. Only players with matchesPlayed > 0 are included. Registered BEFORE :playerId so the ' +
      'literal path segment "rankings" is never swallowed by the :playerId param.',
  })
  getRankings(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Query() query: PlayerRankingsQueryDto,
  ) {
    return this.playersService.getRankings(organizationId, query.metric, query.limit);
  }

  @Get(':playerId')
  @ApiOperation({ summary: 'Get a player by id' })
  findOne(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('playerId', ParseUUIDPipe) playerId: string,
  ) {
    return this.playersService.findOne(organizationId, playerId);
  }

  @Delete(':playerId')
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({ summary: 'Delete a player' })
  remove(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('playerId', ParseUUIDPipe) playerId: string,
  ) {
    return this.playersService.remove(organizationId, playerId);
  }

  @Patch(':playerId')
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({ summary: 'Update a player profile (documents, styles, availability, etc.)' })
  update(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('playerId', ParseUUIDPipe) playerId: string,
    @Body() dto: UpdatePlayerDto,
  ) {
    return this.playersService.update(organizationId, playerId, dto);
  }

  @Patch(':playerId/verification')
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({ summary: 'Approve or reject a player profile' })
  setVerification(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('playerId', ParseUUIDPipe) playerId: string,
    @Body() dto: VerifyPlayerDto,
  ) {
    return this.playersService.setVerification(organizationId, playerId, dto);
  }

  @Patch(':playerId/rating')
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({ summary: 'Set a player rating (0-5)' })
  setRating(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('playerId', ParseUUIDPipe) playerId: string,
    @Body() dto: RatePlayerDto,
  ) {
    return this.playersService.setRating(organizationId, playerId, dto);
  }

  @Get(':playerId/statistics')
  @ApiOperation({
    summary:
      'Career/cross-match statistics for a player, aggregated on read across every completed match they' +
      "appear in (via any of their team_player rows) — summary, batting/bowling/fielding tabs, and a " +
      'chronological match history for a client-side trend graph',
  })
  getStatistics(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('playerId', ParseUUIDPipe) playerId: string,
  ) {
    return this.playersService.getStatistics(organizationId, playerId);
  }

  @Post(':playerId/tournament-teams/:tournamentTeamId/roster')
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({ summary: 'Add a player to a tournament-team roster (creates team_players row)' })
  addToRoster(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('playerId', ParseUUIDPipe) playerId: string,
    @Param('tournamentTeamId', ParseUUIDPipe) tournamentTeamId: string,
    @Body() dto: AddToRosterDto,
  ) {
    return this.playersService.addToRoster(organizationId, playerId, tournamentTeamId, dto);
  }
}
