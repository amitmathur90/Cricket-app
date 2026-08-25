import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../matches/data/models/match.dart' show MatchStatus;
import '../../../matches/presentation/widgets/match_card.dart' show MatchStatusBadge;
import '../../data/models/public_match.dart';

/// Public-section equivalent of `features/matches/presentation/widgets/match_card.dart`'s
/// `MatchCard`, built against [PublicMatch] instead of the authenticated
/// `Match` model (the public response has no officials/venue-id fields to
/// omit here, just a flat `venueName`). Reuses [MatchStatusBadge] as-is —
/// it only depends on the shared [MatchStatus] enum, not the full `Match`
/// shape.
class PublicMatchCard extends StatelessWidget {
  const PublicMatchCard({super.key, required this.match, required this.onTap});

  final PublicMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cancelled = match.status == MatchStatus.cancelled;
    final homeLabel = match.homeTeamName ?? 'TBD';
    final awayLabel = match.awayTeamName ?? 'TBD';
    final scheduledAt = match.scheduledAt?.toLocal();
    final dateLabel = scheduledAt != null ? DateFormat.yMMMd().format(scheduledAt) : 'Date TBD';
    final timeLabel = scheduledAt != null ? DateFormat.jm().format(scheduledAt) : null;
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
                        '$homeLabel vs $awayLabel',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: cancelled ? TextDecoration.lineThrough : null,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    MatchStatusBadge(status: match.status),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: outline),
                    const SizedBox(width: 4),
                    Text(dateLabel, style: Theme.of(context).textTheme.bodySmall),
                    if (timeLabel != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.access_time, size: 14, color: outline),
                      const SizedBox(width: 4),
                      Text(timeLabel, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
                if ((match.venueName ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.stadium_outlined, size: 14, color: outline),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            match.venueName!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (match.status == MatchStatus.completed &&
                    (match.resultSummary ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      match.resultSummary!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
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
