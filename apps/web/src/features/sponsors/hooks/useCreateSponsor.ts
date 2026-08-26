import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { sponsorsApi } from '../api/sponsorsApi'
import type { CreateSponsorPayload } from '../../../types/sponsor'

export function useCreateSponsor() {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: CreateSponsorPayload) => sponsorsApi.create(organizationId!, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['sponsors', organizationId] })
    },
  })
}
