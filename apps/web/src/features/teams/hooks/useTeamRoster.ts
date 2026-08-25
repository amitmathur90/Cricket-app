import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import axios from 'axios'
import { useAuthStore } from '../../../core/auth/authStore'
import { teamsApi } from '../api/teamsApi'
import { tournamentsApi } from '../../tournaments/api/tournamentsApi'
import type { RegisterTeamToTournamentPayload, RosterEntry, Team, UpdateRosterEntryPayload } from '../../../types/team'

export interface TeamTournamentRoster {
  registered: boolean
  roster: RosterEntry[]
}

function rosterQueryKey(organizationId: string | null, teamId: string | undefined, tournamentId: string | undefined) {
  return ['teams', organizationId, teamId, 'tournaments', tournamentId, 'roster']
}

/**
 * A team's roster (squad) — and, implicitly, its registration status — for
 * one specific tournament. There is no dedicated "is this team registered
 * in this tournament" GET on the backend: `TeamsService.getRoster` 404s
 * with "Team is not registered in this tournament" when it isn't, so that
 * 404 IS the registration signal used here, rather than a second lookup.
 * This keeps team+registration status to one request per team, mirroring
 * apps/mobile's TeamListTab, which documents the identical "org-level list
 * only, no tournament-scoped filter endpoint exists" gap.
 */
export function useTeamTournamentRoster(teamId: string | undefined, tournamentId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery<TeamTournamentRoster>({
    queryKey: rosterQueryKey(organizationId, teamId, tournamentId),
    queryFn: async () => {
      try {
        const roster = await teamsApi.getRoster(organizationId!, teamId!, tournamentId!)
        return { registered: true, roster }
      } catch (error) {
        if (axios.isAxiosError(error) && error.response?.status === 404) {
          return { registered: false, roster: [] }
        }
        throw error
      }
    },
    enabled: !!organizationId && !!teamId && !!tournamentId,
  })
}

export function useRegisterTeamToTournament(teamId: string | undefined, tournamentId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: RegisterTeamToTournamentPayload) =>
      teamsApi.registerToTournament(organizationId!, teamId!, tournamentId!, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: rosterQueryKey(organizationId, teamId, tournamentId) })
      // Also refresh the tournament's own teamsCount (computed by TournamentsService.toResponse).
      queryClient.invalidateQueries({ queryKey: ['tournaments', organizationId, tournamentId] })
    },
  })
}

export function useUpdateRosterEntry(teamId: string | undefined, tournamentId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ teamPlayerId, payload }: { teamPlayerId: string; payload: UpdateRosterEntryPayload }) =>
      teamsApi.updateRosterEntry(organizationId!, teamId!, tournamentId!, teamPlayerId, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: rosterQueryKey(organizationId, teamId, tournamentId) })
    },
  })
}

/**
 * Resolves this team's `tournament_teams.id` (tournamentTeamId) for one
 * tournament. Needed only by `PlayersController.addToRoster`, which —
 * inconsistently with the rest of the roster endpoints on
 * `TeamsController` — is scoped by `tournamentTeamId` rather than
 * `teamId`+`tournamentId`. There is no direct `teamId -> tournamentTeamId`
 * lookup exposed by the backend: this is the exact same gap
 * apps/mobile/lib/features/teams/presentation/widgets/team_auction_tab.dart
 * and team_matches_tab.dart already hit and document, worked around there
 * (and here) by matching team *name* against an endpoint that already
 * resolves it server-side — `TournamentsService.getPointsTable` returns one
 * row per registered TournamentTeam (with `tournamentTeamId` + `teamName`),
 * always, even before any match has been played. This is a real backend
 * limitation, not a design choice — call this out rather than hide it.
 */
export function useTournamentTeamId(team: Team | undefined, tournamentId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['tournaments', organizationId, tournamentId, 'points-table', 'team-lookup', team?.id],
    queryFn: async () => {
      const rows = await tournamentsApi.pointsTable(organizationId!, tournamentId!)
      const match = rows.find((row) => row.teamName.trim().toLowerCase() === team!.name.trim().toLowerCase())
      return match?.tournamentTeamId ?? null
    },
    enabled: !!organizationId && !!tournamentId && !!team,
  })
}
