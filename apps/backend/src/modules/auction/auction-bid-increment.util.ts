import { BidIncrementRule } from '../../database/entities/auction-session.entity';

const DEFAULT_INCREMENT_PCT = 0.05;

/**
 * Minimum step a new bid must clear above the current bid.
 *
 * If the session defines `bidIncrementRules` (a tiered schedule, e.g.
 * `[{upTo: 1000000, increment: 50000}, {upTo: null, increment: 100000}]`),
 * the tier whose `upTo` ceiling the current bid falls under (the first
 * ascending tier where `currentBid < upTo`, or the `upTo: null` tier as a
 * catch-all) determines the increment.
 *
 * Otherwise we default to 5% of the current bid, rounded UP to a "round"
 * unit so increments read naturally instead of landing on odd decimals:
 * nearest 100 below 10k, nearest 1,000 below 100k, nearest 5,000 at or
 * above 100k. This is a deliberate MVP default, not from the design doc —
 * organizers who want a real schedule should set `bidIncrementRules`.
 */
export function computeMinIncrement(
  currentBid: number,
  rules: BidIncrementRule[] | null | undefined,
): number {
  if (rules && rules.length > 0) {
    const sorted = [...rules].sort((a, b) => {
      const av = a.upTo === null || a.upTo === undefined ? Infinity : a.upTo;
      const bv = b.upTo === null || b.upTo === undefined ? Infinity : b.upTo;
      return av - bv;
    });
    const tier = sorted.find((r) => r.upTo === null || r.upTo === undefined || currentBid < r.upTo);
    return (tier ?? sorted[sorted.length - 1]).increment;
  }

  const unit = currentBid >= 100000 ? 5000 : currentBid >= 10000 ? 1000 : 100;
  const raw = currentBid * DEFAULT_INCREMENT_PCT;
  return Math.max(unit, Math.ceil(raw / unit) * unit);
}
