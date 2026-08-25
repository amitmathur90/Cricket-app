import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../application/auction_providers.dart';

/// Lightweight dialog showing a player's cross-session auction history —
/// `GET .../players/:playerId/purchase-history`
/// (`PlayerPurchaseHistoryController` in
/// apps/backend/src/modules/auction/auction.controller.ts). Opened from a
/// menu action on the org player list (see player_list_tab.dart).
Future<void> showPlayerPurchaseHistoryDialog(
  BuildContext context, {
  required String playerId,
  required String playerName,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _PlayerPurchaseHistoryDialog(playerId: playerId, playerName: playerName),
  );
}

class _PlayerPurchaseHistoryDialog extends ConsumerWidget {
  const _PlayerPurchaseHistoryDialog({required this.playerId, required this.playerName});

  final String playerId;
  final String playerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(playerPurchaseHistoryProvider(playerId));

    return AlertDialog(
      title: Text('$playerName — auction history'),
      content: SizedBox(
        width: 420,
        height: 400,
        child: historyAsync.when(
          data: (history) {
            if (history.history.isEmpty) {
              return const Center(child: Text('No auction history for this player yet.'));
            }
            return ListView.separated(
              itemCount: history.history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = history.history[index];
                return ListTile(
                  title: Text(entry.auctionSessionName),
                  subtitle: Text(
                    entry.status == 'sold'
                        ? 'Sold to ${entry.soldToTeamName ?? 'unknown team'} for ${entry.finalPrice}'
                        : 'Status: ${entry.status} · Base price ${entry.basePrice}',
                  ),
                  trailing: Text('${entry.bids.length} bid${entry.bids.length == 1 ? '' : 's'}'),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(error is ApiException ? error.message : 'Failed to load history'),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
