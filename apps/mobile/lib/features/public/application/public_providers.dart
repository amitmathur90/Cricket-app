import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../tournaments/data/models/points_table_row.dart';
import '../data/models/public_live_state.dart';
import '../data/models/public_match.dart';
import '../data/models/public_player_ranking.dart';
import '../data/models/public_post.dart';
import '../data/models/public_sponsor.dart';
import '../data/models/public_team.dart';
import '../data/models/public_tournament.dart';
import '../data/public_repository.dart';

/// Reuses the app-wide [apiClientProvider] rather than standing up a second
/// unauthenticated Dio client. This is safe both ways: a caller who's never
/// logged in has no stored token for [ApiClient]'s auth interceptor to
/// attach in the first place, and a logged-in admin using "Preview as Fan"
/// sends their token to a route that has no guard at all to read it (see
/// `PublicModule`'s doc comment on the backend) — either way the
/// `public/organizations/...` routes behave identically.
final publicRepositoryProvider = Provider<PublicRepository>((ref) {
  return PublicRepository(ref.watch(apiClientProvider));
});

final publicTournamentsProvider =
    FutureProvider.autoDispose.family<List<PublicTournament>, String>((ref, organizationId) {
  return ref.watch(publicRepositoryProvider).listTournaments(organizationId);
});

/// The tournament the Fan Home screen leads with, when the org has more than
/// one: prefers a `live` tournament (there's a match to headline), else the
/// soonest-starting `upcoming` one, else the most recently-started one
/// (`completed`/`draft`), else just the first in the list. Returns null only
/// when the org has no tournaments at all. Computed client-side — there's no
/// dedicated "current tournament" backend endpoint, and this heuristic only
/// affects which tournament's matches/points-table/teams the home screen
/// leads with, not which endpoints exist.
final publicPrimaryTournamentProvider =
    FutureProvider.autoDispose.family<PublicTournament?, String>((ref, organizationId) async {
  final tournaments = await ref.watch(publicTournamentsProvider(organizationId).future);
  if (tournaments.isEmpty) return null;

  PublicTournament? live;
  PublicTournament? soonestUpcoming;
  PublicTournament? latestOther;

  for (final t in tournaments) {
    if (t.status == 'live') {
      live ??= t;
    } else if (t.status == 'upcoming') {
      if (soonestUpcoming == null || t.startDate.compareTo(soonestUpcoming.startDate) < 0) {
        soonestUpcoming = t;
      }
    } else {
      if (latestOther == null || t.startDate.compareTo(latestOther.startDate) > 0) {
        latestOther = t;
      }
    }
  }

  return live ?? soonestUpcoming ?? latestOther ?? tournaments.first;
});

/// Family key for the tournament-scoped public providers below — a plain
/// record gets value equality for free, which is all `.family` needs.
typedef PublicTournamentScope = ({String organizationId, String tournamentId});

final publicTournamentProvider =
    FutureProvider.autoDispose.family<PublicTournament, PublicTournamentScope>((ref, scope) {
  return ref
      .watch(publicRepositoryProvider)
      .getTournament(scope.organizationId, scope.tournamentId);
});

final publicTeamsProvider =
    FutureProvider.autoDispose.family<List<PublicTeam>, PublicTournamentScope>((ref, scope) {
  return ref.watch(publicRepositoryProvider).getTeams(scope.organizationId, scope.tournamentId);
});

final publicMatchesProvider =
    FutureProvider.autoDispose.family<List<PublicMatch>, PublicTournamentScope>((ref, scope) {
  return ref.watch(publicRepositoryProvider).getMatches(scope.organizationId, scope.tournamentId);
});

final publicPointsTableProvider =
    FutureProvider.autoDispose.family<List<PointsTableRow>, PublicTournamentScope>((ref, scope) {
  return ref
      .watch(publicRepositoryProvider)
      .getPointsTable(scope.organizationId, scope.tournamentId);
});

typedef PublicLiveScoreScope = ({String organizationId, String tournamentId, String matchId});

/// Not auto-polled by itself — screens that want a "live-ish" feel
/// (`PublicLiveScoreCard`, `PublicLiveMatchScreen`) invalidate this provider
/// on a `Timer.periodic` (15–30s), matching the task's "REST poll, no
/// WebSocket" guidance for the public surface.
final publicLiveScoreProvider =
    FutureProvider.autoDispose.family<PublicLiveMatchState, PublicLiveScoreScope>((ref, scope) {
  return ref
      .watch(publicRepositoryProvider)
      .getLiveScore(scope.organizationId, scope.tournamentId, scope.matchId);
});

typedef PublicRankingsScope = ({
  String organizationId,
  PublicRankingMetric metric,
  int limit,
});

final publicRankingsProvider =
    FutureProvider.autoDispose.family<List<PublicPlayerRanking>, PublicRankingsScope>((
  ref,
  scope,
) {
  return ref
      .watch(publicRepositoryProvider)
      .getRankings(scope.organizationId, metric: scope.metric, limit: scope.limit);
});

final publicSponsorsProvider =
    FutureProvider.autoDispose.family<List<PublicSponsor>, String>((ref, organizationId) {
  return ref.watch(publicRepositoryProvider).getSponsors(organizationId);
});

typedef PublicPostsScope = ({String organizationId, PublicPostType? type});

final publicPostsProvider =
    FutureProvider.autoDispose.family<List<PublicPost>, PublicPostsScope>((ref, scope) {
  return ref.watch(publicRepositoryProvider).getPosts(scope.organizationId, type: scope.type);
});
