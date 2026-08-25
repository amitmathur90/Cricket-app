import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../application/public_providers.dart';
import '../data/models/public_live_state.dart';

/// Full public read-only live match view — `GET
/// public/organizations/:organizationId/tournaments/:tournamentId/live-score/:matchId`,
/// reused verbatim from `ScoringRealtimeService.getLiveState` (see
/// `PublicLiveMatchState`'s doc comment). Polls every 15s while this screen
/// is open, same "REST poll, no WebSocket" approach as
/// `PublicLiveScoreCard` — this screen just shows more of the same
/// response (both innings' scorelines, current partnership, current over,
/// recent balls) rather than only the home card's one-line summary.
class PublicLiveMatchScreen extends ConsumerStatefulWidget {
  const PublicLiveMatchScreen({
    super.key,
    required this.organizationId,
    required this.tournamentId,
    required this.matchId,
  });

  final String organizationId;
  final String tournamentId;
  final String matchId;

  @override
  ConsumerState<PublicLiveMatchScreen> createState() => _PublicLiveMatchScreenState();
}

class _PublicLiveMatchScreenState extends ConsumerState<PublicLiveMatchScreen> {
  static const _pollInterval = Duration(seconds: 15);
  Timer? _timer;

  PublicLiveScoreScope get _scope => (
        organizationId: widget.organizationId,
        tournamentId: widget.tournamentId,
        matchId: widget.matchId,
      );

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_pollInterval, (_) {
      if (mounted) ref.invalidate(publicLiveScoreProvider(_scope));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveAsync = ref.watch(publicLiveScoreProvider(_scope));

    return Scaffold(
      appBar: AppBar(title: const Text('Live Score')),
      body: liveAsync.when(
        data: (state) {
          if (state.innings.isEmpty) {
            return const Center(child: Text('This match has not started yet.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(publicLiveScoreProvider(_scope).future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final innings in state.innings.reversed) ...[
                  _InningsCard(innings: innings, isCurrent: innings == state.currentInnings),
                  const SizedBox(height: 12),
                ],
                if ((state.match.resultSummary ?? '').trim().isNotEmpty)
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        state.match.resultSummary!,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Live score unavailable'),
        ),
      ),
    );
  }
}

class _InningsCard extends StatelessWidget {
  const _InningsCard({required this.innings, required this.isCurrent});

  final PublicLiveInnings innings;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: isCurrent ? colorScheme.surfaceContainerHighest : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Innings ${innings.inningsNumber}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                Text(
                  '${innings.scoreline} (${innings.totalOversBowled} ov)',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              'Extras: ${innings.extrasTotal}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (innings.striker != null || innings.nonStriker != null) ...[
              const Divider(height: 20),
              if (innings.striker != null) _BatterRow(figures: innings.striker!, onStrike: true),
              if (innings.nonStriker != null)
                _BatterRow(figures: innings.nonStriker!, onStrike: false),
            ],
            if (innings.currentOver?.bowler != null) ...[
              const SizedBox(height: 8),
              Text(
                '${innings.currentOver!.bowler!.fullName} — '
                '${innings.currentOver!.bowlerInningsFigures?.overs.toStringAsFixed(1) ?? '0.0'}-'
                '${innings.currentOver!.bowlerInningsFigures?.maidens ?? 0}-'
                '${innings.currentOver!.bowlerInningsFigures?.runsConceded ?? 0}-'
                '${innings.currentOver!.bowlerInningsFigures?.wickets ?? 0}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (innings.recentBalls.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('This over', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final ball in innings.recentBalls.take(6))
                    _BallChip(ball: ball),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BatterRow extends StatelessWidget {
  const _BatterRow({required this.figures, required this.onStrike});

  final PublicBattingFigures figures;
  final bool onStrike;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              onStrike ? '${figures.fullName} *' : figures.fullName,
              style: TextStyle(fontWeight: onStrike ? FontWeight.bold : FontWeight.normal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('${figures.runs} (${figures.ballsFaced})'),
          const SizedBox(width: 10),
          Text('SR ${figures.strikeRate.toStringAsFixed(1)}'),
        ],
      ),
    );
  }
}

class _BallChip extends StatelessWidget {
  const _BallChip({required this.ball});

  final PublicBallSummary ball;

  @override
  Widget build(BuildContext context) {
    final label = ball.isWicket
        ? 'W'
        : ball.extraType != null
            ? '${ball.runsExtra}${ball.extraType![0].toUpperCase()}'
            : '${ball.runsBatter}';
    final colorScheme = Theme.of(context).colorScheme;
    final background = ball.isWicket
        ? colorScheme.errorContainer
        : (ball.runsBatter == 4 || ball.runsBatter == 6)
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest;
    return CircleAvatar(
      radius: 16,
      backgroundColor: background,
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
