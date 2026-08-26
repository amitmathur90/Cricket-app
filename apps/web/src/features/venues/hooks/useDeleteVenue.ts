import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { venuesApi } from '../api/venuesApi'

export function useDeleteVenue() {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (venueId: string) => venuesApi.remove(organizationId!, venueId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['venues', organizationId] })
    },
  })
}
