import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../application/auction_providers.dart';

/// `GET .../auction-sessions/:sessionId/report` rendered as plain lists —
/// per-team spend/purse summary and per-player sold/unsold outcomes. No
/// charts for M1 per the spec.
class AuctionReportScreen extends ConsumerWidget {
  const AuctionReportScreen({super.key, required this.tournamentId, required this.sessionId});

  final String tournamentId;
  final String sessionId;

  AuctionSessionKey get _key => (tournamentId: tournamentId, sessionId: sessionId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(auctionReportProvider(_key));

    return Scaffold(
      appBar: AppBar(title: const Text('Auction report')),
      body: reportAsync.when(
        data: (report) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(report.session.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Teams', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...report.teams.map(
              (team) => Card(
                child: ListTile(
                  title: Text(team.teamName),
                  subtitle: Text(
                    '${team.playersBought} player${team.playersBought == 1 ? '' : 's'} bought · '
                    'Spent ${team.totalSpent}',
                  ),
                  trailing: Text('Purse: ${team.purseRemaining ?? '—'} / ${team.purseTotal ?? '—'}'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Players', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...report.players.map(
              (player) => Card(
                child: ListTile(
                  title: Text(player.playerName),
                  subtitle: Text(
                    player.status == 'sold'
                        ? 'Sold to ${player.soldToTeamName ?? 'unknown team'} for ${player.finalPrice}'
                        : 'Status: ${player.status}',
                  ),
                  trailing: Text('Base: ${player.basePrice}'),
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load report'),
        ),
      ),
    );
  }
}
