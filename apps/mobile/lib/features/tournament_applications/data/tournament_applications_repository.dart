import '../../../core/network/api_client.dart';
import '../../players/data/models/player.dart';
import 'models/tournament_application.dart';

/// Talks to `TournamentApplicationsController`
/// (apps/backend/src/modules/tournament-applications) — routes nested under
/// `/organizations/:organizationId`.
class TournamentApplicationsRepository {
  TournamentApplicationsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Self-service: apply to a tournament as a player. Body shape matches
  /// `CreateTournamentApplicationDto` — identical to `CreatePlayerDto` minus
  /// `dob`/`userId` (see that DTO's doc comment). If the caller already has
  /// a Player profile in this org these fields are ignored server-side and
  /// the existing profile is reused as-is.
  Future<TournamentApplication> apply(
    String organizationId,
    String tournamentId, {
    required String fullName,
    required PlayerRole role,
    required String ageCategory,
    required String previousStatsNotes,
    required String photoUrl,
    required String idDocumentUrl,
    String? battingStyle,
    String? bowlingStyle,
    num? basePrice,
  }) async {
    final response = await _apiClient.post(
      '/organizations/$organizationId/tournaments/$tournamentId/applications',
      data: {
        'fullName': fullName,
        'role': role.apiValue,
        'ageCategory': ageCategory,
        'previousStatsNotes': previousStatsNotes,
        'photoUrl': photoUrl,
        'idDocumentUrl': idDocumentUrl,
        if (battingStyle != null && battingStyle.trim().isNotEmpty)
          'battingStyle': battingStyle.trim(),
        if (bowlingStyle != null && bowlingStyle.trim().isNotEmpty)
          'bowlingStyle': bowlingStyle.trim(),
        if (basePrice != null) 'basePrice': basePrice,
      },
    );
    return TournamentApplication.fromJson(response.data as Map<String, dynamic>);
  }

  /// org_admin/tournament_admin only: list applications for one tournament,
  /// optionally filtered by status.
  Future<List<TournamentApplication>> listForTournament(
    String organizationId,
    String tournamentId, {
    TournamentApplicationStatus? status,
  }) async {
    final response = await _apiClient.get(
      '/organizations/$organizationId/tournaments/$tournamentId/applications',
      queryParameters: status != null ? {'status': status.apiValue} : null,
    );
    return (response.data as List<dynamic>)
        .map((e) => TournamentApplication.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The caller's own applications across every tournament in this org.
  Future<List<TournamentApplication>> listMine(String organizationId) async {
    final response = await _apiClient.get('/organizations/$organizationId/applications/mine');
    return (response.data as List<dynamic>)
        .map((e) => TournamentApplication.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// org_admin/tournament_admin only: approve or reject an application.
  Future<TournamentApplication> review(
    String organizationId,
    String tournamentId,
    String applicationId, {
    required TournamentApplicationStatus status,
    String? note,
  }) async {
    final response = await _apiClient.patch(
      '/organizations/$organizationId/tournaments/$tournamentId/applications/$applicationId/review',
      data: {
        'status': status.apiValue,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return TournamentApplication.fromJson(response.data as Map<String, dynamic>);
  }
}
