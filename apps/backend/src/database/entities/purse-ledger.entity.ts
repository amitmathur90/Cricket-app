import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { AuctionSession } from './auction-session.entity';
import { Player } from './player.entity';
import { TournamentTeam } from './tournament-team.entity';

export enum PurseLedgerType {
  DEBIT = 'debit',
  CREDIT = 'credit',
}

/**
 * Auditable trail of every purse change for a tournament-team. Written
 * inside the same DB transaction that updates the denormalized
 * `tournament_teams.purse_remaining` cache, so the two never drift —
 * this table is the source of truth for "why did the purse change",
 * `purse_remaining` is just the fast-read total.
 */
@Entity({ name: 'purse_ledger' })
export class PurseLedger {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'tournament_team_id', type: 'uuid' })
  tournamentTeamId: string;

  @ManyToOne(() => TournamentTeam, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_team_id' })
  tournamentTeam: TournamentTeam;

  @Column({ name: 'auction_session_id', type: 'uuid', nullable: true })
  auctionSessionId: string | null;

  @ManyToOne(() => AuctionSession, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'auction_session_id' })
  auctionSession: AuctionSession | null;

  @Column({ name: 'player_id', type: 'uuid', nullable: true })
  playerId: string | null;

  @ManyToOne(() => Player, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'player_id' })
  player: Player | null;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amount: string;

  @Column({ type: 'enum', enum: PurseLedgerType })
  type: PurseLedgerType;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
