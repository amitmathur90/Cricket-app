import type { PillTone } from '../../shared/components/StatusPill'
import type { RegistrationStatus, TournamentApplicationStatus, TournamentStatus } from '../../types/tournament'

/** Judgment call: apps/mobile's _TournamentTile._statusColors maps
 * draft/upcoming/live/completed to grey/blue/green/blueGrey. This app's
 * shared token set already defines a `live` tone specifically for
 * "currently live" indicators (see StatusPill), so `live` status uses that
 * dedicated token here instead of green — everything else follows the same
 * light/dark-neutral vs. blue shape as mobile. */
export function tournamentStatusTone(status: TournamentStatus): PillTone {
  switch (status) {
    case 'draft':
      return 'neutral'
    case 'upcoming':
      return 'info'
    case 'live':
      return 'live'
    case 'completed':
      return 'navy'
  }
}

export const TOURNAMENT_STATUS_LABELS: Record<TournamentStatus, string> = {
  draft: 'Draft',
  upcoming: 'Upcoming',
  live: 'Live',
  completed: 'Completed',
}

/** Mirrors _TournamentTile._registrationColor (grey/green/red). */
export function registrationStatusTone(status: RegistrationStatus): PillTone {
  switch (status) {
    case 'not_open':
      return 'neutral'
    case 'open':
      return 'positive'
    case 'closed':
      return 'negative'
  }
}

/** Mirrors ApplicationsReviewTab's _StatusChip (orange/green/red). */
export function applicationStatusTone(status: TournamentApplicationStatus): PillTone {
  switch (status) {
    case 'pending':
      return 'warning'
    case 'approved':
      return 'positive'
    case 'rejected':
      return 'negative'
  }
}
