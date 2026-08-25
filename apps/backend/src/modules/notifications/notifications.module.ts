import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Notification } from '../../database/entities/notification.entity';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';

/**
 * In-app notification center — backend only (no push/email/SMS/WhatsApp,
 * explicitly out of scope). `NotificationsService` is exported so other
 * feature modules can import this module and inject it directly to fire
 * event-triggered notifications (tournament-application review, match
 * reschedule/result, practice session creation, auction session start,
 * roster addition) without going through HTTP — see each service's own
 * notify call site for the specific trigger.
 *
 * Time-based reminders (`match_reminder` "starts soon", `payment_reminder`)
 * are NOT wired to anything here — both would need a scheduled job/cron,
 * a different kind of infrastructure than the event-triggered inserts this
 * module does today. The enum values exist so clients can already handle
 * them; building the cron is a reasonable future addition, not done here.
 */
@Module({
  imports: [TypeOrmModule.forFeature([Notification])],
  controllers: [NotificationsController],
  providers: [NotificationsService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
