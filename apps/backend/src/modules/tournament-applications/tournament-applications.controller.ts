import {
  Body,
  Controller,
  Get,
  Param,
  ParseEnumPipe,
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
import { TournamentApplicationStatus } from '../../database/entities/tournament-application.entity';
import { CreateTournamentApplicationDto } from './dto/create-tournament-application.dto';
import { ReviewTournamentApplicationDto } from './dto/review-tournament-application.dto';
import { TournamentApplicationsService } from './tournament-applications.service';

// Route note: GET .../applications/mine is deliberately nested directly
// under :organizationId (not under a single :tournamentId) — see
// TournamentApplicationsService.findMine for why.
@ApiTags('tournament-applications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId')
export class TournamentApplicationsController {
  constructor(private readonly applicationsService: TournamentApplicationsService) {}

  @Post('tournaments/:tournamentId/applications')
  @ApiOperation({
    summary: 'Apply to a tournament as a player (self-service, any authenticated org member)',
  })
  apply(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateTournamentApplicationDto,
  ) {
    return this.applicationsService.apply(organizationId, tournamentId, user.userId, dto);
  }

  @Get('tournaments/:tournamentId/applications')
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({ summary: 'List applications for a tournament (org_admin/tournament_admin only)' })
  findAllForTournament(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @Query('status', new ParseEnumPipe(TournamentApplicationStatus, { optional: true }))
    status?: TournamentApplicationStatus,
  ) {
    return this.applicationsService.findAllForTournament(organizationId, tournamentId, status);
  }

  @Get('applications/mine')
  @ApiOperation({ summary: "List the caller's own tournament applications across this org" })
  findMine(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.applicationsService.findMine(organizationId, user.userId);
  }

  @Patch('tournaments/:tournamentId/applications/:applicationId/review')
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN)
  @ApiOperation({ summary: 'Approve or reject a tournament application' })
  review(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @Param('applicationId', ParseUUIDPipe) applicationId: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: ReviewTournamentApplicationDto,
  ) {
    return this.applicationsService.review(
      organizationId,
      tournamentId,
      applicationId,
      user.userId,
      dto,
    );
  }
}
