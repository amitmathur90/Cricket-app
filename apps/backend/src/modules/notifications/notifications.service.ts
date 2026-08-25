import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notification, NotificationType } from '../../database/entities/notification.entity';
import { CreateNotificationDto } from './dto/create-notification.dto';

export interface NotifyInput {
  type: NotificationType;
  title: string;
  message: string;
  relatedEntityType?: string | null;
  relatedEntityId?: string | null;
}

export interface FindNotificationsFilters {
  unreadOnly?: boolean;
  limit?: number;
  offset?: number;
}

const DEFAULT_LIMIT = 50;

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(Notification) private readonly notificationRepo: Repository<Notification>,
  ) {}

  /**
   * Lightweight internal entry point for OTHER modules to call directly
   * (no HTTP round trip) — bulk-inserts one row per recipient.
   *
   * Deliberately tolerant of a sparse/empty recipient list: several call
   * sites build `userIds` from optional fields (e.g. `Team.ownerUserId`,
   * which may be null for one or both teams in a match) and should never
   * have to special-case "nobody happens to be notifiable right now" —
   * this just silently no-ops rather than throwing.
   */
  async notify(organizationId: string, userIds: string[], input: NotifyInput): Promise<void> {
    const uniqueUserIds = [...new Set(userIds.filter((id): id is string => !!id))];
    if (uniqueUserIds.length === 0) {
      return;
    }
    const rows = uniqueUserIds.map((userId) =>
      this.notificationRepo.create({
        organizationId,
        userId,
        type: input.type,
        title: input.title,
        message: input.message,
        relatedEntityType: input.relatedEntityType ?? null,
        relatedEntityId: input.relatedEntityId ?? null,
      }),
    );
    await this.notificationRepo.insert(rows);
  }

  /** Admin/captain-triggered creation via `POST /notifications` — same fan-out as notify(), DTO-shaped. */
  async createForRecipients(organizationId: string, dto: CreateNotificationDto): Promise<{ created: number }> {
    const uniqueUserIds = [...new Set(dto.recipientUserIds)];
    await this.notify(organizationId, uniqueUserIds, {
      type: dto.type,
      title: dto.title,
      message: dto.message,
      relatedEntityType: dto.relatedEntityType ?? null,
      relatedEntityId: dto.relatedEntityId ?? null,
    });
    return { created: uniqueUserIds.length };
  }

  /** The caller's own notifications, newest first. Never cross-user — always scoped to (organizationId, userId). */
  async findAllForUser(
    organizationId: string,
    userId: string,
    filters: FindNotificationsFilters,
  ): Promise<Notification[]> {
    const limit = filters.limit && filters.limit > 0 ? filters.limit : DEFAULT_LIMIT;
    const offset = filters.offset && filters.offset > 0 ? filters.offset : 0;
    return this.notificationRepo.find({
      where: { organizationId, userId, ...(filters.unreadOnly ? { isRead: false } : {}) },
      order: { createdAt: 'DESC' },
      take: limit,
      skip: offset,
    });
  }

  async unreadCount(organizationId: string, userId: string): Promise<{ count: number }> {
    const count = await this.notificationRepo.count({ where: { organizationId, userId, isRead: false } });
    return { count };
  }

  /**
   * Marks one notification read. Scoped to (id, organizationId, userId) in
   * a single query, so a notification belonging to a different user in the
   * same org 404s exactly like one that doesn't exist at all — same
   * "don't leak existence of other users' rows" convention as the rest of
   * this codebase's org-scoped lookups.
   */
  async markAsRead(organizationId: string, userId: string, notificationId: string): Promise<Notification> {
    const notification = await this.notificationRepo.findOne({
      where: { id: notificationId, organizationId, userId },
    });
    if (!notification) {
      throw new NotFoundException('Notification not found');
    }
    if (!notification.isRead) {
      notification.isRead = true;
      notification.readAt = new Date();
      await this.notificationRepo.save(notification);
    }
    return notification;
  }

  async markAllAsRead(organizationId: string, userId: string): Promise<{ updated: number }> {
    const result = await this.notificationRepo
      .createQueryBuilder()
      .update(Notification)
      .set({ isRead: true, readAt: new Date() })
      .where('organization_id = :organizationId', { organizationId })
      .andWhere('user_id = :userId', { userId })
      .andWhere('is_read = false')
      .execute();
    return { updated: result.affected ?? 0 };
  }
}
