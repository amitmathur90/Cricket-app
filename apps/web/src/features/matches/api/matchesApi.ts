import { apiClient } from '../../../core/api/client'
import type { CreateMatchPayload, Match, MatchListFilters, UpdateMatchPayload } from '../../../types/match'

function buildQuery(filters?: MatchListFilters): string {
  if (!filters) return ''
  const params = new URLSearchParams()
  if (filters.status) params.set('status', filters.status)
  if (filters.from) params.set('from', filters.from)
  if (filters.to) params.set('to', filters.to)
  const query = params.toString()
  return query ? `?${query}` : ''
}

export const matchesApi = {
  async list(organizationId: string, tournamentId: string, filters?: MatchListFilters): Promise<Match[]> {
    const { data } = await apiClient.get<Match[]>(
      `/organizations/${organizationId}/tournaments/${tournamentId}/matches${buildQuery(filters)}`,
    )
    return data
  },

  async get(organizationId: string, tournamentId: string, matchId: string): Promise<Match> {
    const { data } = await apiClient.get<Match>(
      `/organizations/${organizationId}/tournaments/${tournamentId}/matches/${matchId}`,
    )
    return data
  },

  async create(organizationId: string, tournamentId: string, payload: CreateMatchPayload): Promise<Match> {
    const { data } = await apiClient.post<Match>(
      `/organizations/${organizationId}/tournaments/${tournamentId}/matches`,
      payload,
    )
    return data
  },

  async update(
    organizationId: string,
    tournamentId: string,
    matchId: string,
    payload: UpdateMatchPayload,
  ): Promise<Match> {
    const { data } = await apiClient.patch<Match>(
      `/organizations/${organizationId}/tournaments/${tournamentId}/matches/${matchId}`,
      payload,
    )
    return data
  },
}
