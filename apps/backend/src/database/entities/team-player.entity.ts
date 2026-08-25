import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { Player } from './player.entity';
import { TournamentTeam } from './tournament-team.entity';

export enum AcquisitionType {
  AUCTION = 'auction',
  DIRECT_SIGNING = 'direct_signing',
  RETAINED = 'retained',
}

export enum TeamPlayerStatus {
  ACTIVE = 'active',
  RELEASED = 'released',
}

/**
 * The resolved roster: a player's membership on a specific tournament-team.
 * Populated either directly (M1, `direct_signing`) or via the auction
 * module (M4, `auction`) once that's built.
 */
@Entity({ name: 'team_players' })
@Unique('uq_team_player', ['tournamentTeamId', 'playerId'])
export class TeamPlayer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'tournament_team_id', type: 'uuid' })
  tournamentTeamId: string;

  @ManyToOne(() => TournamentTeam, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_team_id' })
  tournamentTeam: TournamentTeam;

  @Index()
  @Column({ name: 'player_id', type: 'uuid' })
  playerId: string;

  @ManyToOne(() => Player, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'player_id' })
  player: Player;

  @Column({ name: 'jersey_number', type: 'int', nullable: true })
  jerseyNumber: number | null;

  @Column({ name: 'is_captain', type: 'boolean', default: false })
  isCaptain: boolean;

  @Column({ name: 'is_vice_captain', type: 'boolean', default: false })
  isViceCaptain: boolean;

  @Column({ name: 'is_wicketkeeper', type: 'boolean', default: false })
  isWicketkeeper: boolean;

  @Column({
    name: 'acquisition_type',
    type: 'enum',
    enum: AcquisitionType,
    default: AcquisitionType.DIRECT_SIGNING,
  })
  acquisitionType: AcquisitionType;

  @Column({ name: 'acquired_price', type: 'decimal', precision: 12, scale: 2, nullable: true })
  acquiredPrice: string | null;

  @Column({
    type: 'enum',
    enum: TeamPlayerStatus,
    default: TeamPlayerStatus.ACTIVE,
  })
  status: TeamPlayerStatus;
}
