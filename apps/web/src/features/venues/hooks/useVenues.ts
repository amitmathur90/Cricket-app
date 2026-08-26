import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { venuesApi } from '../api/venuesApi'

export function useVenues() {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['venues', organizationId],
    queryFn: () => venuesApi.list(organizationId!),
    enabled: !!organizationId,
  })
}

export function useVenue(venueId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['venues', organizationId, venueId],
    queryFn: () => venuesApi.get(organizationId!, venueId!),
    enabled: !!organizationId && !!venueId,
  })
}
