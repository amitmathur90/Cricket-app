import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../application/matches_providers.dart';
import '../../data/models/match_lineup.dart';

/// Playing XI tab of `MatchCenterScreen` — both teams' Playing XI +
/// substitutes, reusing `MatchLineupRepository.getLineup` via the existing
/// `matchLineupProvider` (features/matches/application/matches_providers.dart)
/// exactly as the task calls for. Player names come from the same response's
/// joined `teamPlayer.player` data (see `TeamLineup.playingPlayers`/
/// `.substitutePlayers`, extended in match_lineup.dart for this tab) rather
/// than a second roster round trip.
class MatchPlayingXiTab extends ConsumerWidget {
  const MatchPlayingXiTab({super.key, required this.tournamentId, required this.matchId});

  final String tournamentId;
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (tournamentId: tournamentId, matchId: matchId);
    final matchAsync = ref.watch(matchDetailProvider(key));
    final lineupAsync = ref.watch(matchLineupProvider(key));

    if (matchAsync.isLoading || lineupAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (matchAsync.hasError) {
      final error = matchAsync.error;
      return Center(child: Text(error is ApiException ? error.message : 'Failed to load match'));
    }
    if (lineupAsync.hasError) {
      final error = lineupAsync.error;
      return Center(child: Text(error is ApiException ? error.message : 'Failed to load lineup'));
    }

    final match = matchAsync.value!;
    final lineup = lineupAsync.value!;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(matchLineupProvider(key).future),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _TeamSection(teamName: match.homeTeamName ?? 'Home team (TBD)', lineup: lineup.home),
          const SizedBox(height: 20),
          _TeamSection(teamName: match.awayTeamName ?? 'Away team (TBD)', lineup: lineup.away),
        ],
      ),
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.teamName, required this.lineup});

  final String teamName;
  final TeamLineup? lineup;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(teamName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (lineup == null || (lineup!.playingPlayers.isEmpty && lineup!.substitutePlayers.isEmpty))
              Text(
                'No lineup set for this team yet.',
                style: TextStyle(color: Theme.of(context).disabledColor),
              )
            else ...[
              Text('Playing XI (${lineup!.playingPlayers.length})', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              if (lineup!.playingPlayers.isEmpty)
                const Text('No playing XI selected.')
              else
                for (var i = 0; i < lineup!.playingPlayers.length; i++)
                  _PlayerLine(index: i + 1, name: lineup!.playingPlayers[i].fullName),
              const SizedBox(height: 12),
              Text('Substitutes (${lineup!.substitutePlayers.length})', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              if (lineup!.substitutePlayers.isEmpty)
                const Text('No substitutes selected.')
              else
                for (final player in lineup!.substitutePlayers)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• ${player.fullName}'),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayerLine extends StatelessWidget {
  const _PlayerLine({required this.index, required this.name});

  final int index;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text('$index. $name'),
    );
  }
}
