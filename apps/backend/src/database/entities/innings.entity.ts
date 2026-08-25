import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Match } from './match.entity';
import { TeamPlayer } from './team-player.entity';
import { TournamentTeam } from './tournament-team.entity';

export enum InningsStatus {
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
}

/**
 * One team's batting innings within a match. This app is T20/ODI-oriented
 * (see TournamentFormat) so `inningsNumber` is always 1 or 2 — a Test-style
 * multi-innings model is deliberately out of scope.
 *
 * `totalOversBowled` is stored as `overs.balls` notation (e.g. 15.2 means 15
 * completed overs + 2 legal balls into the 16th), matching how cricket
 * scoreboards conventionally display it — NOT a true decimal (15.6 never
 * occurs; it rolls to 16.0). It's a read-model convenience column,
 * recomputed from the `balls` table on every state change alongside
 * `totalRuns`/`totalWickets`/`extrasTotal` (see ScoringRealtimeService.
 * recomputeInningsAggregates) — the balls table remains the source of
 * truth throughout.
 *
 * `currentStrikerTeamPlayerId`/`currentNonStrikerTeamPlayerId` are a
 * server-authoritative "live cursor" cache — who's currently at the crease,
 * always recomputed (never trusted from a client) alongside the rest of the
 * aggregate state. This mirrors AuctionSession's `currentPlayerId`/
 * `currentBidAmount`/`currentBidTeamId` "current lot" pattern: a cheap,
 * always-fresh cache of state that's also derivable (in this case, from the
 * `balls` table) but expensive to re-derive on every read.
 */
@Entity({ name: 'innings' })
export class Innings {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'match_id', type: 'uuid' })
  matchId: string;

  @ManyToOne(() => Match, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'match_id' })
  match: Match;

  @Column({ name: 'innings_number', type: 'int' })
  inningsNumber: number;

  @Column({ name: 'batting_tournament_team_id', type: 'uuid' })
  battingTournamentTeamId: string;

  @ManyToOne(() => TournamentTeam, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'batting_tournament_team_id' })
  battingTournamentTeam: TournamentTeam;

  @Column({ name: 'bowling_tournament_team_id', type: 'uuid' })
  bowlingTournamentTeamId: string;

  @ManyToOne(() => TournamentTeam, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'bowling_tournament_team_id' })
  bowlingTournamentTeam: TournamentTeam;

  @Column({ name: 'total_runs', type: 'int', default: 0 })
  totalRuns: number;

  @Column({ name: 'total_wickets', type: 'int', default: 0 })
  totalWickets: number;

  @Column({ name: 'total_overs_bowled', type: 'decimal', precision: 5, scale: 1, default: 0 })
  totalOversBowled: string;

  @Column({ name: 'extras_total', type: 'int', default: 0 })
  extrasTotal: number;

  @Column({
    type: 'enum',
    enum: InningsStatus,
    default: InningsStatus.IN_PROGRESS,
  })
  status: InningsStatus;

  // --- Server-authoritative live cursor cache (see class doc) ---

  @Column({ name: 'current_striker_team_player_id', type: 'uuid', nullable: true })
  currentStrikerTeamPlayerId: string | null;

  @ManyToOne(() => TeamPlayer, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'current_striker_team_player_id' })
  currentStriker: TeamPlayer | null;

  @Column({ name: 'current_non_striker_team_player_id', type: 'uuid', nullable: true })
  currentNonStrikerTeamPlayerId: string | null;

  @ManyToOne(() => TeamPlayer, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'current_non_striker_team_player_id' })
  currentNonStriker: TeamPlayer | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
