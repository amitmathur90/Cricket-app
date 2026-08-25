import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Coach } from '../../database/entities/coach.entity';
import { Player } from '../../database/entities/player.entity';
import { PracticeAttendance } from '../../database/entities/practice-attendance.entity';
import { PracticeSession } from '../../database/entities/practice-session.entity';
import { Team } from '../../database/entities/team.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { PracticeAttendanceController } from './practice-attendance.controller';
import { PracticeAttendanceService } from './practice-attendance.service';
import { PracticeSessionsController } from './practice-sessions.controller';
import { PracticeSessionsService } from './practice-sessions.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([PracticeSession, PracticeAttendance, Team, Coach, Player]),
    NotificationsModule,
  ],
  controllers: [PracticeSessionsController, PracticeAttendanceController],
  providers: [PracticeSessionsService, PracticeAttendanceService],
  exports: [PracticeSessionsService, PracticeAttendanceService],
})
export class PracticeModule {}
