import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../players/data/models/player.dart' show PlayerRoleX;
import '../../application/auction_providers.dart';
import '../../data/models/auction_pool_entry.dart';
import 'add_to_pool_dialog.dart';

/// Pool-management view for a `scheduled` session (not yet started): lists
/// the current pool and offers "Add players to pool" / "Start auction".
/// Per this app's established RBAC-via-backend-rejection pattern (see
/// player_list_tab.dart's doc comment), these admin actions are shown to
/// everyone — an unauthorized caller just gets the API's 403 surfaced as a
/// snackbar, same as everywhere else in this app.
class PoolManagementView extends ConsumerWidget {
  const PoolManagementView({
    super.key,
    required this.organizationId,
    required this.tournamentId,
    required this.sessionId,
  });

  final String organizationId;
  final String tournamentId;
  final String sessionId;

  AuctionSessionKey get _key => (tournamentId: tournamentId, sessionId: sessionId);

  Future<void> _showError(BuildContext context, Object error) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error is ApiException ? error.message : 'Something went wrong')));
  }

  Future<void> _addToPool(BuildContext context, WidgetRef ref, List<AuctionPlayerPoolEntry> pool) async {
    final entries = await showAddToPoolDialog(
      context,
      organizationId: organizationId,
      excludedPlayerIds: pool.map((e) => e.playerId).toSet(),
      existingPoolSize: pool.length,
    );
    if (entries == null || entries.isEmpty) return;
    try {
      await ref.read(auctionRepositoryProvider).addToPool(organizationId, tournamentId, sessionId, entries);
      ref.invalidate(auctionPoolListProvider(_key));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      await _showError(context, e);
    }
  }

  Future<void> _startAuction(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(auctionRepositoryProvider).startSession(organizationId, tournamentId, sessionId);
      ref.invalidate(auctionSessionDetailProvider(_key));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      await _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolAsync = ref.watch(auctionPoolListProvider(_key));

    return poolAsync.when(
      data: (pool) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Player pool', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addToPool(context, ref, pool),
                  icon: const Icon(Icons.add),
                  label: const Text('Add players'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: pool.isEmpty ? null : () => _startAuction(context, ref),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start auction'),
                ),
              ],
            ),
          ),
          Expanded(
            child: pool.isEmpty
                ? const Center(child: Text('No players in the pool yet.'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: pool.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = pool[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${entry.lotOrder}')),
                        title: Text(entry.player?.fullName ?? entry.playerId),
                        subtitle: Text(
                          '${entry.player?.role.label ?? ''} · Base price ${entry.basePrice}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(error is ApiException ? error.message : 'Failed to load pool'),
      ),
    );
  }
}
