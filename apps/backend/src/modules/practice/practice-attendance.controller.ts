import { Body, Controller, Get, Param, ParseUUIDPipe, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../../common/decorators/roles.decorator';
import { OrgRole } from '../../common/enums/org-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { OrgScopeGuard } from '../../common/guards/org-scope.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { MarkAttendanceDto } from './dto/mark-attendance.dto';
import { PracticeAttendanceService } from './practice-attendance.service';

/**
 * Split out from PracticeSessionsController — a distinct sub-resource with
 * its own auth story (team_owner allowed, same pragmatic coach/captain-
 * adjacent approximation as the matches module's Playing XI endpoint),
 * kept under the same path prefix for consistency.
 */
@ApiTags('practice')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/teams/:teamId/practice-sessions/:sessionId/attendance')
export class PracticeAttendanceController {
  constructor(private readonly attendanceService: PracticeAttendanceService) {}

  @Get()
  @ApiOperation({
    summary:
      'List attendance for a session, with player details joined. Only rows that have actually been ' +
      "marked are returned — a player with no row is \"not yet marked\", not synthesized as absent.",
  })
  getAttendance(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
  ) {
    return this.attendanceService.getAttendance(organizationId, teamId, sessionId);
  }

  @Put()
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN, OrgRole.TEAM_OWNER)
  @ApiOperation({
    summary:
      'Bulk mark attendance for a session (create-or-update per playerId). playerId may be any ' +
      "org-level player — there is no tournament-roster membership check.",
  })
  markAttendance(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
    @Body() dto: MarkAttendanceDto,
  ) {
    return this.attendanceService.markAttendance(organizationId, teamId, sessionId, dto);
  }
}
