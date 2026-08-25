import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { tournamentApplicationsApi } from '../api/tournamentApplicationsApi'
import type { ReviewApplicationPayload, TournamentApplicationStatus } from '../../../types/tournament'

export function useApplications(tournamentId: string | undefined, status?: TournamentApplicationStatus) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['tournaments', organizationId, tournamentId, 'applications', status ?? 'all'],
    queryFn: () => tournamentApplicationsApi.listForTournament(organizationId!, tournamentId!, status),
    enabled: !!organizationId && !!tournamentId,
  })
}

/** Approve/reject one application. Invalidates every status-filter variant
 * of this tournament's applications list (query key prefix match), same
 * "invalidate the whole family" approach as the mobile repository. */
export function useReviewApplication(tournamentId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ applicationId, payload }: { applicationId: string; payload: ReviewApplicationPayload }) =>
      tournamentApplicationsApi.review(organizationId!, tournamentId!, applicationId, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: ['tournaments', organizationId, tournamentId, 'applications'],
      })
    },
  })
}
