import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { Player } from './player.entity';
import { PracticeSession } from './practice-session.entity';

export enum PracticeAttendanceStatus {
  PRESENT = 'present',
  ABSENT = 'absent',
}

/**
 * Per-player attendance for one practice session. References the org-level
 * `Player` directly (not `team_players`/roster) — a player can attend their
 * team's practice regardless of which tournament roster they're on; there's
 * no natural "team roster" without a tournament context. See
 * PracticeAttendanceService for the "only rows that exist are returned"
 * read semantics (a missing row means "not yet marked", not "absent").
 */
@Entity({ name: 'practice_attendance' })
@Unique('uq_practice_attendance_session_player', ['practiceSessionId', 'playerId'])
export class PracticeAttendance {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'practice_session_id', type: 'uuid' })
  practiceSessionId: string;

  @ManyToOne(() => PracticeSession, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'practice_session_id' })
  practiceSession: PracticeSession;

  @Index()
  @Column({ name: 'player_id', type: 'uuid' })
  playerId: string;

  @ManyToOne(() => Player, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'player_id' })
  player: Player;

  @Column({
    type: 'enum',
    enum: PracticeAttendanceStatus,
    default: PracticeAttendanceStatus.ABSENT,
  })
  status: PracticeAttendanceStatus;

  @Column({ name: 'marked_at', type: 'timestamptz', nullable: true })
  markedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
