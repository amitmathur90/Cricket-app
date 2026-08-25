import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { matchesApi } from '../api/matchesApi'
import type { CreateMatchPayload } from '../../../types/match'

export function useCreateMatch(tournamentId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: CreateMatchPayload) => matchesApi.create(organizationId!, tournamentId!, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['matches', organizationId, tournamentId] })
    },
  })
}
