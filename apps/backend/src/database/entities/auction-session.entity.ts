import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Player } from './player.entity';
import { Tournament } from './tournament.entity';
import { TournamentTeam } from './tournament-team.entity';

export enum AuctionSessionStatus {
  SCHEDULED = 'scheduled',
  LIVE = 'live',
  PAUSED = 'paused',
  COMPLETED = 'completed',
}

/**
 * One tier of the tiered bid-increment schedule: while the current bid is
 * below `upTo`, `increment` is the minimum step for the next bid. The last
 * tier in the array should have `upTo: null` (applies above all other
 * tiers' ceilings). Stored as jsonb on `bid_increment_rules`; when absent,
 * AuctionRealtimeService falls back to a default (5% of current bid,
 * rounded to a sensible unit — see auction-bid-increment.util.ts).
 */
export interface BidIncrementRule {
  upTo: number | null;
  increment: number;
}

/**
 * A live auction event for one tournament. Tracks the lot currently under
 * the hammer (`currentPlayerId`/`currentBidAmount`/`currentBidTeamId`). All
 * mutation of these "current lot" fields happens through
 * AuctionRealtimeService under a row lock so concurrent bids can't race.
 *
 * There is deliberately NO auto-timer/countdown driving lot resolution —
 * the admin manually marks each lot SOLD or UNSOLD, then manually advances
 * via "Next Player". `currentLotEndsAt` is kept as a column (nullable,
 * always null going forward) rather than dropped, to avoid a destructive
 * migration; nothing reads or writes it as a deadline anymore.
 */
@Entity({ name: 'auction_sessions' })
export class AuctionSession {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'tournament_id', type: 'uuid' })
  tournamentId: string;

  @ManyToOne(() => Tournament, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_id' })
  tournament: Tournament;

  @Column({ type: 'varchar', length: 255 })
  name: string;

  @Column({
    type: 'enum',
    enum: AuctionSessionStatus,
    default: AuctionSessionStatus.SCHEDULED,
  })
  status: AuctionSessionStatus;

  @Column({ name: 'current_player_id', type: 'uuid', nullable: true })
  currentPlayerId: string | null;

  @ManyToOne(() => Player, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'current_player_id' })
  currentPlayer: Player | null;

  @Column({ name: 'current_bid_amount', type: 'decimal', precision: 12, scale: 2, nullable: true })
  currentBidAmount: string | null;

  @Column({ name: 'current_bid_team_id', type: 'uuid', nullable: true })
  currentBidTeamId: string | null;

  @ManyToOne(() => TournamentTeam, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'current_bid_team_id' })
  currentBidTeam: TournamentTeam | null;

  @Column({ name: 'bid_increment_rules', type: 'jsonb', nullable: true })
  bidIncrementRules: BidIncrementRule[] | null;

  @Column({ name: 'current_lot_ends_at', type: 'timestamptz', nullable: true })
  currentLotEndsAt: Date | null;

  /** Informational only — a total time budget for the whole session (shown
   * as a countdown in the UI), NOT a per-lot bidding deadline. Nothing
   * server-side enforces this; it never forces a lot to resolve. */
  @Column({ name: 'duration_minutes', type: 'int', nullable: true })
  durationMinutes: number | null;

  /** When set, starting the session resets every registered team's
   * purseTotal/purseRemaining (for this tournament) to this value — "every
   * team receives the configured default points". Null means leave each
   * team's existing purse (set at registration time) untouched. */
  @Column({ name: 'default_team_points', type: 'decimal', precision: 12, scale: 2, nullable: true })
  defaultTeamPoints: string | null;

  /** When set, a team already at this many roster players (TeamPlayer rows
   * for this tournament-team) can no longer place bids — "SQUAD FULL". */
  @Column({ name: 'max_squad_size', type: 'int', nullable: true })
  maxSquadSize: number | null;

  @Column({ name: 'started_at', type: 'timestamptz', nullable: true })
  startedAt: Date | null;

  @Column({ name: 'ended_at', type: 'timestamptz', nullable: true })
  endedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
