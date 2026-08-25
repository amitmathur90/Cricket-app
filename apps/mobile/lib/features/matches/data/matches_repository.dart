import '../../../core/network/api_client.dart';
import 'models/match.dart';

/// Talks to `MatchesController` (apps/backend/src/modules/matches) —
/// per-tournament fixture CRUD under
/// `/organizations/:organizationId/tournaments/:tournamentId/matches`.
///
/// [update] always sends every editable field (home/away team, scheduledAt,
/// venue/umpire/scorer) together, even fields left unchanged — the match
/// form (see MatchFormScreen) is deliberately a single "everything" form
/// used for both create and edit, mirroring the backend's own single
/// generic PATCH covering assign-teams/assign-venue/assign-umpire/
/// assign-scorer/reschedule in one endpoint (see UpdateMatchDto's doc
/// comment). Sending an explicit JSON `null` for a field the user cleared
/// is intentional, not an oversight: `@IsOptional()` on the DTO treats a
/// `null` the same as "not provided" for validation purposes, and
/// `MatchesService.update`'s `Object.assign(match, rest)` then actually
/// stores that null — so this is how the form clears a previously-set
/// venue/umpire/scorer/team.
class MatchesRepository {
  MatchesRepository(this._apiClient);

  final ApiClient _apiClient;

  String _base(String organizationId, String tournamentId) =>
      '/organizations/$organizationId/tournaments/$tournamentId/matches';

  Future<List<Match>> list(
    String organizationId,
    String tournamentId, {
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _apiClient.get(
      _base(organizationId, tournamentId),
      queryParameters: {
        if (status != null) 'status': status,
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => Match.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Match> get(String organizationId, String tournamentId, String matchId) async {
    final response = await _apiClient.get('${_base(organizationId, tournamentId)}/$matchId');
    return Match.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Match> create(
    String organizationId,
    String tournamentId, {
    String? homeTournamentTeamId,
    String? awayTournamentTeamId,
    DateTime? scheduledAt,
    String? venueName,
    String? umpireName,
    String? scorerName,
    String? venueId,
    String? umpireOfficialId,
    String? scorerOfficialId,
    String? matchRefereeOfficialId,
  }) async {
    final response = await _apiClient.post(
      _base(organizationId, tournamentId),
      data: {
        if (homeTournamentTeamId != null) 'homeTournamentTeamId': homeTournamentTeamId,
        if (awayTournamentTeamId != null) 'awayTournamentTeamId': awayTournamentTeamId,
        if (scheduledAt != null) 'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        if (venueName != null) 'venueName': venueName,
        if (umpireName != null) 'umpireName': umpireName,
        if (scorerName != null) 'scorerName': scorerName,
        if (venueId != null) 'venueId': venueId,
        if (umpireOfficialId != null) 'umpireOfficialId': umpireOfficialId,
        if (scorerOfficialId != null) 'scorerOfficialId': scorerOfficialId,
        if (matchRefereeOfficialId != null) 'matchRefereeOfficialId': matchRefereeOfficialId,
      },
    );
    return Match.fromJson(response.data as Map<String, dynamic>);
  }

  /// [venueId]/[umpireOfficialId]/[scorerOfficialId]/[matchRefereeOfficialId]
  /// always send an explicit value (including `null` to clear a previously
  /// set assignment) — same "full form, every field" convention as the
  /// free-text fields above, and consistent with how the match form treats
  /// the structured pickers as independent, always-editable fields.
  Future<Match> update(
    String organizationId,
    String tournamentId,
    String matchId, {
    String? homeTournamentTeamId,
    String? awayTournamentTeamId,
    DateTime? scheduledAt,
    String? venueName,
    String? umpireName,
    String? scorerName,
    String? venueId,
    String? umpireOfficialId,
    String? scorerOfficialId,
    String? matchRefereeOfficialId,
    MatchStatus? status,
  }) async {
    final response = await _apiClient.patch(
      '${_base(organizationId, tournamentId)}/$matchId',
      data: {
        'homeTournamentTeamId': homeTournamentTeamId,
        'awayTournamentTeamId': awayTournamentTeamId,
        'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
        'venueName': venueName,
        'umpireName': umpireName,
        'scorerName': scorerName,
        'venueId': venueId,
        'umpireOfficialId': umpireOfficialId,
        'scorerOfficialId': scorerOfficialId,
        'matchRefereeOfficialId': matchRefereeOfficialId,
        if (status != null) 'status': status.value,
      },
    );
    return Match.fromJson(response.data as Map<String, dynamic>);
  }

  /// The spec's soft "Cancel match" action — `PATCH { status: 'cancelled' }`.
  /// Deliberately does NOT touch any other field (unlike [update], which
  /// always sends the full form), so cancelling never clobbers an
  /// in-progress edit to venue/teams/etc. that hasn't been saved yet.
  Future<Match> cancel(String organizationId, String tournamentId, String matchId) async {
    final response = await _apiClient.patch(
      '${_base(organizationId, tournamentId)}/$matchId',
      data: {'status': MatchStatus.cancelled.value},
    );
    return Match.fromJson(response.data as Map<String, dynamic>);
  }

  /// True hard delete (`DELETE`) — administrative cleanup only, per
  /// `MatchesController.remove`'s own doc comment. Implemented here for a
  /// complete CRUD contract, but deliberately not wired to any button in
  /// this app's UI: [cancel] (soft "Cancel match") is the real user-facing
  /// destructive action; hard delete is out of scope for the main flow.
  Future<void> delete(String organizationId, String tournamentId, String matchId) async {
    await _apiClient.delete('${_base(organizationId, tournamentId)}/$matchId');
  }
}
