import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../matches/data/models/match.dart';
import '../../../matches/presentation/widgets/match_card.dart';

/// Read-only match details, shown as a bottom sheet — used by the player
/// dashboard's Matches tab and Home tab's Next Match card.
///
/// Deliberately NOT a push into `MatchDetailScreen`
/// (features/matches/presentation/match_detail_screen.dart): that screen
/// bundles admin-only actions (Edit, Cancel match, Set Playing XI,
/// start/live scoring) that have no place in a player-facing read-only
/// view — showing that UI to a player and relying on the backend's role
/// guards to reject the underlying calls would be a worse experience (and a
/// worse safeguard) than simply not offering those actions here.
Future<void> showMatchInfoSheet(BuildContext context, Match match) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _MatchInfoSheet(match: match),
  );
}

class _MatchInfoSheet extends StatelessWidget {
  const _MatchInfoSheet({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final scheduledAt = match.scheduledAt?.toLocal();
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');
    final timeFormat = DateFormat.jm();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${match.homeTeamName ?? 'TBD'} vs ${match.awayTeamName ?? 'TBD'}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                MatchStatusBadge(status: match.status),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value: scheduledAt != null ? dateFormat.format(scheduledAt) : 'TBD',
            ),
            _InfoRow(
              icon: Icons.access_time,
              label: 'Time',
              value: scheduledAt != null ? timeFormat.format(scheduledAt) : 'TBD',
            ),
            _InfoRow(
              icon: Icons.stadium_outlined,
              label: 'Venue',
              value: match.venueName ?? match.venueDisplayName ?? 'TBD',
            ),
            _InfoRow(
              icon: Icons.sports_outlined,
              label: 'Umpire',
              value: match.umpireName ?? match.umpireOfficialDisplayName ?? 'TBD',
            ),
            if (match.winnerTeamName != null)
              _InfoRow(
                icon: Icons.emoji_events_outlined,
                label: 'Winner',
                value: match.winnerTeamName!,
              ),
            if ((match.resultSummary ?? '').trim().isNotEmpty)
              _InfoRow(icon: Icons.summarize_outlined, label: 'Result', value: match.resultSummary!),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
