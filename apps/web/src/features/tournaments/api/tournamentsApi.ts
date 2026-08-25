import { apiClient } from '../../../core/api/client'
import type {
  CreateTournamentPayload,
  PointsTableRow,
  Tournament,
  TournamentAwardsResponse,
  UpdateTournamentPayload,
} from '../../../types/tournament'

export const tournamentsApi = {
  async list(organizationId: string): Promise<Tournament[]> {
    const { data } = await apiClient.get<Tournament[]>(`/organizations/${organizationId}/tournaments`)
    return data
  },

  async get(organizationId: string, tournamentId: string): Promise<Tournament> {
    const { data } = await apiClient.get<Tournament>(
      `/organizations/${organizationId}/tournaments/${tournamentId}`,
    )
    return data
  },

  async create(organizationId: string, payload: CreateTournamentPayload): Promise<Tournament> {
    const { data } = await apiClient.post<Tournament>(
      `/organizations/${organizationId}/tournaments`,
      payload,
    )
    return data
  },

  async update(
    organizationId: string,
    tournamentId: string,
    payload: UpdateTournamentPayload,
  ): Promise<Tournament> {
    const { data } = await apiClient.patch<Tournament>(
      `/organizations/${organizationId}/tournaments/${tournamentId}`,
      payload,
    )
    return data
  },

  async pointsTable(organizationId: string, tournamentId: string): Promise<PointsTableRow[]> {
    const { data } = await apiClient.get<PointsTableRow[]>(
      `/organizations/${organizationId}/tournaments/${tournamentId}/points-table`,
    )
    return data
  },

  async awards(organizationId: string, tournamentId: string): Promise<TournamentAwardsResponse> {
    const { data } = await apiClient.get<TournamentAwardsResponse>(
      `/organizations/${organizationId}/tournaments/${tournamentId}/awards`,
    )
    return data
  },
}
