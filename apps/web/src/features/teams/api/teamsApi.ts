import { apiClient } from '../../../core/api/client'
import type {
  CreateTeamPayload,
  RegisterTeamToTournamentPayload,
  RosterEntry,
  Team,
  TournamentTeam,
  UpdateRosterEntryPayload,
} from '../../../types/team'

/** Wraps apps/backend/src/modules/teams (TeamsController) — org-level team
 * CRUD under `/organizations/:organizationId/teams`, plus a team's
 * per-tournament registration and roster (squad). There is no endpoint that
 * lists every TournamentTeam for a given tournament with team details
 * joined — only `list` (all org teams) and roster lookups scoped by a
 * specific `teamId` + `tournamentId` pair. See TeamsTab's doc comment for
 * how that gap is worked around client-side. */
export const teamsApi = {
  async list(organizationId: string): Promise<Team[]> {
    const { data } = await apiClient.get<Team[]>(`/organizations/${organizationId}/teams`)
    return data
  },

  async get(organizationId: string, teamId: string): Promise<Team> {
    const { data } = await apiClient.get<Team>(`/organizations/${organizationId}/teams/${teamId}`)
    return data
  },

  async create(organizationId: string, payload: CreateTeamPayload): Promise<Team> {
    const { data } = await apiClient.post<Team>(`/organizations/${organizationId}/teams`, payload)
    return data
  },

  async remove(organizationId: string, teamId: string): Promise<void> {
    await apiClient.delete(`/organizations/${organizationId}/teams/${teamId}`)
  },

  /** Registers an org-level team into a specific tournament (creates the tournament_teams row). */
  async registerToTournament(
    organizationId: string,
    teamId: string,
    tournamentId: string,
    payload: RegisterTeamToTournamentPayload,
  ): Promise<TournamentTeam> {
    const { data } = await apiClient.post<TournamentTeam>(
      `/organizations/${organizationId}/teams/${teamId}/tournaments/${tournamentId}/register`,
      payload,
    )
    return data
  },

  /** Lists a team's roster (squad) for a specific tournament, captain-first.
   * 404s ("Team is not registered in this tournament") when the team hasn't
   * been registered for `tournamentId` — callers use that as the
   * registration signal, see useTeamTournamentRoster. */
  async getRoster(organizationId: string, teamId: string, tournamentId: string): Promise<RosterEntry[]> {
    const { data } = await apiClient.get<RosterEntry[]>(
      `/organizations/${organizationId}/teams/${teamId}/tournaments/${tournamentId}/roster`,
    )
    return data
  },

  /** Updates one roster entry's captain/vice-captain/jersey/wicketkeeper
   * fields. Setting isCaptain/isViceCaptain true atomically unsets it on
   * every other roster entry for the same tournament-team server-side. */
  async updateRosterEntry(
    organizationId: string,
    teamId: string,
    tournamentId: string,
    teamPlayerId: string,
    payload: UpdateRosterEntryPayload,
  ): Promise<RosterEntry> {
    const { data } = await apiClient.patch<RosterEntry>(
      `/organizations/${organizationId}/teams/${teamId}/tournaments/${tournamentId}/roster/${teamPlayerId}`,
      payload,
    )
    return data
  },
}
