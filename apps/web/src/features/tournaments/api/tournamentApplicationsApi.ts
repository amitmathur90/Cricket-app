import { apiClient } from '../../../core/api/client'
import type {
  ReviewApplicationPayload,
  TournamentApplication,
  TournamentApplicationStatus,
} from '../../../types/tournament'

/** Wraps apps/backend/src/modules/tournament-applications — the admin
 * review side only (list-for-tournament + review). The self-service "apply"
 * endpoint belongs to the (not-yet-built) player-facing side of this
 * feature, not this admin dashboard. */
export const tournamentApplicationsApi = {
  async listForTournament(
    organizationId: string,
    tournamentId: string,
    status?: TournamentApplicationStatus,
  ): Promise<TournamentApplication[]> {
    const { data } = await apiClient.get<TournamentApplication[]>(
      `/organizations/${organizationId}/tournaments/${tournamentId}/applications`,
      { params: status ? { status } : undefined },
    )
    return data
  },

  async review(
    organizationId: string,
    tournamentId: string,
    applicationId: string,
    payload: ReviewApplicationPayload,
  ): Promise<TournamentApplication> {
    const { data } = await apiClient.patch<TournamentApplication>(
      `/organizations/${organizationId}/tournaments/${tournamentId}/applications/${applicationId}/review`,
      payload,
    )
    return data
  },
}
