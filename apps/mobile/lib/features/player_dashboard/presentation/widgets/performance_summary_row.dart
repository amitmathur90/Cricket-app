import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../players/application/players_providers.dart';

/// Home tab's "Your Performance" summary — Runs / Wickets / Matches, from
/// the caller's own career statistics (`PlayersRepository.getStatistics`,
/// the same endpoint `PlayerStatisticsScreen`/`PlayerStatsTab` use).
class PerformanceSummaryRow extends ConsumerWidget {
  const PerformanceSummaryRow({super.key, required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(playerStatisticsProvider(playerId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Performance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            statsAsync.when(
              data: (stats) => Row(
                children: [
                  Expanded(child: _Stat(label: 'Runs', value: '${stats.summary.totalRuns}')),
                  Expanded(child: _Stat(label: 'Wickets', value: '${stats.summary.totalWickets}')),
                  Expanded(
                    child: _Stat(label: 'Matches', value: '${stats.summary.matchesPlayed}'),
                  ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Text(
                error is ApiException ? error.message : 'Failed to load statistics',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
