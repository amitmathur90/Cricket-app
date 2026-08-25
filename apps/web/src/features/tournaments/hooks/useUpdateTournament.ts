import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { tournamentsApi } from '../api/tournamentsApi'
import type { UpdateTournamentPayload } from '../../../types/tournament'

/** Used both for editing tournament fields and for the create wizard's
 * "Publish" step (a PATCH setting status: 'upcoming' right after the
 * initial POST) — same two-call shape as the mobile wizard's `_submit`. */
export function useUpdateTournament() {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ tournamentId, payload }: { tournamentId: string; payload: UpdateTournamentPayload }) =>
      tournamentsApi.update(organizationId!, tournamentId, payload),
    onSuccess: (updated) => {
      queryClient.invalidateQueries({ queryKey: ['tournaments', organizationId] })
      queryClient.setQueryData(['tournaments', organizationId, updated.id], updated)
    },
  })
}
