import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { OrgRole } from '../../common/enums/org-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { OrgScopeGuard } from '../../common/guards/org-scope.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AuthenticatedUser } from '../../common/types/authenticated-user';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { NotificationsService } from './notifications.service';

/**
 * Every route here is scoped to the CALLING user's own notifications — a
 * user only ever sees their own (see NotificationsService.findAllForUser /
 * markAsRead). There is no "list another user's notifications" endpoint.
 */
@ApiTags('notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  @ApiOperation({ summary: "List the caller's own notifications, newest first" })
  @ApiQuery({ name: 'unreadOnly', required: false, type: Boolean })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Default 50' })
  @ApiQuery({ name: 'offset', required: false, type: Number, description: 'Default 0' })
  findAll(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @CurrentUser() user: AuthenticatedUser,
    @Query('unreadOnly') unreadOnly?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.notificationsService.findAllForUser(organizationId, user.userId, {
      unreadOnly: unreadOnly === 'true',
      limit: limit !== undefined ? parseInt(limit, 10) : undefined,
      offset: offset !== undefined ? parseInt(offset, 10) : undefined,
    });
  }

  @Get('unread-count')
  @ApiOperation({ summary: "Count of the caller's unread notifications, for a badge" })
  unreadCount(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.notificationsService.unreadCount(organizationId, user.userId);
  }

  @Patch(':notificationId/read')
  @ApiOperation({ summary: "Mark one of the caller's own notifications as read" })
  markAsRead(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('notificationId', ParseUUIDPipe) notificationId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.notificationsService.markAsRead(organizationId, user.userId, notificationId);
  }

  @Patch('read-all')
  @ApiOperation({ summary: "Mark all of the caller's unread notifications as read" })
  markAllAsRead(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.notificationsService.markAllAsRead(organizationId, user.userId);
  }

  @Post()
  @Roles(OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN, OrgRole.TEAM_OWNER)
  @ApiOperation({
    summary:
      'Create a notification for one or more recipients — used for admin-triggered notices and the future ' +
      'Captain-App "team announcement" feature (a team_owner broadcasting to their squad)',
  })
  create(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Body() dto: CreateNotificationDto,
  ) {
    return this.notificationsService.createForRecipients(organizationId, dto);
  }
}
