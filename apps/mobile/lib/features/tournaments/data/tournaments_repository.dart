import '../../../core/network/api_client.dart';
import 'models/points_table_row.dart';
import 'models/tournament.dart';
import 'models/tournament_awards.dart';

/// Talks to `TournamentsController`
/// (apps/backend/src/modules/tournaments) — all routes are nested under
/// `/organizations/:organizationId/tournaments`.
///
/// `create`/`update` both accept the full set of optional fields from
/// `CreateTournamentDto`/`UpdateTournamentDto` (the wizard collects all 5
/// steps client-side and submits once on "Save as draft"/"Publish" — see
/// `CreateTournamentScreen`'s doc comment for why). `update` additionally
/// accepts `status`, matching `UpdateTournamentDto`.
class TournamentsRepository {
  TournamentsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Tournament>> list(String organizationId) async {
    final response = await _apiClient.get('/organizations/$organizationId/tournaments');
    return (response.data as List<dynamic>)
        .map((e) => Tournament.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Tournament> getById(String organizationId, String tournamentId) async {
    final response =
        await _apiClient.get('/organizations/$organizationId/tournaments/$tournamentId');
    return Tournament.fromJson(response.data as Map<String, dynamic>);
  }

  /// `GET .../tournaments/:tournamentId/points-table` — computed standings,
  /// already sorted by position ascending by the backend (see
  /// `PointsTableRow`'s doc comment).
  Future<List<PointsTableRow>> getPointsTable(String organizationId, String tournamentId) async {
    final response =
        await _apiClient.get('/organizations/$organizationId/tournaments/$tournamentId/points-table');
    return (response.data as List<dynamic>)
        .map((e) => PointsTableRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET .../tournaments/:tournamentId/awards` — computed tournament
  /// awards (Player of the Tournament, Man of the Match per completed
  /// match, Best Batsman/Bowler/Fielder/All-Rounder, Emerging Player, Best
  /// Captain), same "derived on read, never persisted" philosophy as
  /// [getPointsTable].
  Future<TournamentAwardsResponse> getAwards(String organizationId, String tournamentId) async {
    final response =
        await _apiClient.get('/organizations/$organizationId/tournaments/$tournamentId/awards');
    return TournamentAwardsResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Tournament> create(
    String organizationId, {
    required String name,
    required TournamentFormat format,
    required String startDate,
    required String endDate,
    bool? auctionEnabled,
    // Basic info
    String? logoUrl,
    String? description,
    String? organizerName,
    String? contactEmail,
    String? contactPhone,
    // Tournament details
    String? location,
    int? numberOfTeams,
    int? maxPlayersPerTeam,
    // Rules
    String? tournamentRules,
    String? matchRules,
    String? pointsSystem,
    String? tieBreakerRules,
    // Registration
    String? registrationOpensAt,
    String? registrationClosesAt,
    num? playerRegistrationFee,
    num? teamRegistrationFee,
  }) async {
    final response = await _apiClient.post(
      '/organizations/$organizationId/tournaments',
      data: {
        'name': name,
        'format': format.apiValue,
        'startDate': startDate,
        'endDate': endDate,
        if (auctionEnabled != null) 'auctionEnabled': auctionEnabled,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (description != null) 'description': description,
        if (organizerName != null) 'organizerName': organizerName,
        if (contactEmail != null) 'contactEmail': contactEmail,
        if (contactPhone != null) 'contactPhone': contactPhone,
        if (location != null) 'location': location,
        if (numberOfTeams != null) 'numberOfTeams': numberOfTeams,
        if (maxPlayersPerTeam != null) 'maxPlayersPerTeam': maxPlayersPerTeam,
        if (tournamentRules != null) 'tournamentRules': tournamentRules,
        if (matchRules != null) 'matchRules': matchRules,
        if (pointsSystem != null) 'pointsSystem': pointsSystem,
        if (tieBreakerRules != null) 'tieBreakerRules': tieBreakerRules,
        if (registrationOpensAt != null) 'registrationOpensAt': registrationOpensAt,
        if (registrationClosesAt != null) 'registrationClosesAt': registrationClosesAt,
        if (playerRegistrationFee != null) 'playerRegistrationFee': playerRegistrationFee,
        if (teamRegistrationFee != null) 'teamRegistrationFee': teamRegistrationFee,
      },
    );
    return Tournament.fromJson(response.data as Map<String, dynamic>);
  }

  /// PATCHes any subset of a tournament's fields (`UpdateTournamentDto` —
  /// every field, including `status`, is optional). Used by the edit-mode
  /// wizard; `status`-only calls (e.g. publishing via [setStatus]) go
  /// through this too.
  Future<Tournament> update(
    String organizationId,
    String tournamentId, {
    String? name,
    TournamentFormat? format,
    String? startDate,
    String? endDate,
    bool? auctionEnabled,
    String? status,
    // Basic info
    String? logoUrl,
    String? description,
    String? organizerName,
    String? contactEmail,
    String? contactPhone,
    // Tournament details
    String? location,
    int? numberOfTeams,
    int? maxPlayersPerTeam,
    // Rules
    String? tournamentRules,
    String? matchRules,
    String? pointsSystem,
    String? tieBreakerRules,
    // Registration
    String? registrationOpensAt,
    String? registrationClosesAt,
    num? playerRegistrationFee,
    num? teamRegistrationFee,
  }) async {
    final response = await _apiClient.patch(
      '/organizations/$organizationId/tournaments/$tournamentId',
      data: {
        if (name != null) 'name': name,
        if (format != null) 'format': format.apiValue,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (auctionEnabled != null) 'auctionEnabled': auctionEnabled,
        if (status != null) 'status': status,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (description != null) 'description': description,
        if (organizerName != null) 'organizerName': organizerName,
        if (contactEmail != null) 'contactEmail': contactEmail,
        if (contactPhone != null) 'contactPhone': contactPhone,
        if (location != null) 'location': location,
        if (numberOfTeams != null) 'numberOfTeams': numberOfTeams,
        if (maxPlayersPerTeam != null) 'maxPlayersPerTeam': maxPlayersPerTeam,
        if (tournamentRules != null) 'tournamentRules': tournamentRules,
        if (matchRules != null) 'matchRules': matchRules,
        if (pointsSystem != null) 'pointsSystem': pointsSystem,
        if (tieBreakerRules != null) 'tieBreakerRules': tieBreakerRules,
        if (registrationOpensAt != null) 'registrationOpensAt': registrationOpensAt,
        if (registrationClosesAt != null) 'registrationClosesAt': registrationClosesAt,
        if (playerRegistrationFee != null) 'playerRegistrationFee': playerRegistrationFee,
        if (teamRegistrationFee != null) 'teamRegistrationFee': teamRegistrationFee,
      },
    );
    return Tournament.fromJson(response.data as Map<String, dynamic>);
  }

  /// Convenience wrapper over [update] for the wizard's "Publish" action.
  Future<Tournament> setStatus(String organizationId, String tournamentId, String status) {
    return update(organizationId, tournamentId, status: status);
  }

  Future<void> delete(String organizationId, String tournamentId) async {
    await _apiClient.delete('/organizations/$organizationId/tournaments/$tournamentId');
  }

  /// `GET .../tournaments/:tournamentId/teams` — the tournament's registered
  /// teams (`tournament_teams` rows), id + display name. Lets the match
  /// form assign home/away teams directly, with no auction session
  /// required first.
  Future<List<Map<String, dynamic>>> getTeams(String organizationId, String tournamentId) async {
    final response =
        await _apiClient.get('/organizations/$organizationId/tournaments/$tournamentId/teams');
    return (response.data as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
