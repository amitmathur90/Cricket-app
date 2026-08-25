import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../application/matches_providers.dart';
import 'widgets/match_commentary_tab.dart';
import 'widgets/match_fall_of_wickets_tab.dart';
import 'widgets/match_officials_tab.dart';
import 'widgets/match_overview_tab.dart';
import 'widgets/match_partnerships_tab.dart';
import 'widgets/match_playing_xi_tab.dart';
import 'widgets/match_scorecard_tab.dart';

/// Match Management detail — full tabbed scorecard/stats view for a `live`
/// or `completed` match. Reached from `MatchDetailScreen`'s "Match Center"
/// button rather than folded into that screen's own body: MatchDetailScreen
/// already carries the admin-action surface (edit/cancel/assign
/// lineup/start-scoring/live-score CTAs) that applies across every match
/// status including `scheduled`, and this screen's tabs only make sense
/// once scoring has actually started — keeping them separate avoids
/// wrapping MatchDetailScreen's existing plain `ListView` body in a
/// conditional `DefaultTabController` and risking its current, working
/// functionality. This is still "reached from" the same screen per the
/// task's framing, just via a button push (same pattern as
/// `lineupSelectionPath`/`liveScoringPath`/`scoringSetupPath`, all of which
/// are separate routes MatchDetailScreen pushes to) rather than an inline
/// expansion.
///
/// Tab count: 7, not the task spec's 8 named items. "Scorecard", "Batting"
/// and "Bowling" were spec'd as up-to-3 separate items, but
/// `getScorecard`'s response carries batting AND bowling figures per
/// innings in one payload — splitting them into separate tabs would just
/// mean tapping between two halves of the same fetch for no benefit, so
/// they're merged into one "Scorecard" tab (see `MatchScorecardTab`'s doc
/// comment). The other six — Overview, Commentary, Fall of Wickets,
/// Partnerships, Playing XI, Match Officials — are each their own tab.
///
/// Data-availability honesty, summarized here (see each tab's own doc
/// comment for the full explanation):
///  - Overview / Scorecard / Playing XI / Match Officials: fully backed by
///    real data (`getScorecard`, `MatchLineupRepository.getLineup`, `Match`
///    entity fields).
///  - Commentary / Partnerships: real data, but only a bounded window of it
///    (last ~12 balls per innings; the innings' single most-recent/closing
///    partnership) — the backend has no full-history endpoint for either.
///  - Fall of Wickets: NOT available — no endpoint exposes the full ball
///    log needed to compute a score-at-each-wicket list. Shown as an
///    explicit "not available" state, not a guess.
///  - "MVP": omitted entirely (not a tab) — there is no player-of-the-match
///    concept anywhere in the backend to surface.
class MatchCenterScreen extends ConsumerWidget {
  const MatchCenterScreen({super.key, required this.tournamentId, required this.matchId});

  final String tournamentId;
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (tournamentId: tournamentId, matchId: matchId);
    final matchAsync = ref.watch(matchDetailProvider(key));

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: matchAsync.when(
            data: (match) => Text('${match.homeTeamName ?? 'TBD'} vs ${match.awayTeamName ?? 'TBD'}'),
            loading: () => const Text('Match Center'),
            error: (error, stackTrace) => const Text('Match Center'),
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Scorecard'),
              Tab(text: 'Commentary'),
              Tab(text: 'Fall of Wickets'),
              Tab(text: 'Partnerships'),
              Tab(text: 'Playing XI'),
              Tab(text: 'Officials'),
            ],
          ),
        ),
        body: matchAsync.when(
          data: (_) => TabBarView(
            children: [
              MatchOverviewTab(tournamentId: tournamentId, matchId: matchId),
              MatchScorecardTab(tournamentId: tournamentId, matchId: matchId),
              MatchCommentaryTab(tournamentId: tournamentId, matchId: matchId),
              const MatchFallOfWicketsTab(),
              MatchPartnershipsTab(tournamentId: tournamentId, matchId: matchId),
              MatchPlayingXiTab(tournamentId: tournamentId, matchId: matchId),
              MatchOfficialsTab(tournamentId: tournamentId, matchId: matchId),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(error is ApiException ? error.message : 'Failed to load match'),
          ),
        ),
      ),
    );
  }
}
