import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { playersApi } from '../api/playersApi'
import type { AddToRosterPayload } from '../../../types/player'

/** Adds a player to a resolved `tournamentTeamId`'s roster — see
 * `useTournamentTeamId` (features/teams/hooks/useTeamRoster.ts) for how that
 * id is resolved from a team+tournament pair. Broadly invalidates every
 * `['teams', organizationId, ...]` roster query on success (the exact
 * teamId this roster belongs to isn't known here, only the
 * tournamentTeamId it was posted to) — same "invalidate the whole family"
 * approach used by useReviewApplication. */
export function useAddToRoster(tournamentTeamId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ playerId, payload }: { playerId: string; payload: AddToRosterPayload }) =>
      playersApi.addToRoster(organizationId!, playerId, tournamentTeamId!, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['teams', organizationId] })
    },
  })
}
