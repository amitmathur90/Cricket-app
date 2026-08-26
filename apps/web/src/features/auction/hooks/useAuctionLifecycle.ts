import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { auctionApi, type AuctionLifecycleAction } from '../api/auctionApi'

/**
 * One mutation hook per admin lifecycle action on an auction session
 * (start/pause/resume/mark-sold/mark-unsold/next-lot/undo-last-bid). All
 * seven POST with just the session id and return the updated
 * AuctionSession, so they share one generic factory here rather than seven
 * near-duplicate hook bodies.
 *
 * All seven also share the same invalidation — the REST session list/detail
 * queries, so any REST-only view of the session (e.g. the sessions list's
 * status pill) catches up. The *live room's* own UI does NOT depend on this
 * invalidation: every one of these seven actions also triggers a broadcast
 * on the `/auction` socket room (see auction-realtime.service.ts), and
 * useAuctionSocket is what actually drives the live room's state — this
 * invalidation is a secondary, REST-only consistency measure.
 */
function useLifecycleAction(tournamentId: string | undefined, sessionId: string | undefined, action: AuctionLifecycleAction) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: () => action(organizationId!, tournamentId!, sessionId!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['auction-sessions', organizationId, tournamentId] })
    },
  })
}

export function useStartAuction(tournamentId: string | undefined, sessionId: string | undefined) {
  return useLifecycleAction(tournamentId, sessionId, auctionApi.start)
}

export function usePauseAuction(tournamentId: string | undefined, sessionId: string | undefined) {
  return useLifecycleAction(tournamentId, sessionId, auctionApi.pause)
}

export function useResumeAuction(tournamentId: string | undefined, sessionId: string | undefined) {
  return useLifecycleAction(tournamentId, sessionId, auctionApi.resume)
}

export function useMarkSold(tournamentId: string | undefined, sessionId: string | undefined) {
  return useLifecycleAction(tournamentId, sessionId, auctionApi.markSold)
}

export function useMarkUnsold(tournamentId: string | undefined, sessionId: string | undefined) {
  return useLifecycleAction(tournamentId, sessionId, auctionApi.markUnsold)
}

export function useNextLot(tournamentId: string | undefined, sessionId: string | undefined) {
  return useLifecycleAction(tournamentId, sessionId, auctionApi.nextLot)
}

export function useUndoLastBid(tournamentId: string | undefined, sessionId: string | undefined) {
  return useLifecycleAction(tournamentId, sessionId, auctionApi.undoLastBid)
}
