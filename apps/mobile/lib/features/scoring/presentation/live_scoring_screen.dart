import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../auth/application/session_controller.dart';
import '../../matches/application/matches_providers.dart';
import '../../matches/data/models/match.dart';
import '../application/scoring_providers.dart';
import '../application/scoring_room_controller.dart';
import '../data/models/scoring_lineup.dart';
import '../data/models/scoring_models.dart';
import 'scoring_setup_screen.dart';
import 'widgets/extras_run_dialog.dart';
import 'widgets/wicket_dialog.dart';

/// The tablet/phone-optimized ball-by-ball scoring screen — the main
/// deliverable of the scoring feature. Owns no scoring state itself beyond
/// a couple of transient busy flags; all live state comes from
/// [scoringRoomControllerProvider] (a Socket.IO connection to the `/scoring`
/// namespace — see that controller for the event-handling details).
///
/// The screen is rendered as a small state machine purely derived from the
/// latest snapshot ([LiveScoringState]) rather than one-shot reactions to
/// individual WS events — every branch below (match completed / innings
/// completed / over boundary needing a new bowler / normal scoring) is a
/// pure function of "what does the current snapshot look like", so opening
/// this screen fresh (a cold reconnect mid-match, mid-innings-break, or
/// mid-over-boundary) renders the correct state immediately once the first
/// `scoring.stateSync` arrives, with no separate reconnect-recovery code
/// path to keep in sync with the live-event path.
class LiveScoringScreen extends ConsumerWidget {
  const LiveScoringScreen({super.key, required this.tournamentId, required this.matchId});

  final String tournamentId;
  final String matchId;

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
    if (organizationId == null) {
      return const Scaffold(body: Center(child: Text('No active organization')));
    }

    final key = (organizationId: organizationId, matchId: matchId);
    final controller = ref.read(scoringRoomControllerProvider(key).notifier);
    final roomState = ref.watch(scoringRoomControllerProvider(key));

    ref.listen<ScoringRoomState>(scoringRoomControllerProvider(key), (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        _snack(context, next.errorMessage!);
        controller.dismissError();
      }
    });

    final matchKey = (tournamentId: tournamentId, matchId: matchId);
    final match = ref.watch(matchDetailProvider(matchKey)).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(match != null ? '${match.homeTeamName ?? 'TBD'} vs ${match.awayTeamName ?? 'TBD'}' : 'Live scoring'),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: _ConnectionChip(status: roomState.connectionStatus))],
      ),
      body: SafeArea(child: _Body(tournamentId: tournamentId, matchId: matchId, match: match, controller: controller, roomState: roomState)),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.tournamentId, required this.matchId, required this.match, required this.controller, required this.roomState});

  final String tournamentId;
  final String matchId;
  final Match? match;
  final ScoringRoomController controller;
  final ScoringRoomState roomState;

  String _teamName(String? tournamentTeamId) {
    if (tournamentTeamId == null || match == null) return 'TBD';
    if (tournamentTeamId == match!.homeTournamentTeamId) return match!.homeTeamName ?? 'Home team';
    if (tournamentTeamId == match!.awayTournamentTeamId) return match!.awayTeamName ?? 'Away team';
    return 'Unknown team';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveState = roomState.liveState;
    if (liveState == null) {
      return roomState.connectionStatus == ScoringConnectionStatus.disconnected
          ? const Center(child: Text('Disconnected — reconnecting…'))
          : const Center(child: CircularProgressIndicator());
    }

    if (liveState.match.status == 'completed') {
      return _MatchCompletedView(
        liveState: liveState,
        teamName: _teamName,
        onDone: () => context.canPop() ? context.pop() : context.go(matchDetailPath(tournamentId, matchId)),
      );
    }

    final innings = liveState.currentInnings;
    if (innings == null) {
      return const Center(child: Text('Waiting for the innings to start…'));
    }

    if (innings.status == 'completed') {
      return _InningsCompletedView(
        liveState: liveState,
        innings: innings,
        teamName: _teamName,
        canStartNextInnings: liveState.innings.length == 1,
        onStartNextInnings: match == null
            ? null
            : () => context.push(
                  scoringSetupPath(tournamentId, matchId),
                  extra: ScoringSetupArgs(
                    match: match!,
                    isFirstInnings: false,
                    battingTournamentTeamId: innings.bowlingTournamentTeamId,
                    bowlingTournamentTeamId: innings.battingTournamentTeamId,
                  ),
                ),
      );
    }

    if (innings.currentOver == null) {
      return _NewBowlerPrompt(
        tournamentId: tournamentId,
        matchId: matchId,
        fieldingTournamentTeamId: innings.bowlingTournamentTeamId,
        fieldingTeamName: _teamName(innings.bowlingTournamentTeamId),
        excludeTeamPlayerId: controller.lastOverBowlerTeamPlayerId,
        onSubmit: controller.newBowler,
      );
    }

    return _ScoringBody(
      tournamentId: tournamentId,
      matchId: matchId,
      liveState: liveState,
      innings: innings,
      teamName: _teamName,
      controller: controller,
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.status});

  final ScoringConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ScoringConnectionStatus.connecting => ('Connecting…', Colors.orange),
      ScoringConnectionStatus.connected => ('Live', Colors.green),
      ScoringConnectionStatus.disconnected => ('Disconnected', Colors.red),
    };
    return Chip(
      label: Text(label),
      avatar: Icon(Icons.circle, size: 10, color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ---------------------------------------------------------------------
// Match completed
// ---------------------------------------------------------------------

class _MatchCompletedView extends StatelessWidget {
  const _MatchCompletedView({required this.liveState, required this.teamName, required this.onDone});

  final LiveScoringState liveState;
  final String Function(String?) teamName;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 56, color: Colors.amber),
            const SizedBox(height: 16),
            Text('Match complete', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            if (liveState.match.resultSummary != null)
              Text(liveState.match.resultSummary!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            for (final innings in liveState.innings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${teamName(innings.battingTournamentTeamId)}: ${innings.totalRuns}/${innings.totalWickets} (${innings.totalOversBowled} ov)'),
              ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onDone, child: const Text('Back to match')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Innings completed — prompt to start the next one
// ---------------------------------------------------------------------

class _InningsCompletedView extends StatelessWidget {
  const _InningsCompletedView({
    required this.liveState,
    required this.innings,
    required this.teamName,
    required this.canStartNextInnings,
    required this.onStartNextInnings,
  });

  final LiveScoringState liveState;
  final ScoringInningsSnapshot innings;
  final String Function(String?) teamName;
  final bool canStartNextInnings;
  final VoidCallback? onStartNextInnings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Innings ${innings.inningsNumber} complete', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${teamName(innings.battingTournamentTeamId)}: ${innings.totalRuns}/${innings.totalWickets} (${innings.totalOversBowled} ov)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            if (canStartNextInnings)
              FilledButton.icon(
                onPressed: onStartNextInnings,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start 2nd innings'),
              )
            else
              const Text('Both innings are complete — finalizing the result…'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// New-bowler prompt — shown whenever an over just completed and the next
// over's bowler hasn't been selected yet (currentOver == null). Rendered
// in place of the scoring UI so no ball can be recorded during this
// window, mirroring the backend's own enforcement.
// ---------------------------------------------------------------------

class _NewBowlerPrompt extends ConsumerStatefulWidget {
  const _NewBowlerPrompt({
    required this.tournamentId,
    required this.matchId,
    required this.fieldingTournamentTeamId,
    required this.fieldingTeamName,
    required this.excludeTeamPlayerId,
    required this.onSubmit,
  });

  final String tournamentId;
  final String matchId;
  final String fieldingTournamentTeamId;
  final String fieldingTeamName;
  final String? excludeTeamPlayerId;
  final void Function(String bowlerTeamPlayerId) onSubmit;

  @override
  ConsumerState<_NewBowlerPrompt> createState() => _NewBowlerPromptState();
}

class _NewBowlerPromptState extends ConsumerState<_NewBowlerPrompt> {
  String? _bowlerId;

  @override
  Widget build(BuildContext context) {
    final lineupAsync =
        ref.watch(scoringLineupProvider((tournamentId: widget.tournamentId, matchId: widget.matchId)));

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Over complete', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Select the bowler for the next over — ${widget.fieldingTeamName}'),
                const SizedBox(height: 16),
                lineupAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Text(
                    error is ApiException ? error.message : 'Failed to load Playing XI',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  data: (lineup) {
                    final options = (lineup.forTeam(widget.fieldingTournamentTeamId)?.playing ?? const <ScoringLineupPlayer>[])
                        .where((p) => p.teamPlayerId != widget.excludeTeamPlayerId)
                        .toList();
                    return DropdownButtonFormField<String>(
                      initialValue: _bowlerId,
                      decoration: const InputDecoration(labelText: 'Bowler'),
                      items: options.map((p) => DropdownMenuItem(value: p.teamPlayerId, child: Text(p.fullName))).toList(),
                      onChanged: (value) => setState(() => _bowlerId = value),
                    );
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _bowlerId == null ? null : () => widget.onSubmit(_bowlerId!),
                  child: const Text('Confirm bowler'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// The main scoring surface
// ---------------------------------------------------------------------

class _ScoringBody extends ConsumerStatefulWidget {
  const _ScoringBody({
    required this.tournamentId,
    required this.matchId,
    required this.liveState,
    required this.innings,
    required this.teamName,
    required this.controller,
  });

  final String tournamentId;
  final String matchId;
  final LiveScoringState liveState;
  final ScoringInningsSnapshot innings;
  final String Function(String?) teamName;
  final ScoringRoomController controller;

  @override
  ConsumerState<_ScoringBody> createState() => _ScoringBodyState();
}

class _ScoringBodyState extends ConsumerState<_ScoringBody> {
  bool _busy = false;

  void _recordRuns(int runs) {
    widget.controller.recordBall(runs: runs);
  }

  Future<void> _recordExtra(ScoringExtraType type) async {
    final runs = await showExtraRunsDialog(context, type);
    if (runs == null) return;
    widget.controller.recordBall(runs: runs, extraType: type.apiValue);
  }

  Future<void> _recordWicket() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final organizationId = ref.read(sessionControllerProvider).activeOrgId;
      final innings = widget.innings;

      // Best-effort: fetch the scorecard to know who's already been
      // dismissed this innings, so the incoming-batter picker doesn't
      // offer someone already out. The current crease pair is always
      // excluded regardless of whether this succeeds — see the task's own
      // guidance ("don't over-filter if that data isn't conveniently
      // available client-side — the backend validates this anyway").
      var dismissedIds = <String>{};
      if (organizationId != null) {
        try {
          final scorecard =
              await ref.read(scoringRepositoryProvider).getScorecard(organizationId, widget.tournamentId, widget.matchId);
          for (final card in scorecard.innings) {
            if (card.inningsId == innings.inningsId) {
              dismissedIds = card.batting.where((b) => b.isOut).map((b) => b.teamPlayerId).toSet();
              break;
            }
          }
        } catch (_) {
          // Ignored — see doc comment above.
        }
      }

      ScoringMatchLineup? lineup;
      try {
        lineup = await ref
            .read(scoringLineupProvider((tournamentId: widget.tournamentId, matchId: widget.matchId)).future);
      } catch (_) {
        // Ignored — dialog degrades to empty picker lists below.
      }

      if (!mounted) return;

      final fieldingXi = lineup?.forTeam(innings.bowlingTournamentTeamId)?.playing ?? const <ScoringLineupPlayer>[];
      final battingXi = lineup?.forTeam(innings.battingTournamentTeamId)?.playing ?? const <ScoringLineupPlayer>[];
      final crease = <String>{
        if (innings.striker != null) innings.striker!.teamPlayerId,
        if (innings.nonStriker != null) innings.nonStriker!.teamPlayerId,
      };
      final nextBatterOptions =
          battingXi.where((p) => !dismissedIds.contains(p.teamPlayerId) && !crease.contains(p.teamPlayerId)).toList();
      final wicketsAfter = innings.totalWickets + 1;

      final result = await showWicketDialog(
        context,
        strikerName: innings.striker?.fullName ?? 'Striker',
        strikerId: innings.striker?.teamPlayerId,
        nonStrikerName: innings.nonStriker?.fullName ?? 'Non-striker',
        nonStrikerId: innings.nonStriker?.teamPlayerId,
        fieldingXi: fieldingXi,
        nextBatterOptions: nextBatterOptions,
        requireNextBatter: wicketsAfter < 10,
      );
      if (result == null) return;

      widget.controller.recordBall(
        runs: result.runsCompleted,
        isWicket: true,
        dismissalType: result.dismissalType.apiValue,
        dismissedTeamPlayerId: result.dismissedTeamPlayerId,
        fielderTeamPlayerId: result.fielderTeamPlayerId,
        nextBatterTeamPlayerId: result.nextBatterTeamPlayerId,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undo() async {
    final lastBall = widget.innings.recentBalls.isNotEmpty ? widget.innings.recentBalls.last : null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undo last ball?'),
        content: Text(
          lastBall != null
              ? 'This will undo: ${_describeBall(lastBall)}'
              : 'This will undo the most recently recorded ball.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.controller.undoLastBall();
    }
  }

  @override
  Widget build(BuildContext context) {
    final innings = widget.innings;
    final target = widget.liveState.target;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _ScoreHeaderCard(innings: innings, teamName: widget.teamName(innings.battingTournamentTeamId), target: target),
        const SizedBox(height: 10),
        _BattersCard(innings: innings),
        const SizedBox(height: 10),
        _BowlerCard(innings: innings),
        const SizedBox(height: 10),
        _RecentBallsStrip(innings: innings),
        const SizedBox(height: 16),
        _RunButtonsGrid(onTap: _recordRuns),
        const SizedBox(height: 10),
        _ExtrasRow(onTap: _recordExtra),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negative,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _busy ? null : _recordWicket,
            child: const Text('WICKET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.negative,
              side: const BorderSide(color: AppColors.negative, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: innings.recentBalls.isEmpty ? null : _undo,
            child: const Text('UNDO LAST BALL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

String _describeBall(ScoringRecentBall b) {
  if (b.isWicket) {
    final label = dismissalTypeLabel(b.dismissalType);
    return label.isEmpty ? 'WICKET' : 'WICKET ($label)';
  }
  switch (b.extraType) {
    case 'wide':
      return b.runsExtra > 1 ? 'Wide + ${b.runsExtra - 1} run(s)' : 'Wide';
    case 'no_ball':
      return b.runsBatter > 0 ? 'No ball + ${b.runsBatter} run(s)' : 'No ball';
    case 'bye':
      return '${b.runsExtra} bye(s)';
    case 'leg_bye':
      return '${b.runsExtra} leg bye(s)';
    case 'penalty':
      return '${b.runsExtra} penalty run(s)';
    default:
      return b.runsBatter == 0 ? 'Dot ball' : '${b.runsBatter} run(s)';
  }
}

String _ballChip(ScoringRecentBall b) {
  if (b.isWicket) return 'W';
  switch (b.extraType) {
    case 'wide':
      return b.runsExtra > 1 ? 'wd+${b.runsExtra - 1}' : 'wd';
    case 'no_ball':
      return b.runsBatter > 0 ? 'nb+${b.runsBatter}' : 'nb';
    case 'bye':
      return 'b${b.runsExtra}';
    case 'leg_bye':
      return 'lb${b.runsExtra}';
    case 'penalty':
      return 'p${b.runsExtra}';
    default:
      return b.runsBatter == 0 ? '•' : '${b.runsBatter}';
  }
}

// ---------------------------------------------------------------------
// Display widgets
// ---------------------------------------------------------------------

class _ScoreHeaderCard extends StatelessWidget {
  const _ScoreHeaderCard({required this.innings, required this.teamName, required this.target});

  final ScoringInningsSnapshot innings;
  final String teamName;
  final int? target;

  @override
  Widget build(BuildContext context) {
    final needed = target != null ? target! - innings.totalRuns : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LivePill(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    teamName,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${innings.totalRuns}/${innings.totalWickets}',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1),
                ),
                const SizedBox(width: 12),
                Text(
                  '${innings.totalOversBowled} Overs',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (target != null) ...[
              const SizedBox(height: 10),
              Text(
                needed != null && needed > 0 ? 'Target $target — need $needed run${needed == 1 ? '' : 's'}' : 'Target $target',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BattersCard extends StatelessWidget {
  const _BattersCard({required this.innings});

  final ScoringInningsSnapshot innings;

  Widget _row(BuildContext context, ScoringBatterFigures? batter, {required bool isStriker}) {
    if (batter == null) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('—', style: TextStyle(color: AppColors.textMuted)));
    }
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isStriker ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (isStriker)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.sports_cricket, size: 16, color: AppColors.primary),
            ),
          Expanded(
            child: Text(
              batter.fullName,
              style: TextStyle(
                fontWeight: isStriker ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${batter.runs}(${batter.ballsFaced})',
            style: TextStyle(fontWeight: FontWeight.w700, color: isStriker ? AppColors.primary : AppColors.textPrimary),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(
              'SR ${batter.strikeRate.toStringAsFixed(1)}',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BATTING',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 0.5, color: AppColors.textSecondary),
            ),
            _row(context, innings.striker, isStriker: true),
            _row(context, innings.nonStriker, isStriker: false),
          ],
        ),
      ),
    );
  }
}

class _BowlerCard extends StatelessWidget {
  const _BowlerCard({required this.innings});

  final ScoringInningsSnapshot innings;

  @override
  Widget build(BuildContext context) {
    final over = innings.currentOver;
    final figures = over?.bowlerInningsFigures;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BOWLING',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 0.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    over?.bowler?.fullName ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (over != null)
                  Text(
                    'This over: ${over.runsConceded}-${over.wickets}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
            if (figures != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${figures.overs.toStringAsFixed(1)} - ${figures.maidens} - ${figures.runsConceded} - ${figures.wickets}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Per-value color coding for a recorded ball, matching the mockup's chip
/// legend: dot = gray, 1/2/3 = green, 4 = blue, 6 = purple, wide/no-ball
/// (and penalty) = amber, wicket = red. Byes/leg-byes fall back to the same
/// value scale as ordinary runs since the mockup doesn't call out a
/// separate color for them.
Color _ballColor(ScoringRecentBall b) {
  if (b.isWicket) return AppColors.negative;
  switch (b.extraType) {
    case 'wide':
    case 'no_ball':
    case 'penalty':
      return AppColors.amber;
    default:
      final value = (b.extraType == 'bye' || b.extraType == 'leg_bye') ? b.runsExtra : b.runsBatter;
      if (value == 0) return AppColors.textMuted;
      if (value == 4) return AppColors.info;
      if (value == 6) return AppColors.purple;
      return AppColors.primaryLight;
  }
}

class _RecentBallsStrip extends StatelessWidget {
  const _RecentBallsStrip({required this.innings});

  final ScoringInningsSnapshot innings;

  @override
  Widget build(BuildContext context) {
    final displayOver = innings.currentOver?.overNumber ??
        (innings.recentBalls.isNotEmpty ? innings.recentBalls.last.overNumber : null);
    final balls = displayOver == null
        ? const <ScoringRecentBall>[]
        : innings.recentBalls.where((b) => b.overNumber == displayOver).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'THIS OVER',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 0.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: balls.isEmpty
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('No balls bowled yet', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: balls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final b = balls[index];
                        return CircleAvatar(
                          radius: 18,
                          backgroundColor: _ballColor(b),
                          child: Text(
                            _ballChip(b),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunButtonsGrid extends StatelessWidget {
  const _RunButtonsGrid({required this.onTap});

  final void Function(int runs) onTap;

  static const _runs = [0, 1, 2, 3, 4, 6];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [
        for (final r in _runs)
          FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            onPressed: () => onTap(r),
            child: Text('$r'),
          ),
      ],
    );
  }
}

class _ExtrasRow extends StatelessWidget {
  const _ExtrasRow({required this.onTap});

  final void Function(ScoringExtraType type) onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final type in ScoringExtraType.values.where((t) => t != ScoringExtraType.penalty))
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amber,
                    side: const BorderSide(color: AppColors.amber),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                  onPressed: () => onTap(type),
                  child: Text(type.shortLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
