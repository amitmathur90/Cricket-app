/// Renders a decimal-as-string amount (e.g. `"540000.00"` or `"-30000.00"`)
/// as a rupee figure. Matches this app's existing, established
/// currency-formatting convention elsewhere (see e.g.
/// `live_auction_room_view.dart`'s `'₹${bid.amount}'`/`'₹${lot.basePrice}'`)
/// — a plain `₹` prefix over the raw decimal string, with no thousands
/// grouping invented here. The only addition over that baseline is sign
/// placement: a negative value (possible for [FinanceDashboard.netBalance])
/// renders as `-₹30000.00` rather than `₹-30000.00`.
String formatInr(String rawAmount) {
  final isNegative = rawAmount.startsWith('-');
  final magnitude = isNegative ? rawAmount.substring(1) : rawAmount;
  return '${isNegative ? '-' : ''}₹$magnitude';
}
