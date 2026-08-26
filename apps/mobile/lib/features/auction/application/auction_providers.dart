import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/auction_repository.dart';
import '../data/models/auction_bid.dart';
import '../data/models/auction_pool_entry.dart';
import '../data/models/auction_report.dart';
import '../data/models/auction_session.dart';
import '../data/models/player_purchase_history.dart';

final auctionRepositoryProvider = Provider<AuctionRepository>((ref) {
  return AuctionRepository(ref.watch(apiClientProvider));
});

/// Auction sessions for one tournament, in the caller's active org.
final auctionSessionsListProvider =
    FutureProvider.autoDispose.family<List<AuctionSession>, String>((ref, tournamentId) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(auctionRepositoryProvider).listSessions(organizationId, tournamentId);
});

typedef AuctionSessionKey = ({String tournamentId, String sessionId});

final auctionSessionDetailProvider =
    FutureProvider.autoDispose.family<AuctionSession, AuctionSessionKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(auctionRepositoryProvider).getSession(organizationId, key.tournamentId, key.sessionId);
});

final auctionPoolListProvider =
    FutureProvider.autoDispose.family<List<AuctionPlayerPoolEntry>, AuctionSessionKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(auctionRepositoryProvider).listPool(organizationId, key.tournamentId, key.sessionId);
});

final auctionReportProvider =
    FutureProvider.autoDispose.family<AuctionReport, AuctionSessionKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(auctionRepositoryProvider).getReport(organizationId, key.tournamentId, key.sessionId);
});

/// A player's full cross-session auction history — used by the "purchase
/// history" action on the org player list (see
/// ../presentation/widgets/player_purchase_history_dialog.dart).
final playerPurchaseHistoryProvider =
    FutureProvider.autoDispose.family<PlayerPurchaseHistory, String>((ref, playerId) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(auctionRepositoryProvider).getPlayerPurchaseHistory(organizationId, playerId);
});

typedef AuctionPlayerBidsKey = ({String tournamentId, String sessionId, String playerId});

/// One player's full bid history within a single session — the "complete
/// bid history" drill-down opened from AuctionHistoryScreen. Backed by
/// `GET .../bids?playerId=` (`AuctionRepository.listBids`), which is
/// admin-only (`@Roles(ORG_ADMIN, TOURNAMENT_ADMIN)` on
/// `AuctionController.listBids`) — a non-admin caller's 403 surfaces as the
/// same `ApiException.message` error state every other fetch failure in
/// this app renders (see AuctionPlayerBidHistoryScreen's doc comment),
/// rather than being hidden client-side, matching this app's established
/// RBAC-via-backend-rejection convention.
final auctionPlayerBidsProvider =
    FutureProvider.autoDispose.family<List<AuctionBidRecord>, AuctionPlayerBidsKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref
      .watch(auctionRepositoryProvider)
      .listBids(organizationId, key.tournamentId, key.sessionId, playerId: key.playerId);
});
