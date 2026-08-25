import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post as HttpPost,
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
import { CreatePostDto } from './dto/create-post.dto';
import { UpdatePostDto } from './dto/update-post.dto';
import { PostsService } from './posts.service';

const ADMIN_ROLES = [OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN];

/**
 * Authenticated admin CRUD for news/media posts — mirrors CoachesController's
 * pattern exactly (create/update/delete restricted to org_admin/
 * tournament_admin, list/read open to any authenticated org member,
 * including drafts). The unauthenticated, published-only counterpart lives
 * in PublicModule (`public/organizations/:organizationId/posts`) — see that
 * module for the public-safe projection.
 */
@ApiTags('posts')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/posts')
export class PostsController {
  constructor(private readonly postsService: PostsService) {}

  @HttpPost()
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Create a news/photo/video post (org-wide, or tournament-specific via tournamentId)' })
  create(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Body() dto: CreatePostDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.postsService.create(organizationId, dto, user.userId);
  }

  @Get()
  @ApiOperation({ summary: 'List every post in the org, including drafts — any authenticated org member' })
  findAll(@Param('organizationId', ParseUUIDPipe) organizationId: string) {
    return this.postsService.findAll(organizationId);
  }

  @Get(':postId')
  @ApiOperation({ summary: 'Get a post by id' })
  findOne(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('postId', ParseUUIDPipe) postId: string,
  ) {
    return this.postsService.findOne(organizationId, postId);
  }

  @Patch(':postId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Update a post, including setting/clearing publishedAt (draft <-> published)' })
  update(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('postId', ParseUUIDPipe) postId: string,
    @Body() dto: UpdatePostDto,
  ) {
    return this.postsService.update(organizationId, postId, dto);
  }

  @Delete(':postId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Delete a post' })
  remove(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('postId', ParseUUIDPipe) postId: string,
  ) {
    return this.postsService.remove(organizationId, postId);
  }
}
