import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { matchOptionsApi } from '../api/matchOptionsApi'
import type { OfficialRole } from '../../../types/match'

/** A tournament's registered teams, for the match form's home/away pickers.
 * See matchOptionsApi.listTournamentTeams for why this reads the public
 * teams endpoint rather than an authenticated one. */
export function useTournamentTeamOptions(tournamentId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['matches', 'tournament-team-options', organizationId, tournamentId],
    queryFn: () => matchOptionsApi.listTournamentTeams(organizationId!, tournamentId!),
    enabled: !!organizationId && !!tournamentId,
  })
}

export function useVenueOptions() {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['matches', 'venue-options', organizationId],
    queryFn: () => matchOptionsApi.listVenues(organizationId!),
    enabled: !!organizationId,
  })
}

export function useOfficialOptions(role: OfficialRole) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['matches', 'official-options', organizationId, role],
    queryFn: () => matchOptionsApi.listOfficials(organizationId!, role),
    enabled: !!organizationId,
  })
}
