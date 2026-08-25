/// Mirrors apps/backend/src/database/entities/match.entity.ts's `MatchStatus`
/// enum exactly (values are the raw strings the backend sends/expects).
enum MatchStatus {
  scheduled('scheduled', 'Scheduled'),
  live('live', 'Live'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const MatchStatus(this.value, this.label);

  final String value;
  final String label;

  static MatchStatus fromValue(String value) => MatchStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => MatchStatus.scheduled,
      );
}

/// Mirrors `MatchesService.MatchResponse` (apps/backend/src/modules/matches/matches.service.ts)
/// — the raw `Match` entity fields plus server-resolved `homeTeamName` /
/// `awayTeamName` / `winnerTeamName`. The backend joins
/// match -> tournament_team -> team server-side for every response
/// specifically so the client never has to; always prefer these resolved
/// name fields over trying to re-join `homeTournamentTeamId` against some
/// other locally-fetched team list.
class Match {
  const Match({
    required this.id,
    required this.tournamentId,
    this.homeTournamentTeamId,
    this.awayTournamentTeamId,
    this.scheduledAt,
    this.venueName,
    this.umpireName,
    this.scorerName,
    this.venueId,
    this.umpireOfficialId,
    this.scorerOfficialId,
    this.matchRefereeOfficialId,
    this.venueDisplayName,
    this.umpireOfficialDisplayName,
    this.scorerOfficialDisplayName,
    this.matchRefereeOfficialDisplayName,
    required this.status,
    this.resultSummary,
    this.winnerTournamentTeamId,
    required this.createdByUserId,
    required this.createdAt,
    this.homeTeamName,
    this.awayTeamName,
    this.winnerTeamName,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    // The backend resolves venueId/umpireOfficialId/scorerOfficialId/
    // matchRefereeOfficialId into full nested `venue`/`umpireOfficial`/
    // `scorerOfficial`/`matchRefereeOfficial` objects when set (see
    // MatchesService's RESPONSE_RELATIONS) — this model only needs their
    // display name out of each, not the full Venue/Official shape, to avoid
    // this feature depending on the venues/officials features' models.
    String? displayName(String key, String nameField) {
      final nested = json[key];
      if (nested is Map<String, dynamic>) {
        return nested[nameField] as String?;
      }
      return null;
    }

    return Match(
      id: json['id'] as String,
      tournamentId: json['tournamentId'] as String,
      homeTournamentTeamId: json['homeTournamentTeamId'] as String?,
      awayTournamentTeamId: json['awayTournamentTeamId'] as String?,
      scheduledAt:
          json['scheduledAt'] != null ? DateTime.tryParse(json['scheduledAt'] as String) : null,
      venueName: json['venueName'] as String?,
      umpireName: json['umpireName'] as String?,
      scorerName: json['scorerName'] as String?,
      venueId: json['venueId'] as String?,
      umpireOfficialId: json['umpireOfficialId'] as String?,
      scorerOfficialId: json['scorerOfficialId'] as String?,
      matchRefereeOfficialId: json['matchRefereeOfficialId'] as String?,
      venueDisplayName: displayName('venue', 'name'),
      umpireOfficialDisplayName: displayName('umpireOfficial', 'fullName'),
      scorerOfficialDisplayName: displayName('scorerOfficial', 'fullName'),
      matchRefereeOfficialDisplayName: displayName('matchRefereeOfficial', 'fullName'),
      status: MatchStatus.fromValue(json['status'] as String),
      resultSummary: json['resultSummary'] as String?,
      winnerTournamentTeamId: json['winnerTournamentTeamId'] as String?,
      createdByUserId: json['createdByUserId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      homeTeamName: json['homeTeamName'] as String?,
      awayTeamName: json['awayTeamName'] as String?,
      winnerTeamName: json['winnerTeamName'] as String?,
    );
  }

  final String id;
  final String tournamentId;
  final String? homeTournamentTeamId;
  final String? awayTournamentTeamId;
  final DateTime? scheduledAt;
  final String? venueName;
  final String? umpireName;
  final String? scorerName;

  // --- Dual-field approach (see Match entity's doc comment): optional FKs
  // into the venues/officials modules, alongside the free-text fields above.
  // Both can be set independently; neither overwrites the other.
  final String? venueId;
  final String? umpireOfficialId;
  final String? scorerOfficialId;
  final String? matchRefereeOfficialId;

  /// Server-resolved display name for [venueId] (from the nested `venue`
  /// object), or `null` if [venueId] is unset. Prefer [venueName] for
  /// display when both are present — see the entity doc comment for which
  /// field a given surface should read.
  final String? venueDisplayName;
  final String? umpireOfficialDisplayName;
  final String? scorerOfficialDisplayName;
  final String? matchRefereeOfficialDisplayName;

  final MatchStatus status;

  // --- Reserved for a future live-scoring/points-table feature — the
  // matches module never populates these today, but the entity carries them
  // (see match.entity.ts's doc comment), so the model mirrors them too.
  final String? resultSummary;
  final String? winnerTournamentTeamId;

  final String createdByUserId;
  final DateTime createdAt;

  final String? homeTeamName;
  final String? awayTeamName;
  final String? winnerTeamName;
}
