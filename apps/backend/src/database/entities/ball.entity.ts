import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Innings } from './innings.entity';
import { Over } from './over.entity';
import { TeamPlayer } from './team-player.entity';

export enum ExtraType {
  WIDE = 'wide',
  NO_BALL = 'no_ball',
  BYE = 'bye',
  LEG_BYE = 'leg_bye',
  PENALTY = 'penalty',
}

export enum DismissalType {
  BOWLED = 'bowled',
  CAUGHT = 'caught',
  LBW = 'lbw',
  RUN_OUT = 'run_out',
  STUMPED = 'stumped',
  HIT_WICKET = 'hit_wicket',
  RETIRED_HURT = 'retired_hurt',
}

/**
 * The atomic, append-only ball-by-ball event log — the source of truth for
 * everything else in the scoring engine. `Innings`/`Over`/`Partnership`
 * aggregate columns and all batting/bowling figures are derived
 * (recomputed) from this table; a ball row itself is never mutated after
 * insert except for `voided`/`voidedAt` (the undo-last-ball escape hatch,
 * mirroring `AuctionBid.voided` exactly — a corrected ball genuinely was
 * bowled, so hard-deleting it would silently rewrite history).
 *
 * `strikerTeamPlayerId`/`nonStrikerTeamPlayerId`/`bowlerTeamPlayerId` are
 * historical facts fixed at insert time (who this specific delivery was
 * actually bowled to/by) and are NEVER recomputed afterward — this is what
 * makes replay-based aggregation (used by both normal recording and undo)
 * safe: every row is a frozen, self-contained fact, and totals/partnerships
 * are pure sums/groupings over the non-voided rows in `sequenceNumber`
 * order.
 *
 * `nextBatterTeamPlayerId` is an addition beyond the originally-specified
 * columns: on a wicket ball it records who came in to replace the
 * dismissed player (null if that wicket ended the innings). Without this,
 * replaying the ball log after an undo couldn't reconstruct who took
 * strike next purely from `dismissedTeamPlayerId` (which only says who got
 * out, not who replaced them) — see ScoringRealtimeService's
 * recomputeInningsAggregates for how it's used.
 *
 * `ballNumberInOver` is the LEGAL-ball slot (1-6+), not a raw row count: a
 * wide/no-ball at slot 5 and the legal delivery that eventually completes
 * slot 5 are BOTH numbered 5 — only `sequenceNumber` (monotonic across
 * every row, legal or not) uniquely orders deliveries within the innings.
 */
@Entity({ name: 'balls' })
export class Ball {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'innings_id', type: 'uuid' })
  inningsId: string;

  @ManyToOne(() => Innings, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'innings_id' })
  innings: Innings;

  @Index()
  @Column({ name: 'over_id', type: 'uuid' })
  overId: string;

  @ManyToOne(() => Over, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'over_id' })
  over: Over;

  @Column({ name: 'ball_number_in_over', type: 'int' })
  ballNumberInOver: number;

  @Column({ name: 'striker_team_player_id', type: 'uuid' })
  strikerTeamPlayerId: string;

  @ManyToOne(() => TeamPlayer, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'striker_team_player_id' })
  strikerTeamPlayer: TeamPlayer;

  @Column({ name: 'non_striker_team_player_id', type: 'uuid' })
  nonStrikerTeamPlayerId: string;

  @ManyToOne(() => TeamPlayer, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'non_striker_team_player_id' })
  nonStrikerTeamPlayer: TeamPlayer;

  @Column({ name: 'bowler_team_player_id', type: 'uuid' })
  bowlerTeamPlayerId: string;

  @ManyToOne(() => TeamPlayer, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'bowler_team_player_id' })
  bowlerTeamPlayer: TeamPlayer;

  @Column({ name: 'runs_batter', type: 'int', default: 0 })
  runsBatter: number;

  @Column({ name: 'runs_extra', type: 'int', default: 0 })
  runsExtra: number;

  @Column({ name: 'extra_type', type: 'enum', enum: ExtraType, nullable: true })
  extraType: ExtraType | null;

  @Column({ name: 'is_wicket', type: 'boolean', default: false })
  isWicket: boolean;

  @Column({ name: 'dismissal_type', type: 'enum', enum: DismissalType, nullable: true })
  dismissalType: DismissalType | null;

  @Column({ name: 'dismissed_team_player_id', type: 'uuid', nullable: true })
  dismissedTeamPlayerId: string | null;

  @ManyToOne(() => TeamPlayer, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'dismissed_team_player_id' })
  dismissedTeamPlayer: TeamPlayer | null;

  @Column({ name: 'fielder_team_player_id', type: 'uuid', nullable: true })
  fielderTeamPlayerId: string | null;

  @ManyToOne(() => TeamPlayer, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'fielder_team_player_id' })
  fielderTeamPlayer: TeamPlayer | null;

  /** Who replaced `dismissedTeamPlayerId` — see class doc. Null if not a wicket ball, or if the wicket ended the innings. */
  @Column({ name: 'next_batter_team_player_id', type: 'uuid', nullable: true })
  nextBatterTeamPlayerId: string | null;

  @ManyToOne(() => TeamPlayer, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'next_batter_team_player_id' })
  nextBatterTeamPlayer: TeamPlayer | null;

  @Column({ name: 'commentary_text', type: 'text', nullable: true })
  commentaryText: string | null;

  /** Monotonic within the innings across ALL rows (legal or not, voided or not) — never reused. */
  @Column({ name: 'sequence_number', type: 'int' })
  sequenceNumber: number;

  /** True once this ball has been reverted by scoring.undoLastBall. See class doc. */
  @Column({ type: 'boolean', default: false })
  voided: boolean;

  @Column({ name: 'voided_at', type: 'timestamptz', nullable: true })
  voidedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
