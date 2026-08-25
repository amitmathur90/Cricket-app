import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../../common/decorators/roles.decorator';
import { OrgRole } from '../../common/enums/org-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { OrgScopeGuard } from '../../common/guards/org-scope.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CreateTeamDto } from './dto/create-team.dto';
import { RegisterTeamToTournamentDto } from './dto/register-team-to-tournament.dto';
import { UpdateRosterEntryDto } from './dto/update-roster-entry.dto';
import { TeamsService } from './teams.service';

@ApiTags('teams')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/teams')
export class TeamsController {
  constructor(private readonly teamsService: TeamsService) {}

  @Post()
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({ summary: 'Create an org-level team' })
  create(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Body() dto: CreateTeamDto,
  ) {
    return this.teamsService.create(organizationId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List org-level teams' })
  findAll(@Param('organizationId', ParseUUIDPipe) organizationId: string) {
    return this.teamsService.findAll(organizationId);
  }

  @Get(':teamId')
  @ApiOperation({ summary: 'Get a team by id' })
  findOne(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('teamId', ParseUUIDPipe) teamId: string,
  ) {
    return this.teamsService.findOne(organizationId, teamId);
  }

  @Delete(':teamId')
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({ summary: 'Delete a team' })
  remove(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('teamId', ParseUUIDPipe) teamId: string,
  ) {
    return this.teamsService.remove(organizationId, teamId);
  }

  @Post(':teamId/tournaments/:tournamentId/register')
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({ summary: 'Register a team into a tournament (creates tournament_teams row)' })
  registerToTournament(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @Body() dto: RegisterTeamToTournamentDto,
  ) {
    return this.teamsService.registerToTournament(organizationId, teamId, tournamentId, dto);
  }

  @Get(':teamId/tournaments/:tournamentId/roster')
  @ApiOperation({ summary: "List a team's roster (squad) for a tournament, with player details and captain" })
  getRoster(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
  ) {
    return this.teamsService.getRoster(organizationId, teamId, tournamentId);
  }

  @Patch(':teamId/tournaments/:tournamentId/roster/:teamPlayerId')
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({
    summary:
      'Update a roster entry (captain/vice-captain flags, jersey number, wicketkeeper) — the general write ' +
      'path missing since addToRoster is create-only. Setting isCaptain/isViceCaptain true atomically unsets ' +
      "it on any other roster entry for the same tournament-team; a player can't hold both flags at once.",
  })
  updateRosterEntry(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @Param('teamPlayerId', ParseUUIDPipe) teamPlayerId: string,
    @Body() dto: UpdateRosterEntryDto,
  ) {
    return this.teamsService.updateRosterEntry(organizationId, teamId, tournamentId, teamPlayerId, dto);
  }
}
