import type { PillTone } from '../../shared/components/StatusPill'
import type { VenueDayStatus, VenueStatus } from '../../types/venue'

export function venueStatusTone(status: VenueStatus): PillTone {
  return status === 'active' ? 'positive' : 'neutral'
}

/** Mirrors venue_availability_screen.dart's _StatusChip color mapping
 * (available -> green/positive, booked -> error/negative, maintenance ->
 * orange/warning). */
export function venueDayStatusTone(status: VenueDayStatus): PillTone {
  switch (status) {
    case 'available':
      return 'positive'
    case 'booked':
      return 'negative'
    case 'maintenance':
      return 'warning'
  }
}
