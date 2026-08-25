import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../application/finance_providers.dart';
import 'widgets/finance_format.dart';
import 'widgets/not_tracked_chip.dart';

/// `GET .../finance/team-fees?tournamentId=...` — per-registered-team
/// registration fee owed. Read-only: the backend's `paid`/`paidAt` fields
/// are honest placeholders (always `false`/`null` — see `TeamFeeRow`'s doc
/// comment), because no payment-tracking data exists anywhere in this
/// codebase yet. This screen renders that honestly as a "Not tracked" chip
/// rather than a fake paid/unpaid checkbox, so it never implies
/// functionality that doesn't exist.
class FinanceTeamFeesScreen extends ConsumerWidget {
  const FinanceTeamFeesScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feesAsync = ref.watch(financeTeamFeesProvider(tournamentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Team fees')),
      body: feesAsync.when(
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('No teams registered to this tournament yet.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(financeTeamFeesProvider(tournamentId).future),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(row.teamName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Fee owed: ${formatInr(row.feeAmount)}'),
                    trailing: const NotTrackedChip(),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load team fees'),
        ),
      ),
    );
  }
}
