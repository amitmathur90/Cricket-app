import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { venuesApi } from '../api/venuesApi'
import type { CreateVenuePayload } from '../../../types/venue'

export function useCreateVenue() {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: CreateVenuePayload) => venuesApi.create(organizationId!, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['venues', organizationId] })
    },
  })
}
