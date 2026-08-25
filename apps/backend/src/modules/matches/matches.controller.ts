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
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { OrgRole } from '../../common/enums/org-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { OrgScopeGuard } from '../../common/guards/org-scope.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AuthenticatedUser } from '../../common/types/authenticated-user';
import { CreateMatchDto } from './dto/create-match.dto';
import { UpdateMatchDto } from './dto/update-match.dto';
import { MatchesService } from './matches.service';

const ADMIN_ROLES = [OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN];

@ApiTags('matches')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/tournaments/:tournamentId/matches')
export class MatchesController {
  constructor(private readonly matchesService: MatchesService) {}

  @Post()
  @Roles(...ADMIN_ROLES)
  @ApiOperation({
    summary: 'Create a match ("Create match" — an empty TBD-vs-TBD fixture is a valid result)',
  })
  create(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @Body() dto: CreateMatchDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.matchesService.create(organizationId, tournamentId, dto, user.userId);
  }

  @Get()
  @ApiOperation({
    summary:
      'List matches for a tournament, optionally filtered by status and/or an inclusive scheduledAt date range',
  })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'from', required: false, description: 'ISO date/time, inclusive lower bound on scheduledAt' })
  @ApiQuery({ name: 'to', required: false, description: 'ISO date/time, inclusive upper bound on scheduledAt' })
  findAll(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @Query('status') status?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.matchesService.findAll(organizationId, tournamentId, { status, from, to });
  }

  @Get(':matchId')
  @ApiOperation({ summary: 'Get a match by id, with home/away/winner team names resolved' })
  findOne(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @Param('matchId', ParseUUIDPipe) matchId: string,
  ) {
    return this.matchesService.findOne(organizationId, tournamentId, matchId);
  }

  @Patch(':matchId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({
    summary:
      'Update a match — covers Assign teams, Assign venue, Assign umpire/scorer, Reschedule, and status ' +
      "changes in one endpoint. `{ status: 'cancelled' }` is the spec's soft \"Cancel match\" action " +
      '(see DELETE for a true hard delete).',
  })
  update(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @Param('matchId', ParseUUIDPipe) matchId: string,
    @Body() dto: UpdateMatchDto,
  ) {
    return this.matchesService.update(organizationId, tournamentId, matchId, dto);
  }

  @Delete(':matchId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({
    summary:
      'Hard-delete a match (administrative cleanup). NOT the "Cancel match" button — use ' +
      "PATCH { status: 'cancelled' } for that (soft-cancel, preserves calendar/history).",
  })
  remove(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @Param('matchId', ParseUUIDPipe) matchId: string,
  ) {
    return this.matchesService.remove(organizationId, tournamentId, matchId);
  }
}
