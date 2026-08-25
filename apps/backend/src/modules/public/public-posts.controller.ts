import { Controller, Get, Param, ParseUUIDPipe, Query } from '@nestjs/common';
import { ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { PostType } from '../../database/entities/post.entity';
import { PostsService } from '../posts/posts.service';

@ApiTags('public')
@Controller('public/organizations/:organizationId/posts')
export class PublicPostsController {
  constructor(private readonly postsService: PostsService) {}

  @Get()
  @ApiOperation({
    summary:
      '[Public] Published posts only — PostsService.findPublished excludes drafts and future-scheduled ' +
      'posts at the query level (never filtered client-side).',
  })
  @ApiQuery({ name: 'type', required: false, enum: PostType })
  @ApiQuery({ name: 'tournamentId', required: false, description: 'Filter to one tournament\'s posts' })
  async findAll(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Query('type') type?: string,
    @Query('tournamentId') tournamentId?: string,
  ) {
    const posts = await this.postsService.findPublished(organizationId, { type, tournamentId });
    // Explicit projection — omits createdByUserId (internal admin
    // reference) and organizationId (redundant with the URL).
    return posts.map((p) => ({
      id: p.id,
      tournamentId: p.tournamentId,
      title: p.title,
      body: p.body,
      imageUrl: p.imageUrl,
      videoUrl: p.videoUrl,
      type: p.type,
      publishedAt: p.publishedAt,
      createdAt: p.createdAt,
    }));
  }
}
