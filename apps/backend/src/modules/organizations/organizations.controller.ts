import { Body, Controller, Get, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AuthenticatedUser } from '../../common/types/authenticated-user';
import { CreateOrganizationDto } from './dto/create-organization.dto';
import { InviteMemberDto } from './dto/invite-member.dto';
import { JoinOrganizationDto } from './dto/join-organization.dto';
import { OrganizationsService } from './organizations.service';

// Note: membership/role authorization here is enforced inside
// OrganizationsService (caller may not have an active-org JWT claim yet —
// e.g. right after registering, before creating their first org — so
// OrgScopeGuard/RolesGuard, which key off the active-org claim, don't apply
// cleanly to this controller the way they do to tournaments/teams/players).
@ApiTags('organizations')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('organizations')
export class OrganizationsController {
  constructor(private readonly organizationsService: OrganizationsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new organization (caller becomes org_admin)' })
  create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateOrganizationDto) {
    return this.organizationsService.create(dto, user.userId);
  }

  @Post('join')
  @ApiOperation({
    summary:
      'Join an organization via its join code (auto-creates an ACTIVE player-role membership)',
  })
  join(@CurrentUser() user: AuthenticatedUser, @Body() dto: JoinOrganizationDto) {
    return this.organizationsService.join(dto, user.userId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get an organization by id (includes its join code)' })
  findOne(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.organizationsService.findById(id, user.userId, user.isSuperAdmin);
  }

  @Get(':id/members')
  @ApiOperation({ summary: 'List members of an organization' })
  listMembers(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.organizationsService.listMembers(id, user.userId, user.isSuperAdmin);
  }

  @Post(':id/members/invite')
  @ApiOperation({ summary: 'Invite an existing user to this organization (org_admin only)' })
  inviteMember(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: InviteMemberDto,
  ) {
    return this.organizationsService.inviteMember(id, dto, user.userId, user.isSuperAdmin);
  }

  @Post(':organizationId/join-code/regenerate')
  @ApiOperation({ summary: "Regenerate an organization's join code (org_admin only)" })
  regenerateJoinCode(
    @CurrentUser() user: AuthenticatedUser,
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
  ) {
    return this.organizationsService.regenerateJoinCode(
      organizationId,
      user.userId,
      user.isSuperAdmin,
    );
  }
}
