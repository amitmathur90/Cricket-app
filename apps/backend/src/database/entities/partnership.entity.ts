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

/**
 * A batting partnership: the pair of batters at the crease together,
 * spanning from `startBallSequence` to `endBallSequence` (null while the
 * pair is still batting — every innings has at most one active
 * partnership at a time). A new partnership begins exactly when the
 * *set* of two batters at the crease changes — i.e. after a wicket
 * (strike ROTATION alone, via odd runs or end-of-over, does not start a
 * new partnership: it's still the same two people, just facing from
 * different ends).
 *
 * `runs` follows the common ESPNcricinfo-style convention of counting ALL
 * runs added to the team total while the pair batted together (batter runs
 * AND every extra type) — not just runs off the bat. `ballsFaced` counts
 * only legal deliveries (mirrors the over's own ball-progression count),
 * documented here since neither convention is universal and the spec left
 * it open.
 *
 * Rows are rebuilt (not incrementally patched) by
 * ScoringRealtimeService.recomputeInningsAggregates on every state change,
 * by grouping the innings' non-voided balls by their (striker,
 * non-striker) unordered pair in sequence order — see that method's doc
 * for why this is safe and correct for undo.
 */
@Entity({ name: 'partnerships' })
export class Partnership {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'innings_id', type: 'uuid' })
  inningsId: string;

  @ManyToOne(() => Innings, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'innings_id' })
  innings: Innings;

  @Column({ name: 'batter1_team_player_id', type: 'uuid' })
  batter1TeamPlayerId: string;

  @ManyToOne(() => TeamPlayer, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'batter1_team_player_id' })
  batter1: TeamPlayer;

  @Column({ name: 'batter2_team_player_id', type: 'uuid' })
  batter2TeamPlayerId: string;

  @ManyToOne(() => TeamPlayer, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'batter2_team_player_id' })
  batter2: TeamPlayer;

  @Column({ name: 'start_ball_sequence', type: 'int' })
  startBallSequence: number;

  @Column({ name: 'end_ball_sequence', type: 'int', nullable: true })
  endBallSequence: number | null;

  @Column({ type: 'int', default: 0 })
  runs: number;

  @Column({ name: 'balls_faced', type: 'int', default: 0 })
  ballsFaced: number;
}
