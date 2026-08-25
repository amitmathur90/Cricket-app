import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { AuctionSession } from './auction-session.entity';
import { Player } from './player.entity';
import { TournamentTeam } from './tournament-team.entity';

export enum AuctionPoolStatus {
  PENDING = 'pending',
  IN_PROGRESS = 'in_progress',
  SOLD = 'sold',
  UNSOLD = 'unsold',
}

/**
 * One player's "lot" within an auction session — its base price, position
 * in the running order, and eventual outcome. A player can appear in at
 * most one pool entry per session (see the unique constraint below), but
 * may appear in pools of different sessions (e.g. re-auctioned next year).
 */
@Entity({ name: 'auction_player_pool' })
@Unique('uq_auction_pool_session_player', ['auctionSessionId', 'playerId'])
export class AuctionPlayerPool {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'auction_session_id', type: 'uuid' })
  auctionSessionId: string;

  @ManyToOne(() => AuctionSession, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'auction_session_id' })
  auctionSession: AuctionSession;

  @Index()
  @Column({ name: 'player_id', type: 'uuid' })
  playerId: string;

  @ManyToOne(() => Player, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'player_id' })
  player: Player;

  @Column({ name: 'base_price', type: 'decimal', precision: 12, scale: 2 })
  basePrice: string;

  @Column({
    type: 'enum',
    enum: AuctionPoolStatus,
    default: AuctionPoolStatus.PENDING,
  })
  status: AuctionPoolStatus;

  @Column({ name: 'final_price', type: 'decimal', precision: 12, scale: 2, nullable: true })
  finalPrice: string | null;

  @Column({ name: 'sold_to_team_id', type: 'uuid', nullable: true })
  soldToTeamId: string | null;

  @ManyToOne(() => TournamentTeam, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'sold_to_team_id' })
  soldToTeam: TournamentTeam | null;

  @Column({ name: 'lot_order', type: 'int' })
  lotOrder: number;
}
