import type { PillTone } from '../../shared/components/StatusPill'
import type { MatchStatus } from '../../types/match'

/** Mirrors match_card.dart's `statusColor` (scheduled -> info, live -> the
 * dedicated live/red token, completed -> a muted tone, cancelled -> muted).
 * Same "completed -> navy" choice as tournamentStatusTone in
 * features/tournaments/statusTones.ts, for visual consistency between the
 * two status pill families; cancelled uses `neutral` (no dedicated "muted"
 * PillTone exists) so it still reads as visually de-emphasized. */
export function matchStatusTone(status: MatchStatus): PillTone {
  switch (status) {
    case 'scheduled':
      return 'info'
    case 'live':
      return 'live'
    case 'completed':
      return 'navy'
    case 'cancelled':
      return 'neutral'
  }
}
