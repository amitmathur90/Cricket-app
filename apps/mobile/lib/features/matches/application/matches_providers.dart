import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auction/application/auction_providers.dart';
import '../../auth/application/session_controller.dart';
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
/// (needed for match home/away assignment) and display name.
typedef TournamentTeamOption = ({String tournamentTeamId, String teamName});

/// Teams registered to a tournament — backs the match form's home/away team
/// dropdowns.
///
/// There is currently **no backend GET endpoint** that lists a tournament's
/// `tournament_teams` rows directly (see `TeamsController` — only
/// `POST .../register` and `GET .../roster` exist, neither of which lists
/// every team registered to a tournament). This is the exact same gap
/// `TeamAuctionTab` already works around (see its doc comment): the only
/// place `tournament_teams` ids + display names come back together is
/// `AuctionService.getReport`, which itself needs an existing auction
/// session id to call. So this provider reuses that same technique — look
/// up the tournament's most recent auction session and read its report's
/// `teams[]` (which the backend populates from every `tournament_teams` row
/// for the tournament, not just teams added to that session's pool).
///
/// If the tournament has no auction session yet, this returns an empty
/// list and the match form degrades to TBD-vs-TBD-only, which the backend
/// explicitly documents as a valid match (see CreateMatchDto's doc
/// comment) — a genuine backend/data gap being surfaced honestly, not a
/// client shortcut.
final tournamentTeamsProvider =
    FutureProvider.autoDispose.family<List<TournamentTeamOption>, String>((ref, tournamentId) async {
  final sessions = await ref.watch(auctionSessionsListProvider(tournamentId).future);
  if (sessions.isEmpty) return const [];
  final latest = sessions.first;
  final report = await ref.watch(
    auctionReportProvider((tournamentId: tournamentId, sessionId: latest.id)).future,
  );
  return report.teams
      .map((t) => (tournamentTeamId: t.tournamentTeamId, teamName: t.teamName))
      .toList();
});
