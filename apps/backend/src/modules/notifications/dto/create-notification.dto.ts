import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ArrayNotEmpty, IsArray, IsEnum, IsOptional, IsString, IsUUID } from 'class-validator';
import { NotificationType } from '../../../database/entities/notification.entity';

/**
 * Body for the manual `POST /notifications` endpoint — used for
 * admin-triggered notices today, and the future Captain-App "team
 * announcement" feature (a team_owner broadcasting to their squad) once
 * that client feature ships. One row per recipient is created (see
 * NotificationsService.notify).
 */
export class CreateNotificationDto {
  @ApiProperty({ type: [String], description: 'User ids to notify (one notification row per recipient)' })
  @IsArray()
  @ArrayNotEmpty()
  @IsUUID('4', { each: true })
  recipientUserIds: string[];

  @ApiProperty({ enum: NotificationType })
  @IsEnum(NotificationType)
  type: NotificationType;

  @ApiProperty()
  @IsString()
  title: string;

  @ApiProperty()
  @IsString()
  message: string;

  @ApiPropertyOptional({ description: "Free-text deep-link tag, e.g. 'match', 'tournament', 'practice_session'" })
  @IsOptional()
  @IsString()
  relatedEntityType?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  relatedEntityId?: string;
}
