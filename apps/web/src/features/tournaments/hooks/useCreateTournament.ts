import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { tournamentsApi } from '../api/tournamentsApi'
import type { CreateTournamentPayload } from '../../../types/tournament'

export function useCreateTournament() {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: CreateTournamentPayload) => tournamentsApi.create(organizationId!, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tournaments', organizationId] })
    },
  })
}
