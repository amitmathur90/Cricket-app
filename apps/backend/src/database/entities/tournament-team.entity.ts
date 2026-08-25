import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { Team } from './team.entity';
import { Tournament } from './tournament.entity';
import { TournamentGroup } from './tournament-group.entity';

export enum TournamentTeamStatus {
  REGISTERED = 'registered',
  WITHDRAWN = 'withdrawn',
}

/**
 * A team's participation in one specific tournament — including its
 * auction purse for that tournament. This is the row `team_players`
 * rosters hang off of (a player can be on different tournament rosters
 * for the same org-level Team across different tournaments).
 */
@Entity({ name: 'tournament_teams' })
@Unique('uq_tournament_team', ['tournamentId', 'teamId'])
export class TournamentTeam {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'tournament_id', type: 'uuid' })
  tournamentId: string;

  @ManyToOne(() => Tournament, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_id' })
  tournament: Tournament;

  @Index()
  @Column({ name: 'team_id', type: 'uuid' })
  teamId: string;

  @ManyToOne(() => Team, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'team_id' })
  team: Team;

  @Column({ name: 'group_id', type: 'uuid', nullable: true })
  groupId: string | null;

  @ManyToOne(() => TournamentGroup, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'group_id' })
  group: TournamentGroup | null;

  @Column({
    type: 'enum',
    enum: TournamentTeamStatus,
    default: TournamentTeamStatus.REGISTERED,
  })
  status: TournamentTeamStatus;

  @Column({ name: 'purse_total', type: 'decimal', precision: 12, scale: 2, nullable: true })
  purseTotal: string | null;

  @Column({ name: 'purse_remaining', type: 'decimal', precision: 12, scale: 2, nullable: true })
  purseRemaining: string | null;
}
