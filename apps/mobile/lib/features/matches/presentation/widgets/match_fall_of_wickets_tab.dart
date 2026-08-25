import 'package:flutter/material.dart';

/// Fall of Wickets tab of `MatchCenterScreen` — deliberately a "not
/// available" state, not a fabricated approximation.
///
/// Reconstructing Fall of Wickets needs, for every dismissal, the running
/// team score at the moment it happened. That requires the full ordered
/// ball log for the innings. The backend does not expose one:
///  - `getScorecard` (`ScoringRealtimeService.getScorecard`) returns
///    per-player AGGREGATE batting/bowling figures only — no per-ball rows,
///    no dismissal order, no score-at-dismissal.
///  - `getLiveState`'s `recentBalls` is explicitly capped at the last ~12
///    non-voided balls PER INNINGS (`take: 12` in
///    `ScoringRealtimeService.buildInningsSnapshot`), so even where a wicket
///    ball happens to be visible there, the cumulative score up to that
///    point (needed to know the score "at" that wicket) isn't recoverable
///    from a 12-ball window for any innings longer than that.
/// There is no other endpoint on `ScoringController` that lists the `Ball`
/// entity's full history. Cross-referencing the scorecard's bowling figures
/// against something else doesn't help either — wickets-per-bowler says
/// nothing about the batting side's running total at each fall.
///
/// So this tab states the gap plainly instead of guessing.
class MatchFallOfWicketsTab extends StatelessWidget {
  const MatchFallOfWicketsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline_outlined, size: 40, color: outline),
            const SizedBox(height: 12),
            Text(
              'Fall of wickets isn\'t available yet',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The backend doesn\'t expose a full ball-by-ball history endpoint — only the last '
              '~12 deliveries per innings and aggregated batting/bowling figures. Reconstructing '
              'an accurate score-at-each-wicket needs the complete ball log, which isn\'t '
              'currently available from the API.',
              textAlign: TextAlign.center,
              style: TextStyle(color: outline, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
