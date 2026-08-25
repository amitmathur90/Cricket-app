import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../auth/application/session_controller.dart';
import '../../matches/application/matches_providers.dart';
import '../../matches/data/models/match.dart';
import '../application/scoring_providers.dart';
import '../data/models/scoring_lineup.dart';

/// Navigation payload for [ScoringSetupScreen], passed via go_router
/// `extra` — bundles everything the screen needs beyond the path params
/// (`tournamentId`/`matchId`) since go_router only carries one `extra`
/// object per route.
class ScoringSetupArgs {
  const ScoringSetupArgs({
    required this.match,
    required this.isFirstInnings,
    this.battingTournamentTeamId,
    this.bowlingTournamentTeamId,
  }) : assert(
          isFirstInnings || (battingTournamentTeamId != null && bowlingTournamentTeamId != null),
          'battingTournamentTeamId/bowlingTournamentTeamId are required when starting the second innings',
        );

  /// Used for display (team names) in both flows, and to offer the
  /// home/away choice for the first-innings flow.
  final Match match;

  final bool isFirstInnings;

  /// Second-innings flow only — pre-derived by the caller by swapping
  /// innings 1's batting/bowling teams (see LiveScoringScreen).
  final String? battingTournamentTeamId;
  final String? bowlingTournamentTeamId;
}

/// One-time setup step before scoring can begin: batting team (first
/// innings only — the second innings' batting team is just whoever bowled
/// first, no choice to make) plus opening striker/non-striker/bowler, all
/// constrained to the relevant team's actual Playing XI. Deliberately a
/// single dedicated screen rather than a multi-step wizard — per the task
/// brief, this is a one-time setup step, not the main interaction surface.
class ScoringSetupScreen extends ConsumerStatefulWidget {
  const ScoringSetupScreen({
    super.key,
    required this.tournamentId,
    required this.matchId,
    required this.args,
  });

  final String tournamentId;
  final String matchId;
  final ScoringSetupArgs args;

  @override
  ConsumerState<ScoringSetupScreen> createState() => _ScoringSetupScreenState();
}

class _ScoringSetupScreenState extends ConsumerState<ScoringSetupScreen> {
  String? _battingTournamentTeamId;
  String? _strikerId;
  String? _nonStrikerId;
  String? _bowlerId;
  final _oversLimitController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (!widget.args.isFirstInnings) {
      _battingTournamentTeamId = widget.args.battingTournamentTeamId;
    }
  }

  @override
  void dispose() {
    _oversLimitController.dispose();
    super.dispose();
  }

  String? get _bowlingTournamentTeamId {
    if (!widget.args.isFirstInnings) return widget.args.bowlingTournamentTeamId;
    final match = widget.args.match;
    if (_battingTournamentTeamId == null) return null;
    if (_battingTournamentTeamId == match.homeTournamentTeamId) return match.awayTournamentTeamId;
    if (_battingTournamentTeamId == match.awayTournamentTeamId) return match.homeTournamentTeamId;
    return null;
  }

  String _teamName(String? tournamentTeamId) {
    final match = widget.args.match;
    if (tournamentTeamId == null) return 'TBD';
    if (tournamentTeamId == match.homeTournamentTeamId) return match.homeTeamName ?? 'Home team';
    if (tournamentTeamId == match.awayTournamentTeamId) return match.awayTeamName ?? 'Away team';
    return 'Unknown team';
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final battingId = _battingTournamentTeamId;
    final bowlingId = _bowlingTournamentTeamId;
    if (battingId == null || bowlingId == null) {
      _snack('Select the batting team first');
      return;
    }
    if (_strikerId == null || _nonStrikerId == null || _bowlerId == null) {
      _snack('Select the opening striker, non-striker, and bowler');
      return;
    }
    if (_strikerId == _nonStrikerId) {
      _snack('Striker and non-striker must be different players');
      return;
    }

    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) {
      _snack('No active organization');
      return;
    }

    setState(() => _busy = true);
    try {
      final repo = ref.read(scoringRepositoryProvider);
      if (widget.args.isFirstInnings) {
        final oversText = _oversLimitController.text.trim();
        await repo.startMatch(
          organizationId,
          widget.tournamentId,
          widget.matchId,
          battingFirstTournamentTeamId: battingId,
          oversLimit: oversText.isEmpty ? null : int.tryParse(oversText),
          openingStrikerTeamPlayerId: _strikerId!,
          openingNonStrikerTeamPlayerId: _nonStrikerId!,
          openingBowlerTeamPlayerId: _bowlerId!,
        );
        ref.invalidate(matchDetailProvider((tournamentId: widget.tournamentId, matchId: widget.matchId)));
        ref.invalidate(matchesListProvider);
        if (!mounted) return;
        context.pushReplacement(liveScoringPath(widget.tournamentId, widget.matchId));
      } else {
        await repo.startInnings(
          organizationId,
          widget.tournamentId,
          widget.matchId,
          openingStrikerTeamPlayerId: _strikerId!,
          openingNonStrikerTeamPlayerId: _nonStrikerId!,
          openingBowlerTeamPlayerId: _bowlerId!,
        );
        if (!mounted) return;
        // Pops back to LiveScoringScreen, whose socket (already joined to
        // this match's room) picks up the resulting scoring.inningsStarted
        // broadcast on its own — no separate refresh needed here.
        context.pop();
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.args.match;
    final lineupAsync =
        ref.watch(scoringLineupProvider((tournamentId: widget.tournamentId, matchId: widget.matchId)));

    return Scaffold(
      appBar: AppBar(title: Text(widget.args.isFirstInnings ? 'Start scoring' : 'Start 2nd innings')),
      body: lineupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load Playing XI'),
        ),
        data: (lineup) {
          final battingXi = lineup.forTeam(_battingTournamentTeamId)?.playing ?? const <ScoringLineupPlayer>[];
          final bowlingXi = lineup.forTeam(_bowlingTournamentTeamId)?.playing ?? const <ScoringLineupPlayer>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.args.isFirstInnings) ...[
                Text('Batting first', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                RadioGroup<String?>(
                  groupValue: _battingTournamentTeamId,
                  onChanged: (value) => setState(() {
                    _battingTournamentTeamId = value;
                    _strikerId = null;
                    _nonStrikerId = null;
                    _bowlerId = null;
                  }),
                  child: Column(
                    children: [
                      if (match.homeTournamentTeamId != null)
                        RadioListTile<String?>(
                          title: Text(match.homeTeamName ?? 'Home team'),
                          value: match.homeTournamentTeamId,
                        ),
                      if (match.awayTournamentTeamId != null)
                        RadioListTile<String?>(
                          title: Text(match.awayTeamName ?? 'Away team'),
                          value: match.awayTournamentTeamId,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _oversLimitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Overs limit (optional)',
                    hintText: 'Defaults from the tournament format',
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                Text(
                  '${_teamName(_battingTournamentTeamId)} bat, ${_teamName(_bowlingTournamentTeamId)} bowl',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
              ],
              Text('Opening batters — ${_teamName(_battingTournamentTeamId)}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _strikerId,
                decoration: const InputDecoration(labelText: 'Striker'),
                items: battingXi
                    .map((p) => DropdownMenuItem(value: p.teamPlayerId, child: Text(p.fullName)))
                    .toList(),
                onChanged: battingXi.isEmpty ? null : (value) => setState(() => _strikerId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _nonStrikerId,
                decoration: const InputDecoration(labelText: 'Non-striker'),
                items: battingXi
                    .map((p) => DropdownMenuItem(value: p.teamPlayerId, child: Text(p.fullName)))
                    .toList(),
                onChanged: battingXi.isEmpty ? null : (value) => setState(() => _nonStrikerId = value),
              ),
              if (battingXi.isEmpty && _battingTournamentTeamId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'No Playing XI set for this team yet — set it from the match detail screen first.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 20),
              Text('Opening bowler — ${_teamName(_bowlingTournamentTeamId)}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _bowlerId,
                decoration: const InputDecoration(labelText: 'Bowler'),
                items:
                    bowlingXi.map((p) => DropdownMenuItem(value: p.teamPlayerId, child: Text(p.fullName))).toList(),
                onChanged: bowlingXi.isEmpty ? null : (value) => setState(() => _bowlerId = value),
              ),
              if (bowlingXi.isEmpty && _bowlingTournamentTeamId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'No Playing XI set for this team yet — set it from the match detail screen first.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.args.isFirstInnings ? 'Start match' : 'Start 2nd innings'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
