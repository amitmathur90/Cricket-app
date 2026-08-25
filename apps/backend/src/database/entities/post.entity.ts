import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Organization } from './organization.entity';
import { Tournament } from './tournament.entity';
import { User } from './user.entity';

export enum PostType {
  NEWS = 'news',
  PHOTO = 'photo',
  VIDEO = 'video',
}

/**
 * A lightweight news/media post — the content behind the mobile app's
 * public fan section (News / Photos / Videos tabs). Org-wide by default
 * (`tournamentId` null); scoping a post to one tournament is optional.
 * `videoUrl` is always an external link (YouTube, etc.) — this module does
 * NOT host video files; `imageUrl` reuses the existing generic
 * UploadsController unchanged. `type` is a primary-categorization label for
 * client-side filtering (News/Photos/Videos tabs), not a strict exclusivity
 * rule — a `news`-typed post can still carry an `imageUrl`.
 *
 * `publishedAt` is the draft/publish gate: null means draft (visible only
 * to authenticated org members via the admin CRUD endpoints in
 * `modules/posts`); a past-or-present timestamp means published (also
 * visible via the unauthenticated `public/...` endpoints — see
 * `PostsService.findPublished`). A future timestamp lets an admin schedule
 * a post ahead of time without it appearing publicly yet.
 */
@Entity({ name: 'posts' })
export class Post {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @Index()
  @Column({ name: 'tournament_id', type: 'uuid', nullable: true })
  tournamentId: string | null;

  @ManyToOne(() => Tournament, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_id' })
  tournament: Tournament | null;

  @Column({ type: 'varchar', length: 255 })
  title: string;

  @Column({ type: 'text' })
  body: string;

  @Column({ name: 'image_url', type: 'varchar', length: 512, nullable: true })
  imageUrl: string | null;

  @Column({ name: 'video_url', type: 'varchar', length: 512, nullable: true })
  videoUrl: string | null;

  @Column({ type: 'enum', enum: PostType, default: PostType.NEWS })
  type: PostType;

  @Column({ name: 'published_at', type: 'timestamptz', nullable: true })
  publishedAt: Date | null;

  @Column({ name: 'created_by_user_id', type: 'uuid' })
  createdByUserId: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'created_by_user_id' })
  createdByUser: User;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
