import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Coach } from './coach.entity';
import { Organization } from './organization.entity';
import { Team } from './team.entity';
import { User } from './user.entity';

export enum PracticeType {
  BATTING = 'batting',
  BOWLING = 'bowling',
  FIELDING = 'fielding',
  FITNESS = 'fitness',
  NET_PRACTICE = 'net_practice',
  STRATEGY_SESSION = 'strategy_session',
}

export enum PracticeSessionStatus {
  SCHEDULED = 'scheduled',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
}

/**
 * A practice session belongs to an org-level `Team` — deliberately NOT
 * tournament-scoped (unlike `Match`, which hangs off a `Tournament`), since
 * practice happens independent of any specific tournament. `coachId` is
 * nullable + SET NULL (a session can exist without an assigned coach, and
 * deleting a coach shouldn't cascade-delete practice history).
 */
@Entity({ name: 'practice_sessions' })
export class PracticeSession {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @Index()
  @Column({ name: 'team_id', type: 'uuid' })
  teamId: string;

  @ManyToOne(() => Team, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'team_id' })
  team: Team;

  @Column({ name: 'coach_id', type: 'uuid', nullable: true })
  coachId: string | null;

  @ManyToOne(() => Coach, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'coach_id' })
  coach: Coach | null;

  /** Combines the spec's separate Date/Time fields into one instant. */
  @Column({ name: 'scheduled_at', type: 'timestamptz' })
  scheduledAt: Date;

  @Column({ name: 'venue_name', type: 'varchar', length: 255, nullable: true })
  venueName: string | null;

  @Column({ name: 'practice_type', type: 'enum', enum: PracticeType })
  practiceType: PracticeType;

  @Column({ name: 'duration_minutes', type: 'int', nullable: true })
  durationMinutes: number | null;

  @Column({ type: 'text', nullable: true })
  notes: string | null;

  @Column({
    type: 'enum',
    enum: PracticeSessionStatus,
    default: PracticeSessionStatus.SCHEDULED,
  })
  status: PracticeSessionStatus;

  @Column({ name: 'created_by_user_id', type: 'uuid' })
  createdByUserId: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'created_by_user_id' })
  createdByUser: User;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
