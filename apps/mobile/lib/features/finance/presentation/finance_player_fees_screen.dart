import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../application/finance_providers.dart';
import 'widgets/finance_format.dart';
import 'widgets/not_tracked_chip.dart';

/// `GET .../finance/player-fees?tournamentId=...` — per-registered-player
/// registration fee owed. Same read-only, honest-placeholder rationale as
/// [FinanceTeamFeesScreen] — see its doc comment and `PlayerFeeRow`'s.
class FinancePlayerFeesScreen extends ConsumerWidget {
  const FinancePlayerFeesScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feesAsync = ref.watch(financePlayerFeesProvider(tournamentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Player fees')),
      body: feesAsync.when(
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('No players registered to this tournament yet.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(financePlayerFeesProvider(tournamentId).future),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(row.playerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${row.teamName} · Fee owed: ${formatInr(row.feeAmount)}'),
                    trailing: const NotTrackedChip(),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load player fees'),
        ),
      ),
    );
  }
}
