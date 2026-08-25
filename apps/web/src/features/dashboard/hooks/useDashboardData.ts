import { useQueries } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { useTournaments } from '../../tournaments/hooks/useTournaments'
import { usePointsTable } from '../../tournaments/hooks/usePointsTable'
import { useAwards } from '../../tournaments/hooks/useAwards'
import { usePlayers } from '../../players/hooks/usePlayers'
import { matchesApi } from '../../matches/api/matchesApi'
import type { Tournament } from '../../../types/tournament'
import type { Match } from '../../../types/match'

/** live → soonest upcoming → latest (by startDate) → first. Mirrors
 * apps/mobile/lib/features/tournaments/presentation/widgets/dashboard_overview.dart's
 * `_primaryTournament` heuristic exactly — Points Table/Awards are
 * tournament-scoped but the dashboard itself is org-wide, so one
 * representative tournament has to be picked to drive those two sections. */
function pickPrimaryTournament(tournaments: Tournament[]): Tournament | null {
  if (tournaments.length === 0) return null

  const live = tournaments.find((t) => t.status === 'live')
  if (live) return live

  const upcoming = tournaments
    .filter((t) => t.status === 'upcoming')
    .sort((a, b) => a.startDate.localeCompare(b.startDate))
  if (upcoming.length > 0) return upcoming[0]

  const byLatestStart = [...tournaments].sort((a, b) => b.startDate.localeCompare(a.startDate))
  return byLatestStart[0] ?? tournaments[0]
}

export function useDashboardData() {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const { data: tournaments, isLoading: tournamentsLoading } = useTournaments()
  const { data: players, isLoading: playersLoading } = usePlayers()

  // Fan out matches across every tournament for the org-wide Live/Upcoming
  // sections and the Matches stat count — mirrors dashboard_overview.dart's
  // `_orgMatchesProvider` fan-out. Each tournament's matches are fetched
  // once and cached under the same query key MatchesTab/MatchListPage use,
  // so navigating into a tournament afterward is instant.
  const matchQueries = useQueries({
    queries: (tournaments ?? []).map((t) => ({
      queryKey: ['matches', organizationId, t.id, 'all'],
      queryFn: () => matchesApi.list(organizationId!, t.id),
      enabled: !!organizationId,
    })),
  })
  const matchesLoading = matchQueries.some((q) => q.isLoading)
  const allMatches: Match[] = matchQueries.flatMap((q) => q.data ?? [])

  const primaryTournament = pickPrimaryTournament(tournaments ?? [])
  const { data: pointsTable, isLoading: pointsTableLoading } = usePointsTable(primaryTournament?.id)
  const { data: awards, isLoading: awardsLoading } = useAwards(primaryTournament?.id)

  const liveMatches = allMatches.filter((m) => m.status === 'live')
  const upcomingMatches = allMatches
    .filter((m) => m.status === 'scheduled' && m.scheduledAt)
    .sort((a, b) => a.scheduledAt!.localeCompare(b.scheduledAt!))
    .slice(0, 5)

  return {
    isLoading: tournamentsLoading || playersLoading,
    tournaments: tournaments ?? [],
    teamsCount: (tournaments ?? []).reduce((sum, t) => sum + t.teamsCount, 0),
    playersCount: (players ?? []).length,
    matchesCount: allMatches.length,
    matchesLoading,
    liveMatches,
    upcomingMatches,
    primaryTournament,
    pointsTable: pointsTable ?? [],
    pointsTableLoading,
    awards,
    awardsLoading,
  }
}
