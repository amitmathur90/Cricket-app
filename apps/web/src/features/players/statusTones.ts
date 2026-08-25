import type { PillTone } from '../../shared/components/StatusPill'
import type { PlayerVerificationStatus } from '../../types/player'

/** Judgment call, mirroring apps/mobile's PlayerListTab._VerificationChip
 * (orange/blue/green/red for pending/verified/approved/rejected): pending
 * uses `warning` (amber), verified uses `info` (blue) — "docs checked but
 * not fully cleared" — approved uses `positive` (green) — "fully cleared" —
 * and rejected uses `negative` (red). */
export function playerVerificationStatusTone(status: PlayerVerificationStatus): PillTone {
  switch (status) {
    case 'pending':
      return 'warning'
    case 'verified':
      return 'info'
    case 'approved':
      return 'positive'
    case 'rejected':
      return 'negative'
  }
}
