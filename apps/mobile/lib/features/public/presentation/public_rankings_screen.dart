import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../application/public_providers.dart';
import '../data/models/public_player_ranking.dart';

/// `GET public/organizations/:organizationId/players/rankings` — org-wide
/// leaderboard, sortable by the same [PublicRankingMetric] options the
/// backend's `RankingMetric` enum supports (runs/wickets/average/economy).
/// Performance figures + name only (no PII) — see `PublicPlayerRanking`'s
/// doc comment.
class PublicRankingsScreen extends ConsumerStatefulWidget {
  const PublicRankingsScreen({super.key, required this.organizationId});

  final String organizationId;

  @override
  ConsumerState<PublicRankingsScreen> createState() => _PublicRankingsScreenState();
}

class _PublicRankingsScreenState extends ConsumerState<PublicRankingsScreen> {
  PublicRankingMetric _metric = PublicRankingMetric.runs;

  @override
  Widget build(BuildContext context) {
    final scope = (organizationId: widget.organizationId, metric: _metric, limit: 50);
    final rankingsAsync = ref.watch(publicRankingsProvider(scope));

    return Scaffold(
      appBar: AppBar(title: const Text('Player Rankings')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                for (final metric in PublicRankingMetric.values)
                  ChoiceChip(
                    label: Text(metric.label),
                    selected: _metric == metric,
                    onSelected: (_) => setState(() => _metric = metric),
                  ),
              ],
            ),
          ),
          Expanded(
            child: rankingsAsync.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('No player statistics yet.'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(publicRankingsProvider(scope).future),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: rows.length,
                    itemBuilder: (context, index) => _RankingTile(row: rows[index]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(error is ApiException ? error.message : 'Failed to load rankings'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({required this.row});

  final PublicPlayerRanking row;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text('${row.position}')),
        title: Text(row.playerName),
        subtitle: Text('${row.matchesPlayed} matches'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${row.runs} runs · ${row.wickets} wkts'),
            if (row.average != null || row.economy != null)
              Text(
                [
                  if (row.average != null) 'Avg ${row.average!.toStringAsFixed(1)}',
                  if (row.economy != null) 'Econ ${row.economy!.toStringAsFixed(1)}',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
