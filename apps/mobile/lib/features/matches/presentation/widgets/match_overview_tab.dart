import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../application/match_center_providers.dart';
import '../../application/matches_providers.dart';
import 'match_team_name_resolver.dart';

/// Overview tab of `MatchCenterScreen` — team names, the score line per
/// innings ("Tigers 165/6 (20.0 ov)"), match status, and `resultSummary`.
///
/// No "MVP"/"Player of the match" element: the backend has no such concept
/// anywhere (`Match` only carries `winnerTournamentTeamId`/`resultSummary` —
/// see match.entity.ts's "Live-scoring fields" section, and no other entity
/// in the scoring module tracks a per-match standout player). Per the task's
/// own instruction this is omitted rather than fabricated (e.g. by
/// inventing a "highest scorer" heuristic that isn't what a real MVP pick
/// would be).
class MatchOverviewTab extends ConsumerWidget {
  const MatchOverviewTab({super.key, required this.tournamentId, required this.matchId});

  final String tournamentId;
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (tournamentId: tournamentId, matchId: matchId);
    final matchAsync = ref.watch(matchDetailProvider(key));
    final scorecardAsync = ref.watch(matchScorecardProvider(key));

    if (matchAsync.isLoading || scorecardAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (matchAsync.hasError) {
      final error = matchAsync.error;
      return Center(child: Text(error is ApiException ? error.message : 'Failed to load match'));
    }
    if (scorecardAsync.hasError) {
      final error = scorecardAsync.error;
      return Center(
        child: Text(error is ApiException ? error.message : 'Failed to load scorecard'),
      );
    }

    final match = matchAsync.value!;
    final scorecard = scorecardAsync.value!;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(matchDetailProvider(key));
        ref.invalidate(matchScorecardProvider(key));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${match.homeTeamName ?? 'TBD'} vs ${match.awayTeamName ?? 'TBD'}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Status: ${match.status.label}', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          if (scorecard.innings.isEmpty)
            const Text('No innings have started for this match yet.')
          else
            for (final innings in scorecard.innings)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Innings ${innings.inningsNumber} · '
                            '${matchTeamName(match, innings.battingTournamentTeamId)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${innings.totalRuns}/${innings.totalWickets} '
                          '(${innings.totalOversBowled} ov)',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          if ((scorecard.resultSummary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        scorecard.resultSummary!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if ((match.venueName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _InfoRow(icon: Icons.stadium_outlined, label: 'Venue', value: match.venueName!),
          ],
        ],
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
    final outline = Theme.of(context).colorScheme.outline;
    return Row(
      children: [
        Icon(icon, size: 18, color: outline),
        const SizedBox(width: 8),
        Text('$label: ', style: Theme.of(context).textTheme.bodyMedium),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
