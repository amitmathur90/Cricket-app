import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { sponsorsApi } from '../api/sponsorsApi'

export function useDeleteSponsor() {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (sponsorId: string) => sponsorsApi.remove(organizationId!, sponsorId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['sponsors', organizationId] })
    },
  })
}
