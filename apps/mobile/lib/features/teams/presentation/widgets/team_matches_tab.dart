import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../matches/application/matches_providers.dart';
import '../../../matches/data/models/match.dart';
import '../../../matches/presentation/widgets/match_card.dart';
import '../../data/models/team.dart';

/// This team's matches within one tournament — filters the tournament's
/// full matches list down to fixtures where this team is playing home or
/// away.
///
/// Matched by team *name* (case-insensitive), not `tournamentTeamId`: the
/// same limitation `TeamAuctionTab` already documents applies here — there
/// is no direct `teamId -> tournamentTeamId` lookup exposed by the backend.
/// Rather than reach for that missing id, this reuses what the matches API
/// already resolves server-side (`homeTeamName`/`awayTeamName`, see
/// MatchesService.toResponse) and compares against this team's own `name`.
/// That's the same identifier the backend itself surfaces elsewhere for
/// exactly this purpose (`soldToTeamName` on auction bids/pool entries), so
/// it's consistent with the rest of this app, not a one-off workaround —
/// and it sidesteps needing an auction session to exist at all (unlike the
/// match form's team dropdowns, which do need tournamentTeamId and so fall
/// back to the auction-report technique — see tournamentTeamsProvider's doc
/// comment).
class TeamMatchesTab extends ConsumerWidget {
  const TeamMatchesTab({super.key, required this.team, required this.tournamentId});

  final Team team;
  final String tournamentId;

  void _openMatch(BuildContext context, Match match) {
    context.push(matchDetailPath(tournamentId, match.id), extra: match);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MatchesListKey key = (tournamentId: tournamentId, filter: null);
    final matchesAsync = ref.watch(matchesListProvider(key));

    return matchesAsync.when(
      data: (matches) {
        final teamName = team.name.trim().toLowerCase();
        final teamMatches = matches
            .where(
              (m) =>
                  (m.homeTeamName?.trim().toLowerCase() ?? '') == teamName ||
                  (m.awayTeamName?.trim().toLowerCase() ?? '') == teamName,
            )
            .toList();

        if (teamMatches.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '${team.name} has no matches scheduled in this tournament yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).disabledColor),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: teamMatches.length,
          itemBuilder: (context, index) {
            final match = teamMatches[index];
            return MatchCard(match: match, onTap: () => _openMatch(context, match));
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(error is ApiException ? error.message : 'Failed to load matches'),
      ),
    );
  }
}
