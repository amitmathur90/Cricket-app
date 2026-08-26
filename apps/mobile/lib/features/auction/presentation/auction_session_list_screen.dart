import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../auth/application/session_controller.dart';
import '../application/auction_providers.dart';
import '../data/models/auction_session.dart';
import 'widgets/create_auction_session_dialog.dart';

/// Lists auction sessions for one tournament, with a "Create session"
/// action. Tapping a session opens AuctionSessionDetailScreen, which
/// dispatches to pool-management / live-room / report views based on the
/// session's current status.
class AuctionSessionListScreen extends ConsumerWidget {
  const AuctionSessionListScreen({super.key, required this.tournamentId});

  final String tournamentId;

  Future<void> _createSession(BuildContext context, WidgetRef ref, String organizationId) async {
    final input = await showCreateAuctionSessionDialog(context);
    if (input == null) return;
    try {
      await ref.read(auctionRepositoryProvider).createSession(organizationId, tournamentId, input);
      ref.invalidate(auctionSessionsListProvider(tournamentId));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
    final sessionsAsync = ref.watch(auctionSessionsListProvider(tournamentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auction sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create session',
            onPressed: organizationId == null
                ? null
                : () => _createSession(context, ref, organizationId),
          ),
        ],
      ),
      body: organizationId == null
          ? const Center(child: Text('No active organization'))
          : sessionsAsync.when(
              data: (sessions) {
                if (sessions.isEmpty) {
                  return const Center(child: Text('No auction sessions yet.'));
                }
                return ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return ListTile(
                      leading: const Icon(Icons.gavel),
                      title: Text(session.name),
                      subtitle: Text(session.status.label),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(auctionSessionDetailPath(tournamentId, session.id)),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(error is ApiException ? error.message : 'Failed to load auction sessions'),
              ),
            ),
    );
  }
}
