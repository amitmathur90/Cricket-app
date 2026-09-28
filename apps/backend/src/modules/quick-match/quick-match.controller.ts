import { Controller, Get, Param, ParseUUIDPipe, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { OrgScopeGuard } from '../../common/guards/org-scope.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AuthenticatedUser } from '../../common/types/authenticated-user';
import { QuickMatchService } from './quick-match.service';

@ApiTags('quick-match')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/quick-matches')
export class QuickMatchController {
  constructor(private readonly quickMatchService: QuickMatchService) {}

  @Get('tournament')
  @ApiOperation({
    summary:
      "Gets (creating on first use) this org's hidden Quick Match tournament id. Every other Quick Match " +
      'action (create/select team, register team, add roster, create match, set lineup, start scoring) ' +
      'reuses the normal tournament-scoped endpoints against this id — see QuickMatchService.',
  })
  getTournament(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.quickMatchService.getOrCreateTournament(organizationId, user.userId);
  }
}
