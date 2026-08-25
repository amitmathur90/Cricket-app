import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Official } from './official.entity';
import { Tournament } from './tournament.entity';
import { TournamentTeam } from './tournament-team.entity';
import { User } from './user.entity';
import { Venue } from './venue.entity';

export enum MatchStatus {
  SCHEDULED = 'scheduled',
  LIVE = 'live',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
}

/**
 * A fixture within a tournament, between two `tournament_teams` (a team as
 * registered in THIS tournament, not a raw org-level `Team`). Deliberately
 * cheap to create: the spec treats "Create match", "Assign teams", "Assign
 * venue", "Assign umpire/scorer" and "Reschedule" as distinct admin actions,
 * so every field below except `tournamentId` is nullable/optional — a match
 * can exist as a bare TBD-vs-TBD placeholder on the calendar and be filled
 * in incrementally via PATCH (see MatchesService).
 *
 * `resultSummary`/`winnerTournamentTeamId` are reserved for a future
 * live-scoring/points-table feature — this module never populates them.
 */
@Entity({ name: 'matches' })
export class Match {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'tournament_id', type: 'uuid' })
  tournamentId: string;

  @ManyToOne(() => Tournament, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_id' })
  tournament: Tournament;

  @Column({ name: 'home_tournament_team_id', type: 'uuid', nullable: true })
  homeTournamentTeamId: string | null;

  @ManyToOne(() => TournamentTeam, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'home_tournament_team_id' })
  homeTournamentTeam: TournamentTeam | null;

  @Column({ name: 'away_tournament_team_id', type: 'uuid', nullable: true })
  awayTournamentTeamId: string | null;

  @ManyToOne(() => TournamentTeam, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'away_tournament_team_id' })
  awayTournamentTeam: TournamentTeam | null;

  @Column({ name: 'scheduled_at', type: 'timestamptz', nullable: true })
  scheduledAt: Date | null;

  @Column({ name: 'venue_name', type: 'varchar', length: 255, nullable: true })
  venueName: string | null;

  @Column({ name: 'umpire_name', type: 'varchar', length: 255, nullable: true })
  umpireName: string | null;

  @Column({ name: 'scorer_name', type: 'varchar', length: 255, nullable: true })
  scorerName: string | null;

  /**
   * Dual-field approach (deliberate, see module doc for `venues`/`officials`):
   * the free-text `venueName`/`umpireName`/`scorerName` columns above are
   * NEVER removed or repurposed — the already-built Match Schedule/Match
   * Center UI reads/writes them directly. These FK columns are an ADDITIONAL,
   * optional way to point a match at a real `Venue`/`Official` record from
   * the new org-level management screens, without forcing every existing
   * caller to migrate. Both can be set independently; a match may have a
   * `venueName` string and no `venueId`, a `venueId` and a stale/absent
   * `venueName`, or both. Whichever surface renders the match decides which
   * field it prefers — MatchesService's response resolves these to
   * `venue`/`umpireOfficial`/`scorerOfficial`/`matchRefereeOfficial` objects
   * when present, alongside the untouched legacy strings.
   */
  @Column({ name: 'venue_id', type: 'uuid', nullable: true })
  venueId: string | null;

  @ManyToOne(() => Venue, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'venue_id' })
  venue: Venue | null;

  @Column({ name: 'umpire_official_id', type: 'uuid', nullable: true })
  umpireOfficialId: string | null;

  @ManyToOne(() => Official, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'umpire_official_id' })
  umpireOfficial: Official | null;

  @Column({ name: 'scorer_official_id', type: 'uuid', nullable: true })
  scorerOfficialId: string | null;

  @ManyToOne(() => Official, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'scorer_official_id' })
  scorerOfficial: Official | null;

  /**
   * Added alongside umpire/scorer FKs for consistency: `Official.role`
   * supports `match_referee`, and the spec's Match Schedule actions only
   * explicitly named "Assign umpire"/"Assign scorer" — but shipping the
   * `officials` module with a match-referee role and no way to assign one
   * to a match would be an inconsistency. No corresponding free-text legacy
   * column exists (there never was one), so this FK is the only way to
   * assign a match referee.
   */
  @Column({ name: 'match_referee_official_id', type: 'uuid', nullable: true })
  matchRefereeOfficialId: string | null;

  @ManyToOne(() => Official, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'match_referee_official_id' })
  matchRefereeOfficial: Official | null;

  @Column({
    type: 'enum',
    enum: MatchStatus,
    default: MatchStatus.SCHEDULED,
  })
  status: MatchStatus;

  // --- Live-scoring fields (scoring module) ---

  @Column({ name: 'result_summary', type: 'text', nullable: true })
  resultSummary: string | null;

  @Column({ name: 'winner_tournament_team_id', type: 'uuid', nullable: true })
  winnerTournamentTeamId: string | null;

  /**
   * Overs limit for this match (e.g. 20 for a T20), set by
   * ScoringRealtimeService.startMatch — defaulted from the tournament's
   * `format` when not explicitly supplied. Not part of the originally
   * reserved live-scoring columns; added here (rather than duplicated per
   * `Innings` row) because both innings of a match share the same limit
   * and it must survive a server restart between innings.
   */
  @Column({ name: 'overs_limit', type: 'int', nullable: true })
  oversLimit: number | null;

  @ManyToOne(() => TournamentTeam, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'winner_tournament_team_id' })
  winnerTournamentTeam: TournamentTeam | null;

  @Column({ name: 'created_by_user_id', type: 'uuid' })
  createdByUserId: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'created_by_user_id' })
  createdByUser: User;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
