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
import { CreatePracticeSessionDto } from './dto/create-practice-session.dto';
import { UpdatePracticeSessionDto } from './dto/update-practice-session.dto';
import { PracticeSessionsService } from './practice-sessions.service';

const ADMIN_ROLES = [OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN];

@ApiTags('practice')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/teams/:teamId/practice-sessions')
export class PracticeSessionsController {
  constructor(private readonly sessionsService: PracticeSessionsService) {}

  @Post()
  @Roles(...ADMIN_ROLES)
  @ApiOperation({
    summary:
      'Create a practice session for a team (team comes from the route). Only practiceType and ' +
      'scheduledAt are required; coach/venue/duration/notes are fillable later via PATCH.',
  })
  create(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() dto: CreatePracticeSessionDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.sessionsService.create(organizationId, teamId, dto, user.userId);
  }

  @Get()
  @ApiOperation({
    summary: 'List practice sessions for a team, optionally filtered by status and/or a scheduledAt date range',
  })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'from', required: false, description: 'ISO date/time, inclusive lower bound on scheduledAt' })
  @ApiQuery({ name: 'to', required: false, description: 'ISO date/time, inclusive upper bound on scheduledAt' })
  findAll(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('status') status?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.sessionsService.findAll(organizationId, teamId, { status, from, to });
  }

  @Get(':sessionId')
  @ApiOperation({ summary: 'Get a practice session by id, with coach details joined' })
  findOne(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
  ) {
    return this.sessionsService.findOne(organizationId, teamId, sessionId);
  }

  @Patch(':sessionId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({
    summary:
      'Update a practice session — any field, including status. `{ status: \'cancelled\' }` is a valid ' +
      'alternative to DELETE for callers who prefer to keep the row.',
  })
  update(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
    @Body() dto: UpdatePracticeSessionDto,
  ) {
    return this.sessionsService.update(organizationId, teamId, sessionId, dto);
  }

  @Delete(':sessionId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({
    summary: 'Hard-delete a practice session (and its attendance rows, via cascade)',
  })
  remove(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
  ) {
    return this.sessionsService.remove(organizationId, teamId, sessionId);
  }
}
