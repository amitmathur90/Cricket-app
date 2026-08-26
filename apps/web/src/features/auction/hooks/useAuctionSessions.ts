import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { auctionApi } from '../api/auctionApi'

export function useAuctionSessions(tournamentId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['auction-sessions', organizationId, tournamentId],
    queryFn: () => auctionApi.list(organizationId!, tournamentId!),
    enabled: !!organizationId && !!tournamentId,
  })
}

export function useAuctionSession(tournamentId: string | undefined, sessionId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['auction-sessions', organizationId, tournamentId, sessionId],
    queryFn: () => auctionApi.get(organizationId!, tournamentId!, sessionId!),
    enabled: !!organizationId && !!tournamentId && !!sessionId,
    // A live session's status/current-lot fields go stale within seconds
    // once bidding starts — the live room reads them from the socket-driven
    // cache (see useAuctionSocket), not this REST query, but a short
    // staleTime keeps this one (used for the header/fallback name+status)
    // reasonably fresh too without hammering the endpoint.
    staleTime: 10_000,
  })
}
