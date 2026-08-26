import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { auctionApi } from '../api/auctionApi'

/** Full bid history for a session (optionally filtered to one player).
 * useAuctionSocket invalidates the `['auction-bids', organizationId,
 * sessionId]` prefix on every bidPlaced/bidUndone/playerSold/playerUnsold
 * broadcast, so this refetches automatically as the live auction proceeds
 * rather than needing its own socket listeners.
 *
 * The bids endpoint is admin-gated server-side (ORG_ADMIN/TOURNAMENT_ADMIN
 * only — see auction.controller.ts) — a caller rendering bid history for a
 * non-admin viewer should pass `options.enabled: false` rather than let this
 * fire and 403, so it can show a clean "admins only" message instead of an
 * unhandled network-error state. Defaults to enabled so every existing call
 * site (which only ever runs for tournament_admin+ contexts) is unaffected. */
export function useAuctionBids(
  tournamentId: string | undefined,
  sessionId: string | undefined,
  playerId?: string,
  options?: { enabled?: boolean },
) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['auction-bids', organizationId, sessionId, playerId ?? 'all'],
    queryFn: () => auctionApi.listBids(organizationId!, tournamentId!, sessionId!, playerId),
    enabled: (options?.enabled ?? true) && !!organizationId && !!tournamentId && !!sessionId,
  })
}
