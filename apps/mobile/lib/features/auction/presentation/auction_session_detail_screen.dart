import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../auth/application/session_controller.dart';
import '../application/auction_providers.dart';
import '../data/models/auction_session.dart';
import 'widgets/live_auction_room_view.dart';
import 'widgets/pool_management_view.dart';

/// Session detail — dispatches to the right view for the session's current
/// status: pool management (`scheduled`), the live room (`live`/`paused`),
/// or a simple completed summary with a link to the full report
/// (`completed`).
class AuctionSessionDetailScreen extends ConsumerWidget {
  const AuctionSessionDetailScreen({super.key, required this.tournamentId, required this.sessionId});

  final String tournamentId;
  final String sessionId;

  AuctionSessionKey get _key => (tournamentId: tournamentId, sessionId: sessionId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
    final sessionAsync = ref.watch(auctionSessionDetailProvider(_key));

    return Scaffold(
      appBar: AppBar(
        title: sessionAsync.when(
          data: (session) => Text(session.name),
          loading: () => const Text('Auction session'),
          error: (error, stackTrace) => const Text('Auction session'),
        ),
      ),
      body: organizationId == null
          ? const Center(child: Text('No active organization'))
          : sessionAsync.when(
              data: (session) => switch (session.status) {
                AuctionSessionStatus.scheduled => PoolManagementView(
                    organizationId: organizationId,
                    tournamentId: tournamentId,
                    sessionId: sessionId,
                  ),
                AuctionSessionStatus.live ||
                AuctionSessionStatus.paused =>
                  LiveAuctionRoomView(
                    organizationId: organizationId,
                    tournamentId: tournamentId,
                    sessionId: sessionId,
                  ),
                AuctionSessionStatus.completed => _CompletedSummary(
                    tournamentId: tournamentId,
                    sessionId: sessionId,
                  ),
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(error is ApiException ? error.message : 'Failed to load auction session'),
              ),
            ),
    );
  }
}

class _CompletedSummary extends StatelessWidget {
  const _CompletedSummary({required this.tournamentId, required this.sessionId});

  final String tournamentId;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 48, color: Colors.green),
            const SizedBox(height: 12),
            const Text('This auction session has finished.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push(auctionReportPath(tournamentId, sessionId)),
              icon: const Icon(Icons.summarize),
              label: const Text('View report'),
            ),
          ],
        ),
      ),
    );
  }
}
