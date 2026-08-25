import '../../../matches/data/models/match.dart' show MatchStatus;

/// Mirrors the explicit projection returned by
/// `GET public/organizations/:organizationId/tournaments/:tournamentId/matches`
/// (apps/backend/src/modules/public/public-tournaments.controller.ts#getMatches)
/// — deliberately NOT the authenticated `Match` model
/// (features/matches/data/models/match.dart): the public response omits
/// umpire/scorer/match-referee names and ids entirely (those carry PII —
/// Official.phone/email — on the authenticated response's nested official
/// objects), and has no `venueId`/officials fields at all, just a flat
/// `venueName`.
///
/// Reuses [MatchStatus] from the authenticated matches model — it's a
/// self-contained value enum (raw string <-> label) with no field-shape
/// risk, unlike reusing the full `Match` class would be.
class PublicMatch {
  const PublicMatch({
    required this.id,
    required this.tournamentId,
    this.homeTournamentTeamId,
    this.awayTournamentTeamId,
    this.homeTeamName,
    this.awayTeamName,
    this.winnerTournamentTeamId,
    this.winnerTeamName,
    this.scheduledAt,
    this.venueName,
    required this.status,
    this.resultSummary,
    this.oversLimit,
  });

  factory PublicMatch.fromJson(Map<String, dynamic> json) => PublicMatch(
        id: json['id'] as String,
        tournamentId: json['tournamentId'] as String,
        homeTournamentTeamId: json['homeTournamentTeamId'] as String?,
        awayTournamentTeamId: json['awayTournamentTeamId'] as String?,
        homeTeamName: json['homeTeamName'] as String?,
        awayTeamName: json['awayTeamName'] as String?,
        winnerTournamentTeamId: json['winnerTournamentTeamId'] as String?,
        winnerTeamName: json['winnerTeamName'] as String?,
        scheduledAt:
            json['scheduledAt'] != null ? DateTime.tryParse(json['scheduledAt'] as String) : null,
        venueName: json['venueName'] as String?,
        status: MatchStatus.fromValue(json['status'] as String),
        resultSummary: json['resultSummary'] as String?,
        oversLimit: (json['oversLimit'] as num?)?.toInt(),
      );

  final String id;
  final String tournamentId;
  final String? homeTournamentTeamId;
  final String? awayTournamentTeamId;
  final String? homeTeamName;
  final String? awayTeamName;
  final String? winnerTournamentTeamId;
  final String? winnerTeamName;
  final DateTime? scheduledAt;
  final String? venueName;
  final MatchStatus status;
  final String? resultSummary;
  final int? oversLimit;
}
