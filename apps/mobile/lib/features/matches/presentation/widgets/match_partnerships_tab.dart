import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../application/match_center_providers.dart';
import '../../application/matches_providers.dart';
import 'match_team_name_resolver.dart';

/// Partnerships tab of `MatchCenterScreen` — `currentPartnership` per
/// innings from `getLiveState`.
///
/// Real limitation, documented rather than papered over: the backend has no
/// endpoint listing an innings' full partnership history. `Partnership` rows
/// ARE persisted per stand (see `ScoringRealtimeService
/// .recomputeInningsAggregates`, which fully rebuilds the `partnerships`
/// table from the ball log on every state change), but `getLiveState` only
/// ever surfaces ONE of them per innings — the query in
/// `buildInningsSnapshot` filters `WHERE end_ball_sequence IS NULL`, and
/// because `recomputeInningsAggregates` always leaves the LAST partnership
/// of the innings open-ended (`endSeq: null`) regardless of whether the
/// innings itself has completed, that query returns the innings' most
/// recent (or, for a completed innings, its final/closing) partnership —
/// never the ones before it. So for a completed innings this shows the
/// closing stand, not a full partnership-by-partnership breakdown; for an
/// innings that hasn't started yet, there's nothing to show at all.
class MatchPartnershipsTab extends ConsumerWidget {
  const MatchPartnershipsTab({super.key, required this.tournamentId, required this.matchId});

  final String tournamentId;
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (tournamentId: tournamentId, matchId: matchId);
    final matchAsync = ref.watch(matchDetailProvider(key));
    final liveStateAsync = ref.watch(matchLiveStateProvider(key));

    if (matchAsync.isLoading || liveStateAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (matchAsync.hasError) {
      final error = matchAsync.error;
      return Center(child: Text(error is ApiException ? error.message : 'Failed to load match'));
    }
    if (liveStateAsync.hasError) {
      final error = liveStateAsync.error;
      return Center(
        child: Text(error is ApiException ? error.message : 'Failed to load partnership data'),
      );
    }

    final match = matchAsync.value!;
    final liveState = liveStateAsync.value!;

    if (liveState.innings.isEmpty) {
      return const Center(child: Text('No innings have started for this match yet.'));
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(matchLiveStateProvider(key).future),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only the most recent (or, for a finished innings, closing) partnership of '
                      'each innings is available — a full partnership-by-partnership history '
                      'isn\'t exposed by the API.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final innings in liveState.innings)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Innings ${innings.inningsNumber} · '
                      '${matchTeamName(match, innings.battingTournamentTeamId)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (innings.currentPartnership == null)
                      const Text('No partnership data available for this innings.')
                    else
                      Text(
                        '${innings.currentPartnership!.batter1?.fullName ?? 'Unknown'} & '
                        '${innings.currentPartnership!.batter2?.fullName ?? 'Unknown'}: '
                        '${innings.currentPartnership!.runs} runs '
                        '(${innings.currentPartnership!.ballsFaced} balls)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
