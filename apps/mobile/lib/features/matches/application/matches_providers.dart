import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../../tournaments/application/tournaments_providers.dart';
import '../data/match_lineup_repository.dart';
import '../data/matches_repository.dart';
import '../data/models/match.dart';
import '../data/models/match_lineup.dart';

final matchesRepositoryProvider = Provider<MatchesRepository>((ref) {
  return MatchesRepository(ref.watch(apiClientProvider));
});

final matchLineupRepositoryProvider = Provider<MatchLineupRepository>((ref) {
  return MatchLineupRepository(ref.watch(apiClientProvider));
});

/// Optional filters for [matchesListProvider], mirroring
/// `MatchesController.findAll`'s `status`/`from`/`to` query params. Not
/// currently driven by any screen (the Matches tab fetches everything and
/// filters Upcoming/Past client-side, see MatchesTab's doc comment) but
/// kept as part of the provider's contract since the backend route supports
/// it.
typedef MatchesFilter = ({String? status, DateTime? from, DateTime? to});

typedef MatchesListKey = ({String tournamentId, MatchesFilter? filter});

/// All matches for one tournament, optionally filtered.
final matchesListProvider =
    FutureProvider.autoDispose.family<List<Match>, MatchesListKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  final filter = key.filter;
  return ref.watch(matchesRepositoryProvider).list(
        organizationId,
        key.tournamentId,
        status: filter?.status,
        from: filter?.from,
        to: filter?.to,
      );
});

typedef MatchDetailKey = ({String tournamentId, String matchId});

final matchDetailProvider =
    FutureProvider.autoDispose.family<Match, MatchDetailKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(matchesRepositoryProvider).get(organizationId, key.tournamentId, key.matchId);
});

/// Both teams' Playing XI + substitutes for one match — backs
/// LineupSelectionScreen's pre-population (edit flow) and could equally back
/// a read-only lineup summary elsewhere. Empty/null sides just mean "no
/// lineup set yet for that team", not an error.
final matchLineupProvider =
    FutureProvider.autoDispose.family<MatchLineupResponse, MatchDetailKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(matchLineupRepositoryProvider).getLineup(organizationId, key.tournamentId, key.matchId);
});

/// One tournament-registered team, resolved with its `tournament_teams` id
/// (needed for match home/away assignment), its plain org-level `teamId`
/// (needed for roster lookups, which are keyed by team+tournament — see
/// TeamsRepository.getRoster), and display name.
typedef TournamentTeamOption = ({String tournamentTeamId, String teamId, String teamName});

/// Teams registered to a tournament — backs the match form's home/away team
/// dropdowns. Backed by `GET .../tournaments/:tournamentId/teams`
/// (`TournamentsRepository.getTeams`), which lists every `tournament_teams`
/// row for the tournament directly — no auction session required. (An
/// earlier version of this provider derived teams from the tournament's
/// most recent auction session report, since that was the only endpoint
/// that returned tournament_teams ids + display names together at the
/// time; that workaround meant a match couldn't get real teams assigned
/// until an auction had run. The dedicated endpoint replaces it.)
final tournamentTeamsProvider =
    FutureProvider.autoDispose.family<List<TournamentTeamOption>, String>((ref, tournamentId) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  final rows = await ref.watch(tournamentsRepositoryProvider).getTeams(organizationId, tournamentId);
  return rows
      .map((r) => (
            tournamentTeamId: r['tournamentTeamId'] as String,
            teamId: r['teamId'] as String,
            teamName: r['teamName'] as String,
          ))
      .toList();
});
