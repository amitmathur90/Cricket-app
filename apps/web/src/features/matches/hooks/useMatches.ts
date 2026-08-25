import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { matchesApi } from '../api/matchesApi'
import type { MatchListFilters } from '../../../types/match'

/** Lists a tournament's matches. `filters` is intentionally left undefined
 * by MatchesTab/MatchListPage — they fetch every match once and filter
 * client-side (Upcoming/Past/All + the week-strip date), same as the mobile
 * MatchesTab's `matchesListProvider(... filter: null)` — but the param is
 * still exposed here since the backend supports server-side status/date
 * filtering, for any caller that wants a narrower fetch. */
export function useMatches(tournamentId: string | undefined, filters?: MatchListFilters) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['matches', organizationId, tournamentId, filters ?? 'all'],
    queryFn: () => matchesApi.list(organizationId!, tournamentId!, filters),
    enabled: !!organizationId && !!tournamentId,
  })
}

export function useMatch(tournamentId: string | undefined, matchId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['matches', organizationId, tournamentId, matchId],
    queryFn: () => matchesApi.get(organizationId!, tournamentId!, matchId!),
    enabled: !!organizationId && !!tournamentId && !!matchId,
  })
}
