import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Innings } from './innings.entity';
import { TeamPlayer } from './team-player.entity';

export enum OverStatus {
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
}

/**
 * One bowler's over within an innings. `overNumber` is 1-indexed (the
 * first over of an innings is 1, not 0) — purely a display/ordering
 * convention, documented here since the spec left the choice open.
 *
 * Rows are created once, at over-start (via ScoringRealtimeService's
 * `startInnings` for over 1, or `newBowler` for every over after) and
 * never deleted or replaced — only their aggregate columns
 * (`runsConceded`/`wickets`/`isMaiden`/`status`) are recomputed, from this
 * over's own `balls` rows, every time innings state changes (new ball,
 * undo). This lets a bowler be selected for the next over (creating an
 * empty in-progress Over row with 0 balls) before the first ball of that
 * over is actually bowled, without that placeholder row being wiped out by
 * a later recompute.
 *
 * `runsConceded` follows standard bowling-figures convention: it excludes
 * bye/leg_bye runs (those aren't charged against the bowler) but includes
 * the wide/no_ball penalty run and any batter runs scored off a no-ball.
 * `wickets` here counts EVERY dismissal in the over (including run-outs,
 * which aren't bowler-credited) — this column is for the over-by-over
 * summary display, not the bowler's personal wicket tally (that's
 * computed separately in the scorecard query, excluding run-outs).
 */
@Entity({ name: 'overs' })
export class Over {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'innings_id', type: 'uuid' })
  inningsId: string;

  @ManyToOne(() => Innings, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'innings_id' })
  innings: Innings;

  @Column({ name: 'over_number', type: 'int' })
  overNumber: number;

  @Column({ name: 'bowler_team_player_id', type: 'uuid' })
  bowlerTeamPlayerId: string;

  @ManyToOne(() => TeamPlayer, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'bowler_team_player_id' })
  bowlerTeamPlayer: TeamPlayer;

  @Column({ name: 'runs_conceded', type: 'int', default: 0 })
  runsConceded: number;

  @Column({ type: 'int', default: 0 })
  wickets: number;

  @Column({ name: 'is_maiden', type: 'boolean', default: false })
  isMaiden: boolean;

  @Column({
    type: 'enum',
    enum: OverStatus,
    default: OverStatus.IN_PROGRESS,
  })
  status: OverStatus;
}
