import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../data/models/practice_session.dart';

/// Status -> accent color, shared by [PracticeStatusBadge] and by
/// PracticeSessionDetailScreen's photo-header badge — mirrors MatchCard's
/// `statusColor`.
Color practiceStatusColor(PracticeSessionStatus status) => switch (status) {
      PracticeSessionStatus.scheduled => AppColors.info,
      PracticeSessionStatus.completed => AppColors.textSecondary,
      PracticeSessionStatus.cancelled => AppColors.textMuted,
    };

/// A single practice session's card — used both in [PracticeSessionsTab]'s
/// grouped list and anywhere else a compact summary is useful. Shows
/// practice type, date, time, venue, assigned coach (or "No coach
/// assigned"), and a status badge — same visual language as MatchCard.
/// Cancelled sessions are dimmed, matching MatchCard's cancelled treatment.
class PracticeSessionCard extends StatelessWidget {
  const PracticeSessionCard({super.key, required this.session, required this.onTap});

  final PracticeSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cancelled = session.status == PracticeSessionStatus.cancelled;
    final scheduledAt = session.scheduledAt.toLocal();
    final dateLabel = DateFormat.yMMMd().format(scheduledAt);
    final timeLabel = DateFormat.jm().format(scheduledAt);
    final outline = Theme.of(context).colorScheme.outline;

    return Opacity(
      opacity: cancelled ? 0.6 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        session.practiceType.label,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: cancelled ? TextDecoration.lineThrough : null,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PracticeStatusBadge(status: session.status),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: outline),
                    const SizedBox(width: 4),
                    Text(dateLabel, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 10),
                    Icon(Icons.access_time, size: 14, color: outline),
                    const SizedBox(width: 4),
                    Text(timeLabel, style: Theme.of(context).textTheme.bodySmall),
                    if (session.durationMinutes != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.timer_outlined, size: 14, color: outline),
                      const SizedBox(width: 4),
                      Text('${session.durationMinutes} min', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: outline),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        session.coachName ?? 'No coach assigned',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if ((session.venueName ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.stadium_outlined, size: 14, color: outline),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            session.venueName!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin compatibility wrapper around [StatusPill] — kept under this name
/// (rather than inlining [StatusPill] everywhere) because [PracticeSessionCard]
/// and PracticeSessionDetailScreen reference `PracticeStatusBadge` directly;
/// this keeps those call sites source-compatible while still routing through
/// the shared [StatusPill] styling. Mirrors MatchCard's `MatchStatusBadge`.
class PracticeStatusBadge extends StatelessWidget {
  const PracticeStatusBadge({super.key, required this.status});

  final PracticeSessionStatus status;

  @override
  Widget build(BuildContext context) {
    return StatusPill(label: status.label, color: practiceStatusColor(status));
  }
}
