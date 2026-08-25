import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../matches/data/models/match.dart';
import '../../../matches/presentation/widgets/match_card.dart' show statusColor;
import '../../application/player_dashboard_providers.dart';

/// Home tab's "Match Centre" banner — the "Match Centre" mockup's live-match
/// banner (a live match takes priority when one exists) falling back to the
/// caller's soonest upcoming match (see [playerRelevantMatchesProvider]), or
/// an honest "No upcoming match" state. There is no live score field
/// anywhere in the [Match] model (see match.dart's doc comment — the backend
/// never populates one), so a live match is captioned "Match in progress"
/// rather than showing a fabricated score.
///
/// When [PlayerMatches.teamScoped] comes back false — team membership
/// couldn't be resolved, see that provider's doc comment — this is captioned
/// as the tournament's next match rather than silently implying it's
/// specifically the caller's own team playing.
class NextMatchCard extends ConsumerWidget {
  const NextMatchCard({super.key});

  /// Soonest scheduled (not live, not completed/cancelled) match, ascending
  /// by kickoff time — used both as the banner's fallback and, via
  /// [featured], to decide what the "Upcoming Matches" list should skip.
  static Match? nextUpcoming(List<Match> matches) {
    final upcoming = upcomingList(matches);
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// All scheduled (not live/completed/cancelled) matches, ascending by
  /// kickoff time, optionally excluding one id — shared by the banner's
  /// [nextUpcoming] and the Home tab's "Upcoming Matches" list so the same
  /// match never appears in both.
  static List<Match> upcomingList(List<Match> matches, {String? excludeId}) {
    final now = DateTime.now();
    final upcoming = matches
        .where(
          (m) =>
              m.id != excludeId &&
              m.status == MatchStatus.scheduled &&
              (m.scheduledAt == null || !m.scheduledAt!.isBefore(now)),
        )
        .toList()
      ..sort((a, b) {
        if (a.scheduledAt == null && b.scheduledAt == null) return 0;
        if (a.scheduledAt == null) return 1;
        if (b.scheduledAt == null) return -1;
        return a.scheduledAt!.compareTo(b.scheduledAt!);
      });
    return upcoming;
  }

  /// The match the banner should feature: a currently-live match takes
  /// priority (the "Match Centre" mockup's live banner), falling back to the
  /// soonest upcoming one when nothing is live right now.
  static Match? featured(List<Match> matches) {
    for (final m in matches) {
      if (m.status == MatchStatus.live) return m;
    }
    return nextUpcoming(matches);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(playerRelevantMatchesProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: matchesAsync.when(
          data: (result) => _NextMatchBody(
            match: featured(result.matches),
            teamScoped: result.teamScoped,
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Text(
            error is ApiException ? error.message : 'Failed to load matches',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}

class _NextMatchBody extends StatelessWidget {
  const _NextMatchBody({required this.match, required this.teamScoped});

  final Match? match;
  final bool teamScoped;

  static String _relativeDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat.yMMMd().format(date);
  }

  /// The banner's status/score line — "Tigers won by 23 runs" style for a
  /// finished match, "Match in progress" for a live one (there is no live
  /// score field to show, see this file's doc comment), or the kickoff
  /// date/time for an upcoming one.
  static String _statusLine(Match match) {
    switch (match.status) {
      case MatchStatus.live:
        return 'Match in progress';
      case MatchStatus.completed:
        final summary = (match.resultSummary ?? '').trim();
        if (summary.isNotEmpty) return summary;
        if (match.winnerTeamName != null) return '${match.winnerTeamName} won';
        return 'Match completed';
      case MatchStatus.cancelled:
        return 'Match cancelled';
      case MatchStatus.scheduled:
        final scheduledAt = match.scheduledAt;
        if (scheduledAt == null) return 'Date TBD';
        final local = scheduledAt.toLocal();
        return '${_relativeDay(local)} • ${DateFormat.jm().format(local)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final primary = Theme.of(context).colorScheme.primary;
    final match = this.match;
    final isLive = match?.status == MatchStatus.live;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sports_cricket, size: 16, color: isLive ? AppColors.live : primary),
            const SizedBox(width: 6),
            Text(
              isLive ? 'LIVE MATCH' : 'NEXT MATCH',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isLive ? AppColors.live : primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
            ),
            if (match != null) ...[
              const Spacer(),
              if (isLive)
                const LivePill()
              else
                StatusPill(label: match.status.label, color: statusColor(match.status)),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (match == null)
          Text('No upcoming match', style: Theme.of(context).textTheme.bodyMedium)
        else ...[
          Text(
            '${match.homeTeamName ?? 'TBD'} vs ${match.awayTeamName ?? 'TBD'}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _statusLine(match),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: match.status == MatchStatus.completed ? AppColors.textPrimary : outline,
                  fontWeight:
                      match.status == MatchStatus.completed ? FontWeight.w600 : FontWeight.normal,
                ),
          ),
          if ((match.venueName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: outline),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    match.venueName!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
        if (!teamScoped) ...[
          const SizedBox(height: 10),
          Text(
            "We couldn't confirm your team roster yet, so this shows your tournament's "
            'schedule.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontStyle: FontStyle.italic, color: outline),
          ),
        ],
      ],
    );
  }
}
