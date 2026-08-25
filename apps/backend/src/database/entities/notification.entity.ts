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
import { User } from './user.entity';

/**
 * In-app notification types. `payment_reminder` and `match_reminder` are
 * defined here (so clients can already branch on them) but are not
 * currently emitted by any trigger — both would need a scheduled job/cron
 * (time-based "starts soon" logic) rather than an event-triggered insert,
 * which is out of scope for this module; see NotificationsModule doc.
 * `announcement` is reserved for the future Captain-App "team announcement"
 * broadcast feature and is reachable today only via the manual
 * `POST /notifications` endpoint.
 */
export enum NotificationType {
  MATCH_REMINDER = 'match_reminder',
  PRACTICE_REMINDER = 'practice_reminder',
  AUCTION_ANNOUNCEMENT = 'auction_announcement',
  PLAYER_APPROVAL = 'player_approval',
  TEAM_SELECTION = 'team_selection',
  MATCH_RESULT = 'match_result',
  SCHEDULE_CHANGE = 'schedule_change',
  PAYMENT_REMINDER = 'payment_reminder',
  ANNOUNCEMENT = 'announcement',
}

/**
 * A single in-app notification for one recipient (`userId`). Notifications
 * are always addressed to exactly one user — a "broadcast to N recipients"
 * write (see NotificationsService.notify) is just N of these rows, not a
 * separate fan-out table, which keeps read/unread-count/mark-as-read all
 * simple per-row operations scoped to `userId`.
 *
 * `relatedEntityType`/`relatedEntityId` are a deliberately loose, free-text
 * pairing (not a typed FK) so the client can build a deep link (e.g.
 * `relatedEntityType: 'match'` -> navigate to that match) without this
 * table needing a nullable FK column per possible entity type.
 */
@Entity({ name: 'notifications' })
export class Notification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  /** The recipient. A user only ever sees their own notifications — see NotificationsService. */
  @Index()
  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'enum', enum: NotificationType })
  type: NotificationType;

  @Column({ type: 'varchar', length: 255 })
  title: string;

  @Column({ type: 'text' })
  message: string;

  /** Free-text deep-link tag for the client (e.g. 'match', 'tournament', 'practice_session'). */
  @Column({ name: 'related_entity_type', type: 'varchar', length: 50, nullable: true })
  relatedEntityType: string | null;

  @Column({ name: 'related_entity_id', type: 'uuid', nullable: true })
  relatedEntityId: string | null;

  @Index()
  @Column({ name: 'is_read', type: 'boolean', default: false })
  isRead: boolean;

  @Column({ name: 'read_at', type: 'timestamptz', nullable: true })
  readAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
