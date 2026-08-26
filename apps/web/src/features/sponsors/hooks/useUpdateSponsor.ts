import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { sponsorsApi } from '../api/sponsorsApi'
import type { UpdateSponsorPayload } from '../../../types/sponsor'

export function useUpdateSponsor() {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ sponsorId, payload }: { sponsorId: string; payload: UpdateSponsorPayload }) =>
      sponsorsApi.update(organizationId!, sponsorId, payload),
    onSuccess: (updated) => {
      queryClient.invalidateQueries({ queryKey: ['sponsors', organizationId] })
      queryClient.setQueryData(['sponsors', organizationId, updated.id], updated)
    },
  })
}
