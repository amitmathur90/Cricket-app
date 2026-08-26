import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../application/auction_providers.dart';

/// One player's complete bid history within a single auction session —
/// opened by tapping a row on [AuctionHistoryScreen]. Backed by
/// `GET .../bids?playerId=` (`AuctionRepository.listBids`), the same
/// endpoint the live room used to build its per-lot ticker/feed, just
/// fetched as a plain REST call here instead of accumulated from socket
/// events (there is no live room once a player's lot has resolved).
///
/// `listBids` is `@Roles(ORG_ADMIN, TOURNAMENT_ADMIN)`-only as of this pass
/// (previously open to any org member) — matching the new spec requirement
/// that bid-history viewing is an admin-only capability. This screen isn't
/// hidden per-role: per this app's established RBAC-via-backend-rejection
/// convention (see pool_management_view.dart's / player_list_tab.dart's
/// doc comments — admin actions/views are shown to everyone and the API's
/// 403 is what actually enforces the boundary), a non-admin caller just
/// sees this screen's existing error state (`ApiException.message`, the
/// same "Failed to load ..." pattern every other fetch failure in this
/// feature renders) instead of an unhandled crash.
class AuctionPlayerBidHistoryScreen extends ConsumerWidget {
  const AuctionPlayerBidHistoryScreen({
    super.key,
    required this.tournamentId,
    required this.sessionId,
    required this.playerId,
    this.playerName,
  });

  final String tournamentId;
  final String sessionId;
  final String playerId;

  /// Passed via `extra` from the row that was tapped (AuctionHistoryScreen
  /// already has it loaded) so the app bar has a title immediately, rather
  /// than waiting on this screen's own fetch — same `extra`-carries-a-name
  /// pattern used by e.g. `organizationName` on the org-switcher route.
  final String? playerName;

  AuctionPlayerBidsKey get _key =>
      (tournamentId: tournamentId, sessionId: sessionId, playerId: playerId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bidsAsync = ref.watch(auctionPlayerBidsProvider(_key));

    return Scaffold(
      appBar: AppBar(title: Text(playerName != null ? '$playerName — bids' : 'Bid history')),
      body: bidsAsync.when(
        data: (bids) {
          if (bids.isEmpty) {
            return const Center(child: Text('No bids were placed on this player.'));
          }
          // The backend returns bids ordered oldest-first by bidSequence
          // (AuctionService.listBids) — reverse to newest-first, matching
          // every other bid-history feed in this app (the live room's
          // _BidHistorySection, player_purchase_history_dialog.dart).
          final newestFirst = bids.reversed.toList();
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: newestFirst.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final bid = newestFirst[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.accents[bid.teamName.hashCode.abs() % AppColors.accents.length],
                  foregroundColor: Colors.white,
                  child: Text(bid.teamName.isEmpty ? '?' : bid.teamName[0].toUpperCase()),
                ),
                title: Text(bid.teamName),
                subtitle: Text('Bid #${bid.bidSequence}'),
                trailing: Text(
                  '₹${bid.bidAmount}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load bid history'),
        ),
      ),
    );
  }
}
