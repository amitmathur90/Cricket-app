import '../../../core/network/api_client.dart';
import 'models/roster_entry.dart';
import 'models/team.dart';

/// Talks to `TeamsController` (apps/backend/src/modules/teams) — org-level
/// team CRUD under `/organizations/:organizationId/teams`, plus a
/// tournament-team's roster (squad) read/write:
/// `GET .../teams/:teamId/tournaments/:tournamentId/roster` and
/// `PATCH .../roster/:teamPlayerId` (captain/vice-captain/jersey/wicketkeeper
/// — see UpdateRosterEntryDto). Tournament registration
/// (`POST .../:teamId/tournaments/:tournamentId/register`) is out of scope
/// for M1's screens.
class TeamsRepository {
  TeamsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Team>> list(String organizationId) async {
    final response = await _apiClient.get('/organizations/$organizationId/teams');
    return (response.data as List<dynamic>)
        .map((e) => Team.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Team> get(String organizationId, String teamId) async {
    final response = await _apiClient.get('/organizations/$organizationId/teams/$teamId');
    return Team.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Team> create(
    String organizationId, {
    required String name,
    String? shortCode,
    String? logoUrl,
  }) async {
    final response = await _apiClient.post(
      '/organizations/$organizationId/teams',
      data: {
        'name': name,
        if (shortCode != null && shortCode.trim().isNotEmpty) 'shortCode': shortCode.trim(),
        if (logoUrl != null && logoUrl.trim().isNotEmpty) 'logoUrl': logoUrl.trim(),
      },
    );
    return Team.fromJson(response.data as Map<String, dynamic>);
  }

  /// Lists a tournament-team's roster (squad) — player details, captain/
  /// vice-captain flags, jersey number, wicketkeeper — ordered captain-first
  /// (see `TeamsService.getRoster`).
  Future<List<RosterEntry>> getRoster(
    String organizationId,
    String teamId,
    String tournamentId,
  ) async {
    final response = await _apiClient.get(
      '/organizations/$organizationId/teams/$teamId/tournaments/$tournamentId/roster',
    );
    return (response.data as List<dynamic>)
        .map((e) => RosterEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Updates one roster entry — captain/vice-captain flags, jersey number,
  /// wicketkeeper. Setting `isCaptain`/`isViceCaptain` true atomically
  /// unsets it on every other roster entry for the tournament-team
  /// server-side (see `TeamsService.updateRosterEntry`); the client never
  /// needs to un-set the previous holder itself.
  Future<RosterEntry> updateRosterEntry(
    String organizationId,
    String teamId,
    String tournamentId,
    String teamPlayerId, {
    bool? isCaptain,
    bool? isViceCaptain,
    int? jerseyNumber,
    bool? isWicketkeeper,
  }) async {
    final response = await _apiClient.patch(
      '/organizations/$organizationId/teams/$teamId/tournaments/$tournamentId/roster/$teamPlayerId',
      data: {
        if (isCaptain != null) 'isCaptain': isCaptain,
        if (isViceCaptain != null) 'isViceCaptain': isViceCaptain,
        if (jerseyNumber != null) 'jerseyNumber': jerseyNumber,
        if (isWicketkeeper != null) 'isWicketkeeper': isWicketkeeper,
      },
    );
    return RosterEntry.fromJson(response.data as Map<String, dynamic>);
  }
}
