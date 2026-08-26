import { useEffect, useRef, useState } from 'react'
import { useQuery, useQueryClient, type QueryKey } from '@tanstack/react-query'
import type { Socket } from 'socket.io-client'
import { useAuthStore } from '../../../core/auth/authStore'
import { createNamespaceSocket } from '../../../core/sockets/socketClient'
import type {
  AuctionBidPlacedEvent,
  AuctionBidUndoneEvent,
  AuctionErrorEvent,
  AuctionPlayerSoldEvent,
  AuctionPlayerUnsoldEvent,
  AuctionPlayerUpEvent,
  AuctionStateSync,
} from '../../../types/auction'

/** The single query key the live auction state lives under — written only
 * by useAuctionSocket's event listeners (via `queryClient.setQueryData`),
 * read by useAuctionLiveState (and by anything else that wants to observe
 * it) via a plain `useQuery({queryKey, enabled: false})` subscription. */
export function auctionLiveStateKey(organizationId: string | null, sessionId: string | undefined): QueryKey {
  return ['auction-live-state', organizationId, sessionId]
}

/** Read-only subscription to the live-state cache entry useAuctionSocket
 * maintains. `enabled: false` because this query is never fetched over
 * REST — there is no endpoint that returns this exact shape (see
 * types/auction.ts's AuctionStateSync doc comment) — its data arrives
 * exclusively via `auction.stateSync` (and the patches applied from the
 * other five broadcast types) over the socket. Safe to call from multiple
 * components at once; they all observe the same cache entry. */
export function useAuctionLiveState(sessionId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  return useQuery<AuctionStateSync>({
    queryKey: auctionLiveStateKey(organizationId, sessionId),
    queryFn: () => Promise.reject(new Error('auction-live-state is populated by the socket only, never fetched directly')),
    enabled: false,
    staleTime: Infinity,
  })
}

interface UseAuctionSocketResult {
  /** True once the socket namespace connection is open (and the initial
   * `auction.join` has been sent) — false before connect and after any
   * disconnect, including mid-session network blips (socket.io
   * auto-reconnects and this flips back true, re-joining, once it does). */
  connected: boolean
  /** The most recent `auction.error` message this socket received (bid
   * rejections — insufficient purse, squad full, stale bid amount, etc.).
   * Cleared on the next successful placeBid call. */
  lastError: string | null
  placeBid: (teamId: string, amount: number) => void
}

/**
 * Owns one Socket.IO connection to the `/auction` namespace for as long as
 * this hook is mounted with a given `sessionId` (opened on mount,
 * disconnected on unmount or sessionId/token change) — joins
 * `auction:{sessionId}`'s room and keeps the TanStack Query cache at
 * `auctionLiveStateKey(...)` as the single source of truth for live
 * auction state, so every component reading that key (via
 * useAuctionLiveState) sees the same live-updated snapshot without a REST
 * refetch. This hook is the cache's only writer.
 *
 * `auction.stateSync` (sent on join — including every reconnect, which is
 * this backend's reconnect-recovery mechanism — plus pause, resume, and
 * session completion) fully replaces the cached snapshot; it's always a
 * complete, authoritative state. The other four broadcast types are
 * partial payloads (see the object literals built inline in
 * auction-realtime.service.ts), so this hook patches just the fields they
 * carry onto the existing cached snapshot:
 *  - playerUp: replaces currentLot with the new unresolved lot (bid reset
 *    to the base price, no leading bidder) and decrements remainingPoolCount.
 *  - bidPlaced / bidUndone: update currentLot's currentBidAmount/
 *    currentBidTeamId.
 *  - playerSold: flips currentLot.resolved and patches the winning team's
 *    purseRemaining from the payload.
 *  - playerUnsold: flips currentLot.resolved only (no purse change).
 * All five of the bid/lot-resolution events also invalidate the
 * `['auction-bids', ...]` REST query so the bid-history panel refetches.
 *
 * Known, documented limitation: a team's `squadFull` flag is only
 * recomputed server-side as part of the *full* stateSync payload — the
 * partial `playerSold` payload carries purseRemaining but not a fresh
 * roster count for every team. So if a sale fills a team's last roster
 * slot, that team's squadFull badge can lag (client-side display only)
 * until the next full stateSync (next pause/resume, reconnect, or fresh
 * page load). The server remains the authoritative check regardless — a
 * subsequent bid from that team is still rejected with "SQUAD FULL" via
 * `auction.error` — so this is a UX staleness window, not a correctness gap.
 */
export function useAuctionSocket(sessionId: string | undefined): UseAuctionSocketResult {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const accessToken = useAuthStore((s) => s.accessToken)
  const queryClient = useQueryClient()
  const [connected, setConnected] = useState(false)
  const [lastError, setLastError] = useState<string | null>(null)
  const socketRef = useRef<Socket | null>(null)

  useEffect(() => {
    if (!sessionId || !accessToken) return

    const socket = createNamespaceSocket('/auction', accessToken)
    socketRef.current = socket
    const queryKey = auctionLiveStateKey(organizationId, sessionId)
    const bidsKey = ['auction-bids', organizationId, sessionId]

    socket.on('connect', () => {
      setConnected(true)
      socket.emit('auction.join', { auctionSessionId: sessionId })
    })

    socket.on('disconnect', () => setConnected(false))

    socket.on('auction.stateSync', (payload: AuctionStateSync) => {
      queryClient.setQueryData(queryKey, payload)
    })

    socket.on('auction.playerUp', (payload: AuctionPlayerUpEvent) => {
      queryClient.setQueryData<AuctionStateSync | undefined>(queryKey, (prev) => {
        if (!prev) return prev
        return {
          ...prev,
          currentLot: {
            poolEntryId: payload.poolEntryId,
            player: payload.player,
            basePrice: payload.basePrice,
            currentBidAmount: payload.basePrice,
            currentBidTeamId: null,
            resolved: false,
          },
          remainingPoolCount: Math.max(0, prev.remainingPoolCount - 1),
        }
      })
    })

    socket.on('auction.bidPlaced', (payload: AuctionBidPlacedEvent) => {
      queryClient.setQueryData<AuctionStateSync | undefined>(queryKey, (prev) => {
        if (!prev || !prev.currentLot) return prev
        return { ...prev, currentLot: { ...prev.currentLot, currentBidAmount: payload.amount, currentBidTeamId: payload.teamId } }
      })
      queryClient.invalidateQueries({ queryKey: bidsKey })
    })

    socket.on('auction.bidUndone', (payload: AuctionBidUndoneEvent) => {
      queryClient.setQueryData<AuctionStateSync | undefined>(queryKey, (prev) => {
        if (!prev || !prev.currentLot) return prev
        return {
          ...prev,
          currentLot: {
            ...prev.currentLot,
            currentBidAmount: payload.currentBidAmount,
            currentBidTeamId: payload.currentBidTeamId,
          },
        }
      })
      queryClient.invalidateQueries({ queryKey: bidsKey })
    })

    socket.on('auction.playerSold', (payload: AuctionPlayerSoldEvent) => {
      queryClient.setQueryData<AuctionStateSync | undefined>(queryKey, (prev) => {
        if (!prev || !prev.currentLot) return prev
        return {
          ...prev,
          currentLot: { ...prev.currentLot, resolved: true },
          teams: prev.teams.map((t) =>
            t.tournamentTeamId === payload.soldToTeamId ? { ...t, purseRemaining: payload.purseRemaining } : t,
          ),
        }
      })
      queryClient.invalidateQueries({ queryKey: bidsKey })
    })

    socket.on('auction.playerUnsold', (_payload: AuctionPlayerUnsoldEvent) => {
      queryClient.setQueryData<AuctionStateSync | undefined>(queryKey, (prev) => {
        if (!prev || !prev.currentLot) return prev
        return { ...prev, currentLot: { ...prev.currentLot, resolved: true } }
      })
    })

    socket.on('auction.error', (payload: AuctionErrorEvent) => {
      setLastError(payload.message)
    })

    return () => {
      socket.disconnect()
      socketRef.current = null
      setConnected(false)
    }
  }, [sessionId, accessToken, organizationId, queryClient])

  function placeBid(teamId: string, amount: number) {
    setLastError(null)
    socketRef.current?.emit('auction.placeBid', { auctionSessionId: sessionId, teamId, amount })
  }

  return { connected, lastError, placeBid }
}
