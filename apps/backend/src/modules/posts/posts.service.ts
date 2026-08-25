import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { FindOptionsWhere, LessThanOrEqual, Repository } from 'typeorm';
import { findManyOrgScoped, findOneOrgScoped } from '../../common/base/org-scoped.repository';
import { Post, PostType } from '../../database/entities/post.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { CreatePostDto } from './dto/create-post.dto';
import { UpdatePostDto } from './dto/update-post.dto';

export interface FindPublishedFilters {
  tournamentId?: string;
  type?: string;
}

@Injectable()
export class PostsService {
  constructor(
    @InjectRepository(Post) private readonly postRepo: Repository<Post>,
    @InjectRepository(Tournament) private readonly tournamentRepo: Repository<Tournament>,
  ) {}

  /** Verifies a (possibly null/undefined) tournamentId belongs to this org, or throws. */
  private async validateTournamentId(
    organizationId: string,
    tournamentId: string | null | undefined,
  ): Promise<void> {
    if (!tournamentId) {
      return;
    }
    const tournament = await findOneOrgScoped(this.tournamentRepo, organizationId, {
      id: tournamentId,
    });
    if (!tournament) {
      throw new BadRequestException('tournamentId must be a tournament belonging to this organization');
    }
  }

  async create(organizationId: string, dto: CreatePostDto, createdByUserId: string): Promise<Post> {
    await this.validateTournamentId(organizationId, dto.tournamentId);
    return this.postRepo.save(
      this.postRepo.create({
        title: dto.title,
        body: dto.body,
        type: dto.type ?? PostType.NEWS,
        tournamentId: dto.tournamentId ?? null,
        imageUrl: dto.imageUrl ?? null,
        videoUrl: dto.videoUrl ?? null,
        publishedAt: dto.publishedAt ? new Date(dto.publishedAt) : null,
        organizationId,
        createdByUserId,
      }),
    );
  }

  async findAll(organizationId: string): Promise<Post[]> {
    return findManyOrgScoped(this.postRepo, organizationId);
  }

  async findOne(organizationId: string, postId: string): Promise<Post> {
    const post = await findOneOrgScoped(this.postRepo, organizationId, { id: postId });
    if (!post) {
      throw new NotFoundException('Post not found');
    }
    return post;
  }

  async update(organizationId: string, postId: string, dto: UpdatePostDto): Promise<Post> {
    const post = await this.findOne(organizationId, postId);
    if (dto.tournamentId !== undefined) {
      await this.validateTournamentId(organizationId, dto.tournamentId);
    }
    Object.assign(post, {
      ...dto,
      publishedAt:
        dto.publishedAt !== undefined
          ? dto.publishedAt
            ? new Date(dto.publishedAt)
            : null
          : post.publishedAt,
    });
    return this.postRepo.save(post);
  }

  async remove(organizationId: string, postId: string): Promise<void> {
    const post = await this.findOne(organizationId, postId);
    await this.postRepo.remove(post);
  }

  /**
   * Public-safe read model: only posts that are actually published
   * (`publishedAt` set AND at-or-before now) — drafts and future-scheduled
   * posts never come back from this method. `LessThanOrEqual` against a
   * nullable column never matches NULL in SQL, so "publishedAt IS NOT NULL
   * AND publishedAt <= now()" falls out of this filter for free, with no
   * separate IS NOT NULL clause needed.
   *
   * Consumed by PublicPostsController, which further projects the result
   * down to a public-safe field set — this method itself only handles the
   * publish-gate + filters, not field-level redaction.
   */
  async findPublished(organizationId: string, filters: FindPublishedFilters = {}): Promise<Post[]> {
    const where: FindOptionsWhere<Post> = {
      organizationId,
      publishedAt: LessThanOrEqual(new Date()),
    };
    if (filters.tournamentId) {
      where.tournamentId = filters.tournamentId;
    }
    if (filters.type) {
      if (!Object.values(PostType).includes(filters.type as PostType)) {
        throw new BadRequestException(`Invalid type filter: ${filters.type}`);
      }
      where.type = filters.type as PostType;
    }
    return this.postRepo.find({ where, order: { publishedAt: 'DESC' } });
  }
}
