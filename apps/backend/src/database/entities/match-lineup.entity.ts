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
import { Match } from './match.entity';
import { TeamPlayer } from './team-player.entity';
import { TournamentTeam } from './tournament-team.entity';

export enum MatchLineupRole {
  PLAYING = 'playing',
  SUBSTITUTE = 'substitute',
}

/**
 * One roster member's (`team_players` row) participation status for one
 * specific match: Playing XI or substitute. Per-match, per-team — a
 * `tournament_teams` squad can field a different Playing XI in every match
 * of the tournament, hence this is keyed off `matchId` + `teamPlayerId`
 * rather than living on `team_players` itself.
 *
 * `tournamentTeamId` is denormalized alongside `teamPlayerId` (rather than
 * derived by joining through team_players -> tournament_teams every read)
 * so a lineup row can be validated/queried directly against
 * `match.home/awayTournamentTeamId` without an extra join, and so the
 * unique constraint + FK-cascade story stays simple.
 */
@Entity({ name: 'match_lineups' })
@Unique('uq_match_lineup_team_player', ['matchId', 'teamPlayerId'])
export class MatchLineup {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'match_id', type: 'uuid' })
  matchId: string;

  @ManyToOne(() => Match, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'match_id' })
  match: Match;

  @Index()
  @Column({ name: 'tournament_team_id', type: 'uuid' })
  tournamentTeamId: string;

  @ManyToOne(() => TournamentTeam, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_team_id' })
  tournamentTeam: TournamentTeam;

  @Index()
  @Column({ name: 'team_player_id', type: 'uuid' })
  teamPlayerId: string;

  @ManyToOne(() => TeamPlayer, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'team_player_id' })
  teamPlayer: TeamPlayer;

  @Column({
    type: 'enum',
    enum: MatchLineupRole,
    enumName: 'match_lineups_role_enum',
  })
  role: MatchLineupRole;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
