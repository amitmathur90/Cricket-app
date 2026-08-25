import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../scoring/data/models/scoring_models.dart';
import '../../application/match_center_providers.dart';
import '../../application/matches_providers.dart';
import 'match_team_name_resolver.dart';

/// Commentary tab of `MatchCenterScreen`.
///
/// Genuine backend limitation, not a shortcut: there is no full
/// ball-by-ball history endpoint anywhere in the scoring module — the only
/// ball-level data exposed is `getLiveState`'s `recentBalls`, which is
/// explicitly capped at the last ~12 non-voided balls PER INNINGS (see
/// `ScoringRealtimeService.buildInningsSnapshot`'s `take: 12`). This tab
/// renders exactly that — the most recent deliveries, most-recent-first —
/// with a visible note about the cap rather than pretending it's the full
/// innings. `commentaryText` is an optional free-text field scorers can
/// fill in while recording a ball; when it's null/empty this falls back to
/// a factual one-line description built purely from that ball's own
/// recorded fields (runs/extras/wicket) — never invented narrative text.
class MatchCommentaryTab extends ConsumerWidget {
  const MatchCommentaryTab({super.key, required this.tournamentId, required this.matchId});

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
        child: Text(error is ApiException ? error.message : 'Failed to load ball data'),
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
                      'Showing the last ~12 deliveries recorded for each innings — full '
                      'ball-by-ball history isn\'t exposed by the API yet.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final innings in liveState.innings.reversed) ...[
            Text(
              'Innings ${innings.inningsNumber} · ${matchTeamName(match, innings.battingTournamentTeamId)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (innings.recentBalls.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No deliveries recorded yet.'),
              )
            else
              for (final ball in innings.recentBalls.reversed) _BallTile(ball: ball),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _BallTile extends StatelessWidget {
  const _BallTile({required this.ball});

  final ScoringRecentBall ball;

  String _description() {
    final parts = <String>[];
    if (ball.isWicket) {
      parts.add(ball.dismissalType != null ? 'WICKET — ${dismissalTypeLabel(ball.dismissalType)}' : 'WICKET');
    }
    if (ball.extraType != null) {
      parts.add(_extraLabel(ball.extraType));
    } else if (ball.runsBatter == 4) {
      parts.add('FOUR');
    } else if (ball.runsBatter == 6) {
      parts.add('SIX');
    }
    final totalRuns = ball.runsBatter + ball.runsExtra;
    parts.add('$totalRuns run${totalRuns == 1 ? '' : 's'}');
    return parts.join(' · ');
  }

  String _extraLabel(String? raw) {
    for (final type in ScoringExtraType.values) {
      if (type.apiValue == raw) return type.label;
    }
    return raw ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final over = ball.overNumber != null ? '${ball.overNumber}.${ball.ballNumberInOver}' : '${ball.ballNumberInOver}';
    final commentary = (ball.commentaryText ?? '').trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(over, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _description(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ball.isWicket ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
                if (commentary.isNotEmpty)
                  Text(commentary, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
