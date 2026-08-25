import { apiClient } from '../../../core/api/client'
import type { MatchOfficial, MatchVenue, OfficialRole, TournamentTeamOption } from '../../../types/match'

/**
 * Read-only "picker data" for the match form — a tournament's registered
 * teams (home/away selects) and an organization's venues/officials
 * (structured half of the venue/umpire/scorer/match-referee dual-field
 * approach — see types/match.ts's doc comments). Kept as a small standalone
 * module rather than three separate features: the Teams/Venues/Officials
 * admin screens haven't been built yet, and this only needs enough of each
 * to populate a dropdown, not full CRUD.
 */
export const matchOptionsApi = {
  /** No authenticated endpoint lists a tournament's registered teams — this
   * reuses the public (unauthenticated, but org-scoped by the URL) teams
   * endpoint from public-tournaments.controller.ts instead. */
  async listTournamentTeams(organizationId: string, tournamentId: string): Promise<TournamentTeamOption[]> {
    const { data } = await apiClient.get<TournamentTeamOption[]>(
      `/public/organizations/${organizationId}/tournaments/${tournamentId}/teams`,
    )
    return data
  },

  async listVenues(organizationId: string): Promise<MatchVenue[]> {
    const { data } = await apiClient.get<MatchVenue[]>(`/organizations/${organizationId}/venues`)
    return data
  },

  async listOfficials(organizationId: string, role?: OfficialRole): Promise<MatchOfficial[]> {
    const query = role ? `?role=${role}` : ''
    const { data } = await apiClient.get<MatchOfficial[]>(`/organizations/${organizationId}/officials${query}`)
    return data
  },
}
