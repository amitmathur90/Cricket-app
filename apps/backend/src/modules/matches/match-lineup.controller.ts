import { Body, Controller, Get, Param, ParseUUIDPipe, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../../common/decorators/roles.decorator';
import { OrgRole } from '../../common/enums/org-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { OrgScopeGuard } from '../../common/guards/org-scope.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { SetLineupDto } from './dto/set-lineup.dto';
import { MatchLineupService } from './match-lineup.service';

/**
 * Split out from MatchesController — a distinct sub-resource (per-match,
 * per-team Playing XI / substitutes) with its own auth story (team_owner
 * allowed, unlike the rest of the matches admin surface), kept under the
 * same path prefix for consistency.
 */
@ApiTags('matches')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/tournaments/:tournamentId/matches/:matchId/lineup')
export class MatchLineupController {
  constructor(private readonly lineupService: MatchLineupService) {}

  @Put(':tournamentTeamId')
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN, OrgRole.TEAM_OWNER)
  @ApiOperation({
    summary:
      'Set (full replace) one team\'s Playing XI + substitutes for a match. The spec frames this as ' +
      '"captain selects Playing XI" — there is no per-user captain linkage in this app beyond org role, so ' +
      'team_owner is allowed as the closest existing proxy, alongside org/tournament admins. Server does not ' +
      'enforce an exact Playing XI size of 11; the Flutter UI enforces that before submitting a final lineup.',
  })
  setLineup(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @Param('matchId', ParseUUIDPipe) matchId: string,
    @Param('tournamentTeamId', ParseUUIDPipe) tournamentTeamId: string,
    @Body() dto: SetLineupDto,
  ) {
    return this.lineupService.setLineup(organizationId, tournamentId, matchId, tournamentTeamId, dto);
  }

  @Get()
  @ApiOperation({ summary: "Get both teams' Playing XI + substitutes for a match, with player details joined" })
  getLineup(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @Param('matchId', ParseUUIDPipe) matchId: string,
  ) {
    return this.lineupService.getLineup(organizationId, tournamentId, matchId);
  }
}
