import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { venuesApi } from '../api/venuesApi'

/** Day-by-day availability calendar for `[from, to]` (inclusive ISO dates,
 * YYYY-MM-DD) — backs the calendar section of VenueDetailPage. */
export function useVenueAvailability(venueId: string | undefined, from: string, to: string) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['venues', organizationId, venueId, 'availability', from, to],
    queryFn: () => venuesApi.getAvailability(organizationId!, venueId!, from, to),
    enabled: !!organizationId && !!venueId && !!from && !!to,
  })
}
