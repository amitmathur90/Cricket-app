import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { matchesApi } from '../api/matchesApi'
import type { UpdateMatchPayload } from '../../../types/match'

/** Covers every distinct admin action the backend's single PATCH endpoint
 * handles — assign teams/venue/umpire/scorer, reschedule, and status
 * transitions including the soft "Cancel match" action
 * (`{ status: 'cancelled' }`) — same one-mutation-hook shape as
 * useUpdateTournament. */
export function useUpdateMatch(tournamentId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ matchId, payload }: { matchId: string; payload: UpdateMatchPayload }) =>
      matchesApi.update(organizationId!, tournamentId!, matchId, payload),
    onSuccess: (updated) => {
      queryClient.invalidateQueries({ queryKey: ['matches', organizationId, tournamentId] })
      queryClient.setQueryData(['matches', organizationId, tournamentId, updated.id], updated)
    },
  })
}
