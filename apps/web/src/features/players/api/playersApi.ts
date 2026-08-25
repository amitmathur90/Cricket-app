import { apiClient } from '../../../core/api/client'
import type {
  AddToRosterPayload,
  CreatePlayerPayload,
  Player,
  PlayerStatistics,
  RatePlayerPayload,
  UpdatePlayerPayload,
  VerifyPlayerPayload,
} from '../../../types/player'
import type { RosterEntry } from '../../../types/team'

/** Wraps apps/backend/src/modules/players (PlayersController) — org-level
 * player CRUD under `/organizations/:organizationId/players`. Players are
 * org-level profiles, not tournament-scoped — there is no "players in this
 * tournament" listing endpoint; see PlayersTab's doc comment. */
export const playersApi = {
  async list(organizationId: string): Promise<Player[]> {
    const { data } = await apiClient.get<Player[]>(`/organizations/${organizationId}/players`)
    return data
  },

  async get(organizationId: string, playerId: string): Promise<Player> {
    const { data } = await apiClient.get<Player>(`/organizations/${organizationId}/players/${playerId}`)
    return data
  },

  async create(organizationId: string, payload: CreatePlayerPayload): Promise<Player> {
    const { data } = await apiClient.post<Player>(`/organizations/${organizationId}/players`, payload)
    return data
  },

  async update(organizationId: string, playerId: string, payload: UpdatePlayerPayload): Promise<Player> {
    const { data } = await apiClient.patch<Player>(`/organizations/${organizationId}/players/${playerId}`, payload)
    return data
  },

  async remove(organizationId: string, playerId: string): Promise<void> {
    await apiClient.delete(`/organizations/${organizationId}/players/${playerId}`)
  },

  /** Moves a player through the 4-stage verification flow — see
   * ALLOWED_VERIFICATION_TRANSITIONS in types/player.ts for the legal
   * transitions this must respect. */
  async setVerification(organizationId: string, playerId: string, payload: VerifyPlayerPayload): Promise<Player> {
    const { data } = await apiClient.patch<Player>(
      `/organizations/${organizationId}/players/${playerId}/verification`,
      payload,
    )
    return data
  },

  async setRating(organizationId: string, playerId: string, payload: RatePlayerPayload): Promise<Player> {
    const { data } = await apiClient.patch<Player>(`/organizations/${organizationId}/players/${playerId}/rating`, payload)
    return data
  },

  /** Career/cross-match statistics, computed on read — see PlayerStatistics doc in types/player.ts. */
  async getStatistics(organizationId: string, playerId: string): Promise<PlayerStatistics> {
    const { data } = await apiClient.get<PlayerStatistics>(
      `/organizations/${organizationId}/players/${playerId}/statistics`,
    )
    return data
  },

  /** Adds a player to a tournament-team's roster (creates the team_players
   * row). Scoped by `tournamentTeamId`, NOT `teamId`+`tournamentId` like the
   * rest of the roster endpoints on TeamsController — see
   * useTournamentTeamId's doc comment in features/teams for how the web app
   * resolves that id. */
  async addToRoster(
    organizationId: string,
    playerId: string,
    tournamentTeamId: string,
    payload: AddToRosterPayload,
  ): Promise<RosterEntry> {
    const { data } = await apiClient.post<RosterEntry>(
      `/organizations/${organizationId}/players/${playerId}/tournament-teams/${tournamentTeamId}/roster`,
      payload,
    )
    return data
  },
}
