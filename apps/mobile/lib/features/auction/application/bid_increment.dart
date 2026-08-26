import '../data/models/auction_session.dart';

/// Client-side mirror of the backend's `computeMinIncrement`
/// (apps/backend/src/modules/auction/auction-bid-increment.util.ts) — used
/// ONLY for the live auction room's "Next Bid" preview display (the always-
/// visible amount line, and the amount shown on each team's PLACE BID
/// button label). The backend remains the sole source of truth for what a
/// bid actually needs to clear; a rejected bid still surfaces via
/// `auction.error`.
///
/// Mirrors the exact same two cases as the backend, so this must be kept in
/// lockstep with that file if it ever changes:
///  - If the session has a tiered `bidIncrementRules` schedule, use the
///    first tier (ascending by `upTo`, with `upTo: null` sorting last as the
///    catch-all) whose ceiling the current bid falls under — reusing the
///    last tier's increment for any bid at or above every configured
///    ceiling (rather than blocking).
///  - Otherwise, default to 5% of the current bid, rounded up to a "round"
///    unit (100 below 10k, 1,000 below 100k, 5,000 at or above 100k).
num computeMinIncrement(num currentBid, List<AuctionBidIncrementTier>? rules) {
  if (rules != null && rules.isNotEmpty) {
    final sorted = [...rules]..sort((a, b) {
        final av = a.upTo ?? double.infinity;
        final bv = b.upTo ?? double.infinity;
        return av.compareTo(bv);
      });
    for (final tier in sorted) {
      if (tier.upTo == null || currentBid < tier.upTo!) return tier.increment;
    }
    return sorted.last.increment;
  }

  final unit = currentBid >= 100000 ? 5000 : (currentBid >= 10000 ? 1000 : 100);
  final raw = currentBid * 0.05;
  final ceilValue = (raw / unit).ceil() * unit;
  return ceilValue > unit ? ceilValue : unit;
}

/// The minimum bid amount the backend would currently accept for [lot] —
/// `currentBid + computeMinIncrement(currentBid, rules)`.
num computeNextBid(num currentBid, List<AuctionBidIncrementTier>? rules) =>
    currentBid + computeMinIncrement(currentBid, rules);
