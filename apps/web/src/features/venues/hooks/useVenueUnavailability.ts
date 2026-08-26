import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { venuesApi } from '../api/venuesApi'
import type { CreateVenueUnavailabilityPayload } from '../../../types/venue'

/** Raw list of a venue's unavailability ("Maintenance") records — distinct
 * from the derived day-by-day calendar (useVenueAvailability), this is what
 * lets the admin see and remove individual records by id. */
export function useVenueUnavailability(venueId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['venues', organizationId, venueId, 'unavailability'],
    queryFn: () => venuesApi.listUnavailability(organizationId!, venueId!),
    enabled: !!organizationId && !!venueId,
  })
}

/** Invalidates both the raw unavailability list and every cached
 * availability-calendar range for this venue, since a new/removed
 * unavailability record changes what the calendar would show. */
function invalidateVenueAvailability(
  queryClient: ReturnType<typeof useQueryClient>,
  organizationId: string | null,
  venueId: string,
) {
  queryClient.invalidateQueries({ queryKey: ['venues', organizationId, venueId, 'unavailability'] })
  queryClient.invalidateQueries({ queryKey: ['venues', organizationId, venueId, 'availability'] })
}

export function useAddVenueUnavailability(venueId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: CreateVenueUnavailabilityPayload) =>
      venuesApi.addUnavailability(organizationId!, venueId!, payload),
    onSuccess: () => {
      if (venueId) invalidateVenueAvailability(queryClient, organizationId, venueId)
    },
  })
}

export function useRemoveVenueUnavailability(venueId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (unavailabilityId: string) => venuesApi.removeUnavailability(organizationId!, venueId!, unavailabilityId),
    onSuccess: () => {
      if (venueId) invalidateVenueAvailability(queryClient, organizationId, venueId)
    },
  })
}
