import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { venuesApi } from '../api/venuesApi'
import type { UpdateVenuePayload } from '../../../types/venue'

export function useUpdateVenue() {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ venueId, payload }: { venueId: string; payload: UpdateVenuePayload }) =>
      venuesApi.update(organizationId!, venueId, payload),
    onSuccess: (updated) => {
      queryClient.invalidateQueries({ queryKey: ['venues', organizationId] })
      queryClient.setQueryData(['venues', organizationId, updated.id], updated)
    },
  })
}
