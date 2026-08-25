import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../practice/data/models/practice_session.dart';
import '../../application/player_dashboard_providers.dart';

/// Home tab's "Upcoming Practice" card — the caller's team's soonest
/// upcoming practice session, or an honest empty state.
///
/// Unlike [NextMatchCard], there is no tournament-wide fallback available
/// here at all (see [playerUpcomingPracticeProvider]'s doc comment) — this
/// is either the caller's real team's next session, or nothing, and the
/// empty state distinguishes "no team yet" from "team has nothing
/// scheduled" so the caller isn't told the wrong reason.
class UpcomingPracticeCard extends ConsumerWidget {
  const UpcomingPracticeCard({super.key});

  static PracticeSession? nextUpcoming(List<PracticeSession> sessions) {
    final now = DateTime.now();
    final upcoming = sessions
        .where((s) => s.status == PracticeSessionStatus.scheduled && !s.scheduledAt.isBefore(now))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipAsync = ref.watch(myTeamMembershipProvider);
    final sessionsAsync = ref.watch(playerUpcomingPracticeProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fitness_center, size: 16, color: primary),
                const SizedBox(width: 6),
                Text(
                  'UPCOMING PRACTICE',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            sessionsAsync.when(
              data: (sessions) {
                final next = nextUpcoming(sessions);
                if (next != null) return _SessionSummary(session: next);
                return membershipAsync.when(
                  data: (membership) => Text(
                    membership == null
                        ? "You haven't been added to a team roster yet."
                        : 'No upcoming practice scheduled.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  loading: () => const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => Text(
                    'No upcoming practice scheduled.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Text(
                error is ApiException ? error.message : 'Failed to load practice sessions',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.session});

  final PracticeSession session;

  String _relativeDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat.yMMMd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    final scheduledAt = session.scheduledAt.toLocal();
    final outline = Theme.of(context).colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.practiceType.label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${_relativeDay(scheduledAt)} • ${DateFormat.jm().format(scheduledAt)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: outline),
        ),
        if ((session.venueName ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            session.venueName!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
          ),
        ],
      ],
    );
  }
}
