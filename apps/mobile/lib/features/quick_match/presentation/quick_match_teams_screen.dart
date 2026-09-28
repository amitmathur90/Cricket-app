import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../matches/application/matches_providers.dart';
import '../application/quick_match_providers.dart';

/// Quick Match entry point — CricHeroes-style "Select playing teams": pick
/// or create Team A and Team B (each an ad-hoc team registered into the
/// caller's hidden per-org Quick Match tournament — see
/// quickMatchTournamentIdProvider), then continue straight to the normal
/// match-creation form pre-filled with both teams. Everything after that
/// (lineup, toss, live scoring) is the exact same, already-built flow a
/// tournament match uses.
class QuickMatchTeamsScreen extends ConsumerStatefulWidget {
  const QuickMatchTeamsScreen({super.key});

  @override
  ConsumerState<QuickMatchTeamsScreen> createState() => _QuickMatchTeamsScreenState();
}

class _QuickMatchTeamsScreenState extends ConsumerState<QuickMatchTeamsScreen> {
  TournamentTeamOption? _teamA;
  TournamentTeamOption? _teamB;

  Future<void> _pickTeam(String tournamentId, {required bool isTeamA}) async {
    final excludeId = isTeamA ? _teamB?.tournamentTeamId : _teamA?.tournamentTeamId;
    final result = await context.push<TournamentTeamOption>(
      quickMatchPickTeamPath(tournamentId),
      extra: excludeId,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (isTeamA) {
        _teamA = result;
      } else {
        _teamB = result;
      }
    });
  }

  void _next(String tournamentId) {
    final teamA = _teamA;
    final teamB = _teamB;
    if (teamA == null || teamB == null) return;
    context.push(
      matchFormPath(tournamentId),
      extra: QuickMatchTeams(
        homeTournamentTeamId: teamA.tournamentTeamId,
        awayTournamentTeamId: teamB.tournamentTeamId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tournamentAsync = ref.watch(quickMatchTournamentIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select playing teams')),
      body: tournamentAsync.when(
        data: (tournamentId) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _TeamSlot(
                label: 'Team A',
                team: _teamA,
                onTap: () => _pickTeam(tournamentId, isTeamA: true),
              ),
              const SizedBox(height: 8),
              const Text('vs', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _TeamSlot(
                label: 'Team B',
                team: _teamB,
                onTap: () => _pickTeam(tournamentId, isTeamA: false),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _teamA != null && _teamB != null ? () => _next(tournamentId) : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load'),
        ),
      ),
    );
  }
}

class _TeamSlot extends StatelessWidget {
  const _TeamSlot({required this.label, required this.team, required this.onTap});

  final String label;
  final TournamentTeamOption? team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              child: Icon(team == null ? Icons.add : Icons.shield),
            ),
            const SizedBox(height: 8),
            Text(team?.teamName ?? 'Select $label'),
          ],
        ),
      ),
    );
  }
}
