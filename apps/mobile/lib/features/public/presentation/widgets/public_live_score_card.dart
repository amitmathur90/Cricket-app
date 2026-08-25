import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../application/public_providers.dart';
import '../../data/models/public_match.dart';

/// The "LIVE NOW" card for the Fan Home screen — a compact, read-only score
/// snapshot for one `live`-status match, e.g. "Tigers 105/3 vs Warriors —
/// 15.2 Overs". No WebSocket: `getLiveScore` is a plain REST endpoint (see
/// `PublicRepository.getLiveScore`), so this just re-fetches it on a
/// [Timer.periodic] every 20s for a "live-ish" feel while this card is on
/// screen — cheap enough for a single card, and avoids standing up a second
/// realtime transport just for a read-only public view (the authenticated
/// live-scoring screen's Socket.IO room is for scorer *input*, which this
/// section never does).
class PublicLiveScoreCard extends ConsumerStatefulWidget {
  const PublicLiveScoreCard({
    super.key,
    required this.organizationId,
    required this.tournamentId,
    required this.match,
    required this.onTap,
  });

  final String organizationId;
  final String tournamentId;

  /// The `live`-status match this card summarizes — team names come from
  /// here (the live-score endpoint itself only returns tournament-team ids,
  /// not names, see `PublicLiveMatchInfo`'s doc comment).
  final PublicMatch match;
  final VoidCallback onTap;

  @override
  ConsumerState<PublicLiveScoreCard> createState() => _PublicLiveScoreCardState();
}

class _PublicLiveScoreCardState extends ConsumerState<PublicLiveScoreCard> {
  static const _pollInterval = Duration(seconds: 20);
  Timer? _timer;

  PublicLiveScoreScope get _scope => (
        organizationId: widget.organizationId,
        tournamentId: widget.tournamentId,
        matchId: widget.match.id,
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
    final colorScheme = Theme.of(context).colorScheme;
    final homeLabel = widget.match.homeTeamName ?? 'TBD';
    final awayLabel = widget.match.awayTeamName ?? 'TBD';

    return Card(
      clipBehavior: Clip.antiAlias,
      color: colorScheme.errorContainer.withValues(alpha: 0.25),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE NOW',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 8),
              liveAsync.when(
                data: (state) {
                  final innings = state.currentInnings;
                  if (innings == null) {
                    return Text('$homeLabel vs $awayLabel', style: Theme.of(context).textTheme.titleMedium);
                  }
                  final battingIsHome = innings.battingTournamentTeamId ==
                      widget.match.homeTournamentTeamId;
                  final battingLabel = battingIsHome ? homeLabel : awayLabel;
                  final bowlingLabel = battingIsHome ? awayLabel : homeLabel;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$battingLabel ${innings.scoreline} vs $bowlingLabel',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${innings.totalOversBowled} Overs',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (innings.striker != null || innings.currentOver?.bowler != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            [
                              if (innings.striker != null)
                                '${innings.striker!.fullName} ${innings.striker!.runs}(${innings.striker!.ballsFaced})',
                              if (innings.currentOver?.bowler != null)
                                '${innings.currentOver!.bowler!.fullName} bowling',
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  );
                },
                loading: () => Row(
                  children: [
                    Text('$homeLabel vs $awayLabel', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 10),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ),
                error: (error, stackTrace) => Text(
                  error is ApiException ? error.message : 'Score unavailable right now',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'VIEW LIVE SCORE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
