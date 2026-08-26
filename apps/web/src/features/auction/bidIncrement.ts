import type { BidIncrementRule } from '../../types/auction'

const DEFAULT_INCREMENT_PCT = 0.05

/**
 * Client-side mirror of the backend's `computeMinIncrement`
 * (apps/backend/src/modules/auction/auction-bid-increment.util.ts, ported
 * line-for-line) — used only to prefill/display the next minimum bid and to
 * grey out a team's bid option when it obviously can't afford the next
 * increment. The server recomputes and enforces this authoritatively on
 * every `auction.placeBid` call (see AuctionRealtimeService.placeBid); this
 * copy is a UX convenience only, never the real check.
 */
export function computeMinIncrement(currentBid: number, rules: BidIncrementRule[] | null | undefined): number {
  if (rules && rules.length > 0) {
    const sorted = [...rules].sort((a, b) => {
      const av = a.upTo === null || a.upTo === undefined ? Infinity : a.upTo
      const bv = b.upTo === null || b.upTo === undefined ? Infinity : b.upTo
      return av - bv
    })
    const tier = sorted.find((r) => r.upTo === null || r.upTo === undefined || currentBid < r.upTo)
    return (tier ?? sorted[sorted.length - 1]).increment
  }

  const unit = currentBid >= 100000 ? 5000 : currentBid >= 10000 ? 1000 : 100
  const raw = currentBid * DEFAULT_INCREMENT_PCT
  return Math.max(unit, Math.ceil(raw / unit) * unit)
}
