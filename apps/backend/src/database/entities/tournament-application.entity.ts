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
import { Tournament } from './tournament.entity';
import { User } from './user.entity';

export enum TournamentApplicationStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

/**
 * A player-role user's self-service application to join a specific
 * tournament (see TournamentApplicationsService.apply). One application per
 * user per tournament — the unique constraint below blocks a second
 * application to the same tournament outright (including after a
 * rejection); there is no resubmission flow in M1. A user may still apply
 * to a *different* tournament.
 *
 * Approving an application does NOT automatically add the player to any
 * auction pool or team roster — that remains a separate, manual admin
 * action via the existing Players/Auction endpoints. Deliberate scope
 * boundary, not an oversight.
 */
@Entity({ name: 'tournament_applications' })
@Unique('uq_tournament_application_tournament_user', ['tournamentId', 'userId'])
export class TournamentApplication {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'tournament_id', type: 'uuid' })
  tournamentId: string;

  @ManyToOne(() => Tournament, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_id' })
  tournament: Tournament;

  @Index()
  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  /** Set once the applicant's org-level Player profile is created/linked. */
  @Column({ name: 'player_id', type: 'uuid', nullable: true })
  playerId: string | null;

  @ManyToOne(() => Player, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'player_id' })
  player: Player | null;

  @Column({
    type: 'enum',
    enum: TournamentApplicationStatus,
    default: TournamentApplicationStatus.PENDING,
  })
  status: TournamentApplicationStatus;

  @Column({ name: 'review_note', type: 'varchar', length: 255, nullable: true })
  reviewNote: string | null;

  @Column({ name: 'reviewed_by_user_id', type: 'uuid', nullable: true })
  reviewedByUserId: string | null;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'reviewed_by_user_id' })
  reviewedByUser: User | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @Column({ name: 'reviewed_at', type: 'timestamptz', nullable: true })
  reviewedAt: Date | null;
}
