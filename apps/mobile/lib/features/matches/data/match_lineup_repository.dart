import '../../../core/network/api_client.dart';
import 'models/match_lineup.dart';

/// Talks to `MatchLineupController` (apps/backend/src/modules/matches/
/// match-lineup.controller.ts) — per-match, per-team Playing XI /
/// substitutes under
/// `/organizations/:organizationId/tournaments/:tournamentId/matches/:matchId/lineup`.
///
/// [setLineup] is a full replace (`PUT`): it always sends the complete
/// desired Playing XI + substitute lists, matching `SetLineupDto`'s own doc
/// comment that this mirrors how a "Select Playing XI" screen's whole state
/// is naturally submitted on save. The backend deliberately does NOT
/// enforce exactly-11 (`MatchLineupService.setLineup`'s own doc comment) —
/// that's a client-side UI rule (see LineupSelectionScreen).
class MatchLineupRepository {
  MatchLineupRepository(this._apiClient);

  final ApiClient _apiClient;

  String _base(String organizationId, String tournamentId, String matchId) =>
      '/organizations/$organizationId/tournaments/$tournamentId/matches/$matchId/lineup';

  Future<MatchLineupResponse> getLineup(
    String organizationId,
    String tournamentId,
    String matchId,
  ) async {
    final response = await _apiClient.get(_base(organizationId, tournamentId, matchId));
    return MatchLineupResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TeamLineup> setLineup(
    String organizationId,
    String tournamentId,
    String matchId,
    String tournamentTeamId, {
    required List<String> playingTeamPlayerIds,
    required List<String> substituteTeamPlayerIds,
  }) async {
    final response = await _apiClient.put(
      '${_base(organizationId, tournamentId, matchId)}/$tournamentTeamId',
      data: {
        'playingTeamPlayerIds': playingTeamPlayerIds,
        'substituteTeamPlayerIds': substituteTeamPlayerIds,
      },
    );
    return TeamLineup.fromJson(response.data as Map<String, dynamic>);
  }
}
