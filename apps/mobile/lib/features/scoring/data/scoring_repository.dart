import '../../../core/network/api_client.dart';
import 'models/scoring_lineup.dart';
import 'models/scoring_models.dart';

/// Talks to `ScoringController`
/// (apps/backend/src/modules/scoring/scoring.controller.ts) — the REST
/// surface for the ball-by-ball scoring engine, under
/// `/organizations/:organizationId/tournaments/:tournamentId/matches/:matchId/scoring`.
///
/// Every mutating call here has a WS equivalent on the `/scoring` namespace
/// (see `ScoringRoomController`) that does the exact same server-side work
/// and broadcasts the same way — REST is used here only for the one-time
/// setup actions (`start`/`start-innings`) that happen on their own screen
/// before (or between) live-room sessions; every in-room action during
/// actual scoring goes over the socket instead, per `ScoringGateway`'s own
/// doc comment ("REST is the fallback source of truth... WS is the
/// low-latency delta stream").
class ScoringRepository {
  ScoringRepository(this._apiClient);

  final ApiClient _apiClient;

  String _base(String organizationId, String tournamentId, String matchId) =>
      '/organizations/$organizationId/tournaments/$tournamentId/matches/$matchId/scoring';

  /// `POST .../scoring/start` — sets Match.status=live and creates the
  /// first innings (opening pair + first over's bowler) in one call.
  Future<LiveScoringState> startMatch(
    String organizationId,
    String tournamentId,
    String matchId, {
    required String battingFirstTournamentTeamId,
    int? oversLimit,
    required String openingStrikerTeamPlayerId,
    required String openingNonStrikerTeamPlayerId,
    required String openingBowlerTeamPlayerId,
  }) async {
    final response = await _apiClient.post(
      '${_base(organizationId, tournamentId, matchId)}/start',
      data: {
        'battingFirstTournamentTeamId': battingFirstTournamentTeamId,
        if (oversLimit != null) 'oversLimit': oversLimit,
        'openingStrikerTeamPlayerId': openingStrikerTeamPlayerId,
        'openingNonStrikerTeamPlayerId': openingNonStrikerTeamPlayerId,
        'openingBowlerTeamPlayerId': openingBowlerTeamPlayerId,
      },
    );
    return LiveScoringState.fromJson(response.data as Map<String, dynamic>);
  }

  /// `POST .../scoring/start-innings` — starts the second innings
  /// (batting/bowling teams auto-swapped server-side from innings 1).
  Future<LiveScoringState> startInnings(
    String organizationId,
    String tournamentId,
    String matchId, {
    required String openingStrikerTeamPlayerId,
    required String openingNonStrikerTeamPlayerId,
    required String openingBowlerTeamPlayerId,
  }) async {
    final response = await _apiClient.post(
      '${_base(organizationId, tournamentId, matchId)}/start-innings',
      data: {
        'openingStrikerTeamPlayerId': openingStrikerTeamPlayerId,
        'openingNonStrikerTeamPlayerId': openingNonStrikerTeamPlayerId,
        'openingBowlerTeamPlayerId': openingBowlerTeamPlayerId,
      },
    );
    return LiveScoringState.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LiveScoringState> newBowler(
    String organizationId,
    String tournamentId,
    String matchId, {
    required String bowlerTeamPlayerId,
  }) async {
    final response = await _apiClient.post(
      '${_base(organizationId, tournamentId, matchId)}/new-bowler',
      data: {'bowlerTeamPlayerId': bowlerTeamPlayerId},
    );
    return LiveScoringState.fromJson(response.data as Map<String, dynamic>);
  }

  /// `POST .../scoring/record-ball`. Deliberately does NOT accept striker/
  /// non-striker/bowler — those are always server-derived (see
  /// `RecordBallDto`'s own doc comment).
  Future<LiveScoringState> recordBall(
    String organizationId,
    String tournamentId,
    String matchId, {
    int? runs,
    String? extraType,
    bool? isWicket,
    String? dismissalType,
    String? dismissedTeamPlayerId,
    String? fielderTeamPlayerId,
    String? nextBatterTeamPlayerId,
    String? commentaryText,
  }) async {
    final response = await _apiClient.post(
      '${_base(organizationId, tournamentId, matchId)}/record-ball',
      data: {
        if (runs != null) 'runs': runs,
        if (extraType != null) 'extraType': extraType,
        if (isWicket != null) 'isWicket': isWicket,
        if (dismissalType != null) 'dismissalType': dismissalType,
        if (dismissedTeamPlayerId != null) 'dismissedTeamPlayerId': dismissedTeamPlayerId,
        if (fielderTeamPlayerId != null) 'fielderTeamPlayerId': fielderTeamPlayerId,
        if (nextBatterTeamPlayerId != null) 'nextBatterTeamPlayerId': nextBatterTeamPlayerId,
        if (commentaryText != null) 'commentaryText': commentaryText,
      },
    );
    return LiveScoringState.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LiveScoringState> undoLastBall(
    String organizationId,
    String tournamentId,
    String matchId,
  ) async {
    final response = await _apiClient.post('${_base(organizationId, tournamentId, matchId)}/undo-last-ball');
    return LiveScoringState.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LiveScoringState> endInnings(
    String organizationId,
    String tournamentId,
    String matchId,
  ) async {
    final response = await _apiClient.post('${_base(organizationId, tournamentId, matchId)}/end-innings');
    return LiveScoringState.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LiveScoringState> getLiveState(
    String organizationId,
    String tournamentId,
    String matchId,
  ) async {
    final response = await _apiClient.get('${_base(organizationId, tournamentId, matchId)}/live-state');
    return LiveScoringState.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MatchScorecard> getScorecard(
    String organizationId,
    String tournamentId,
    String matchId,
  ) async {
    final response = await _apiClient.get('${_base(organizationId, tournamentId, matchId)}/scorecard');
    return MatchScorecard.fromJson(response.data as Map<String, dynamic>);
  }

  /// `GET .../matches/:matchId/lineup` — NOT under the `/scoring` sub-path
  /// (it's `MatchLineupController`'s route, see `ScoringLineupPlayer`'s doc
  /// comment for why the scoring feature parses this response itself
  /// instead of reusing `MatchLineupRepository`/`TeamLineup`).
  Future<ScoringMatchLineup> getLineupPlayers(
    String organizationId,
    String tournamentId,
    String matchId,
  ) async {
    final response =
        await _apiClient.get('/organizations/$organizationId/tournaments/$tournamentId/matches/$matchId/lineup');
    return ScoringMatchLineup.fromJson(response.data as Map<String, dynamic>);
  }
}
