import '../../../core/network/api_client.dart';
import '../../tournaments/data/models/points_table_row.dart';
import 'models/public_live_state.dart';
import 'models/public_match.dart';
import 'models/public_player_ranking.dart';
import 'models/public_post.dart';
import 'models/public_sponsor.dart';
import 'models/public_team.dart';
import 'models/public_tournament.dart';

/// Talks to the fully-unauthenticated `public/organizations/:organizationId/...`
/// surface (apps/backend/src/modules/public/) — the mobile app's "browse as
/// a fan" section. See `PublicModule`'s doc comment on the backend for why no
/// auth guard is applied to any of these routes; on the client side that
/// means [ApiClient] is reused as-is (see `public_providers.dart`'s doc
/// comment) rather than standing up a second, bare Dio instance — a
/// logged-out caller simply has no token to attach, and an admin previewing
/// their own org's fan view sends one harmlessly (the backend ignores it,
/// there being no guard to read it).
///
/// Every method here reuses [ApiClient.get] — this surface is read-only,
/// there is no public write path anywhere in `PublicModule`.
class PublicRepository {
  PublicRepository(this._apiClient);

  final ApiClient _apiClient;

  String _base(String organizationId) => '/public/organizations/$organizationId';

  Future<List<PublicTournament>> listTournaments(String organizationId) async {
    final response = await _apiClient.get('${_base(organizationId)}/tournaments');
    return (response.data as List<dynamic>)
        .map((e) => PublicTournament.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PublicTournament> getTournament(String organizationId, String tournamentId) async {
    final response = await _apiClient.get('${_base(organizationId)}/tournaments/$tournamentId');
    return PublicTournament.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<PublicTeam>> getTeams(String organizationId, String tournamentId) async {
    final response =
        await _apiClient.get('${_base(organizationId)}/tournaments/$tournamentId/teams');
    return (response.data as List<dynamic>)
        .map((e) => PublicTeam.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PublicMatch>> getMatches(String organizationId, String tournamentId) async {
    final response =
        await _apiClient.get('${_base(organizationId)}/tournaments/$tournamentId/matches');
    return (response.data as List<dynamic>)
        .map((e) => PublicMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Already sorted by `position` ascending by the backend — see
  /// `PointsTableRow`'s doc comment. Reuses the authenticated
  /// `PointsTableRow` model verbatim: `getPointsTable`'s computed result is
  /// returned unmodified by the public endpoint too (see the backend
  /// controller's doc comment — every field it returns was already
  /// public-safe with nothing to redact), so the two responses are
  /// byte-for-byte the same shape.
  Future<List<PointsTableRow>> getPointsTable(String organizationId, String tournamentId) async {
    final response =
        await _apiClient.get('${_base(organizationId)}/tournaments/$tournamentId/points-table');
    return (response.data as List<dynamic>)
        .map((e) => PointsTableRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET .../tournaments/:tournamentId/live-score/:matchId` — a REST
  /// snapshot for the "LIVE NOW" card and the public match view, meant to be
  /// polled periodically rather than pushed over a socket (see
  /// `PublicLiveMatchState`'s doc comment).
  Future<PublicLiveMatchState> getLiveScore(
    String organizationId,
    String tournamentId,
    String matchId,
  ) async {
    final response = await _apiClient
        .get('${_base(organizationId)}/tournaments/$tournamentId/live-score/$matchId');
    return PublicLiveMatchState.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<PublicPlayerRanking>> getRankings(
    String organizationId, {
    PublicRankingMetric? metric,
    int? limit,
  }) async {
    final response = await _apiClient.get(
      '${_base(organizationId)}/players/rankings',
      queryParameters: {
        if (metric != null) 'metric': metric.apiValue,
        if (limit != null) 'limit': limit,
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => PublicPlayerRanking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Only sponsors with `visibleOnApp: true`, sorted by company name —
  /// filtered/sorted server-side.
  Future<List<PublicSponsor>> getSponsors(String organizationId) async {
    final response = await _apiClient.get('${_base(organizationId)}/sponsors');
    return (response.data as List<dynamic>)
        .map((e) => PublicSponsor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Published posts only (drafts / future-scheduled excluded server-side),
  /// newest first. `type` filters to one of news/photo/video;
  /// `tournamentId` filters to one tournament's posts. Both optional and
  /// combinable, matching `PublicPostsController.findAll`'s query params.
  Future<List<PublicPost>> getPosts(
    String organizationId, {
    PublicPostType? type,
    String? tournamentId,
  }) async {
    final response = await _apiClient.get(
      '${_base(organizationId)}/posts',
      queryParameters: {
        if (type != null) 'type': type.apiValue,
        if (tournamentId != null) 'tournamentId': tournamentId,
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => PublicPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
