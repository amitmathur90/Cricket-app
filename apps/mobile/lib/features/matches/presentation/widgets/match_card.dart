import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../data/models/match.dart';

/// Status -> accent color, shared by [MatchCard]'s [StatusPill] tag and by
/// [MatchStatusBadge] below.
Color statusColor(MatchStatus status) => switch (status) {
      MatchStatus.scheduled => AppColors.info,
      MatchStatus.live => AppColors.live,
      MatchStatus.completed => AppColors.textSecondary,
      MatchStatus.cancelled => AppColors.textMuted,
    };

/// A single match's row card — used in [MatchesTab]'s date-grouped schedule
/// list, plus TeamMatchesTab, CaptainMatchesTab/CaptainHomeTab, and
/// PlayerDashboard's matches tab. Shows kickoff time, a small initials
/// indicator for each side, ground name, and a [StatusPill] status tag.
/// Cancelled matches are visually de-emphasized (dimmed + strikethrough
/// team names) rather than hidden, per spec.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, required this.onTap});

  final Match match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cancelled = match.status == MatchStatus.cancelled;
    final homeLabel = match.homeTeamName ?? 'TBD';
    final awayLabel = match.awayTeamName ?? 'TBD';
    final scheduledAt = match.scheduledAt?.toLocal();
    final timeLabel = scheduledAt != null ? DateFormat.jm().format(scheduledAt) : 'Time TBD';
    final venue = (match.venueName ?? '').trim();

    return Opacity(
      opacity: cancelled ? 0.6 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const Spacer(),
                    StatusPill(
                      label: match.status.label,
                      color: statusColor(match.status),
                      filled: match.status == MatchStatus.live,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _TeamIndicator(name: homeLabel, strikeThrough: cancelled)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'vs',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Expanded(child: _TeamIndicator(name: awayLabel, strikeThrough: cancelled)),
                  ],
                ),
                if (venue.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.stadium_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venue,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A team's small initials avatar + name, used side-by-side either side of
/// "vs" on a [MatchCard] row.
class _TeamIndicator extends StatelessWidget {
  const _TeamIndicator({required this.name, this.strikeThrough = false});

  final String name;
  final bool strikeThrough;

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  static Color _colorFor(String name) => AppColors.accents[name.hashCode.abs() % AppColors.accents.length];

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(name);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            _initials(name),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: strikeThrough ? TextDecoration.lineThrough : null,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Thin compatibility wrapper around [StatusPill] — kept under this name
/// (rather than inlining [StatusPill] everywhere) because MatchDetailScreen,
/// PublicMatchCard, and MatchInfoSheet reference `MatchStatusBadge`
/// directly; this keeps those screens source-compatible while still routing
/// through the shared [StatusPill] styling.
class MatchStatusBadge extends StatelessWidget {
  const MatchStatusBadge({super.key, required this.status});

  final MatchStatus status;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: status.label,
      color: statusColor(status),
      filled: status == MatchStatus.live,
    );
  }
}
