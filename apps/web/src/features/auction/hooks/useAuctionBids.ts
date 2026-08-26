import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { auctionApi } from '../api/auctionApi'

/** Full bid history for a session (optionally filtered to one player).
 * useAuctionSocket invalidates the `['auction-bids', organizationId,
 * sessionId]` prefix on every bidPlaced/bidUndone/playerSold/playerUnsold
 * broadcast, so this refetches automatically as the live auction proceeds
 * rather than needing its own socket listeners. */
export function useAuctionBids(tournamentId: string | undefined, sessionId: string | undefined, playerId?: string) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['auction-bids', organizationId, sessionId, playerId ?? 'all'],
    queryFn: () => auctionApi.listBids(organizationId!, tournamentId!, sessionId!, playerId),
    enabled: !!organizationId && !!tournamentId && !!sessionId,
  })
}
