import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../application/auction_providers.dart';
import '../data/models/auction_report.dart';

/// Per-team auction standing for one session — every team's
/// Initial/Remaining/Spent points, players-bought fraction, and full
/// "Purchased players" list. Sourced from the same `GET .../report` data
/// AuctionReportScreen already uses (`auctionReportProvider`): `teams[]` for
/// the summary figures, plus a client-side filter of `players[]` by
/// `soldToTeamId` for each team's purchased-players list — no parallel
/// fetch, no fabricated figures.
///
/// `maxSquadSize` isn't on the report response at all (see
/// `AuctionReportSessionInfo`) — it comes from the plain "get one session"
/// REST fetch (`auctionSessionDetailProvider`), the same extra `ref.watch`
/// the live room already does for the same reason (see
/// live_auction_room_view.dart's class doc comment).
class AuctionTeamDashboardScreen extends ConsumerWidget {
  const AuctionTeamDashboardScreen({super.key, required this.tournamentId, required this.sessionId});

  final String tournamentId;
  final String sessionId;

  AuctionSessionKey get _key => (tournamentId: tournamentId, sessionId: sessionId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(auctionReportProvider(_key));
    final maxSquadSize = ref.watch(auctionSessionDetailProvider(_key)).valueOrNull?.maxSquadSize;

    return Scaffold(
      appBar: AppBar(title: const Text('Team auction dashboard')),
      body: reportAsync.when(
        data: (report) {
          if (report.teams.isEmpty) {
            return const Center(child: Text('No teams registered for this auction.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: report.teams.length,
            itemBuilder: (context, index) {
              final team = report.teams[index];
              final purchased = report.players
                  .where((p) => p.status == 'sold' && p.soldToTeamId == team.tournamentTeamId)
                  .toList();
              return _TeamDashboardCard(team: team, purchased: purchased, maxSquadSize: maxSquadSize);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load team dashboard'),
        ),
      ),
    );
  }
}

class _TeamDashboardCard extends StatelessWidget {
  const _TeamDashboardCard({required this.team, required this.purchased, this.maxSquadSize});

  final AuctionTeamSummary team;
  final List<AuctionPlayerOutcome> purchased;
  final int? maxSquadSize;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(team.teamName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'INITIAL POINTS',
                    value: team.purseTotal != null ? '₹${team.purseTotal}' : '—',
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'REMAINING POINTS',
                    value: team.purseRemaining != null ? '₹${team.purseRemaining}' : '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'PLAYERS',
                    value: maxSquadSize != null
                        ? '${team.playersBought}/$maxSquadSize'
                        : '${team.playersBought}',
                  ),
                ),
                Expanded(child: _StatTile(label: 'TOTAL SPENT', value: '₹${team.totalSpent}')),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text('Purchased players', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (purchased.isEmpty)
              const Text('No players purchased yet.', style: TextStyle(color: AppColors.textSecondary))
            else
              for (final player in purchased)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          player.playerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${player.finalPrice ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
        ),
      ],
    );
  }
}
