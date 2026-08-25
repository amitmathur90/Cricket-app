import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../application/matches_providers.dart';

/// Match Officials tab of `MatchCenterScreen` — a simple display of
/// `Match.umpireName`/`Match.scorerName`, both of which already exist from
/// the matches module (see match.entity.ts) and are set via the "Assign
/// umpire/scorer" admin action MatchDetailScreen already exposes. No new
/// backend surface needed here.
class MatchOfficialsTab extends ConsumerWidget {
  const MatchOfficialsTab({super.key, required this.tournamentId, required this.matchId});

  final String tournamentId;
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (tournamentId: tournamentId, matchId: matchId);
    final matchAsync = ref.watch(matchDetailProvider(key));

    return matchAsync.when(
      data: (match) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OfficialRow(icon: Icons.sports_outlined, label: 'Umpire', value: match.umpireName ?? 'TBD'),
          const Divider(height: 24),
          _OfficialRow(icon: Icons.edit_note_outlined, label: 'Scorer', value: match.scorerName ?? 'TBD'),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(error is ApiException ? error.message : 'Failed to load match'),
      ),
    );
  }
}

class _OfficialRow extends StatelessWidget {
  const _OfficialRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 12),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
