import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { AuctionPlayerPool } from './auction-player-pool.entity';
import { AuctionSession } from './auction-session.entity';
import { TournamentTeam } from './tournament-team.entity';

/**
 * Audit log of every bid placed during a live auction. `bidSequence` is
 * the 1-based order the bid was placed within its lot (auction_player_pool
 * row), assigned inside the same row-locked transaction that serializes
 * bids per session so it can never collide.
 *
 * Bids are otherwise append-only — the one exception is the admin
 * "undo last bid" action (AuctionRealtimeService.undoLastBid), which never
 * hard-deletes a bid row (that would silently rewrite history: the bid
 * really was placed). Instead it flips `voided`/`voidedAt` on the
 * most-recent row for the current lot, so the audit trail stays honest
 * while `currentBidAmount`/`currentBidTeamId` get recomputed from the
 * next-most-recent non-voided bid.
 */
@Entity({ name: 'auction_bids' })
export class AuctionBid {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'auction_session_id', type: 'uuid' })
  auctionSessionId: string;

  @ManyToOne(() => AuctionSession, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'auction_session_id' })
  auctionSession: AuctionSession;

  @Index()
  @Column({ name: 'auction_player_pool_id', type: 'uuid' })
  auctionPlayerPoolId: string;

  @ManyToOne(() => AuctionPlayerPool, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'auction_player_pool_id' })
  auctionPlayerPool: AuctionPlayerPool;

  @Index()
  @Column({ name: 'team_id', type: 'uuid' })
  teamId: string;

  @ManyToOne(() => TournamentTeam, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'team_id' })
  team: TournamentTeam;

  @Column({ name: 'bid_amount', type: 'decimal', precision: 12, scale: 2 })
  bidAmount: string;

  @Column({ name: 'bid_sequence', type: 'int' })
  bidSequence: number;

  /** True once this bid has been undone by an admin via undo-last-bid. */
  @Column({ name: 'voided', type: 'boolean', default: false })
  voided: boolean;

  @Column({ name: 'voided_at', type: 'timestamptz', nullable: true })
  voidedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
