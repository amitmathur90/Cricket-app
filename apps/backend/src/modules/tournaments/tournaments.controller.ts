import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
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
import { CreateTournamentDto } from './dto/create-tournament.dto';
import { UpdateTournamentDto } from './dto/update-tournament.dto';
import { TournamentsService } from './tournaments.service';

@ApiTags('tournaments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/tournaments')
export class TournamentsController {
  constructor(private readonly tournamentsService: TournamentsService) {}

  @Post()
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({ summary: 'Create a tournament within an organization' })
  create(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Body() dto: CreateTournamentDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.tournamentsService.create(organizationId, dto, user.userId);
  }

  @Get()
  @ApiOperation({ summary: 'List tournaments in an organization' })
  findAll(@Param('organizationId', ParseUUIDPipe) organizationId: string) {
    return this.tournamentsService.findAll(organizationId);
  }

  @Get(':tournamentId')
  @ApiOperation({ summary: 'Get a tournament by id' })
  findOne(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
  ) {
    return this.tournamentsService.findOne(organizationId, tournamentId);
  }

  @Get(':tournamentId/teams')
  @ApiOperation({
    summary:
      "List a tournament's registered teams (id = tournamentTeamId, for assigning a match's home/away team) " +
      "— works whether or not an auction session exists for the tournament.",
  })
  getTeams(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
  ) {
    return this.tournamentsService.getTeams(organizationId, tournamentId);
  }

  @Get(':tournamentId/points-table')
  @ApiOperation({
    summary:
      'Computed points table (standings) for a tournament — derived on read from completed matches/innings, ' +
      'never persisted. Any authenticated org member may view it (no role restriction).',
  })
  getPointsTable(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
  ) {
    return this.tournamentsService.getPointsTable(organizationId, tournamentId);
  }

  @Get(':tournamentId/awards')
  @ApiOperation({
    summary:
      'Computed tournament awards (Player of the Tournament, Man of the Match per completed match, Best ' +
      'Batsman/Bowler/Fielder/All-Rounder, Emerging Player, Best Captain) — derived on read from every ' +
      "completed match's ball log, never persisted. See TournamentsService.getAwards for the exact formula, " +
      'thresholds, and honest data-availability caveats (esp. Emerging Player) behind each award. Any ' +
      'authenticated org member may view it (no role restriction, same as points-table).',
  })
  getAwards(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
  ) {
    return this.tournamentsService.getAwards(organizationId, tournamentId);
  }

  @Patch(':tournamentId')
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({ summary: 'Update a tournament' })
  update(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @Body() dto: UpdateTournamentDto,
  ) {
    return this.tournamentsService.update(organizationId, tournamentId, dto);
  }

  @Delete(':tournamentId')
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({ summary: 'Delete a tournament' })
  remove(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
  ) {
    return this.tournamentsService.remove(organizationId, tournamentId);
  }
}
