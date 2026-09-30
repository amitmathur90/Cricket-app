import '../../../tournaments/data/models/tournament.dart';

/// Mirrors `PUBLIC_TOURNAMENT_SELECT` in
/// apps/backend/src/modules/public/public-tournaments.controller.ts — a
/// deliberately smaller field set than the authenticated `Tournament` model
/// (features/tournaments/data/models/tournament.dart). Notably NOT present
/// on this response (so NOT modeled here): organizationId, contactEmail,
/// contactPhone, playerRegistrationFee, teamRegistrationFee,
/// tournamentRules, matchRules, pointsSystem, tieBreakerRules,
/// registrationOpensAt/ClosesAt, createdByUserId, teamsCount,
/// registrationStatus (the latter two are computed-at-response-time fields
/// on the authenticated endpoint only — the public controller queries the
/// repository directly with a plain `select`, so nothing is computed).
///
/// Reuses [TournamentFormat]/[TournamentFormatX] from the authenticated
/// model — it's a self-contained value enum with no field-shape risk, same
/// reasoning as reusing [MatchStatus] in `public_match.dart`.
class PublicTournament {
  const PublicTournament({
    required this.id,
    required this.name,
    required this.format,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.logoUrl,
    this.location,
    this.description,
    this.organizerName,
    this.numberOfTeams,
    this.organizationId,
    this.organizationName,
  });

  factory PublicTournament.fromJson(Map<String, dynamic> json) => PublicTournament(
        id: json['id'] as String,
        name: json['name'] as String,
        format: TournamentFormatX.fromApi(json['format'] as String),
        startDate: json['startDate'] as String,
        endDate: json['endDate'] as String,
        status: json['status'] as String? ?? 'draft',
        logoUrl: json['logoUrl'] as String?,
        location: json['location'] as String?,
        description: json['description'] as String?,
        organizerName: json['organizerName'] as String?,
        numberOfTeams: (json['numberOfTeams'] as num?)?.toInt(),
        organizationId: json['organizationId'] as String?,
        organizationName: json['organizationName'] as String?,
      );

  final String id;
  final String name;
  final TournamentFormat format;

  /// ISO date string (`YYYY-MM-DD`).
  final String startDate;
  final String endDate;

  /// One of `draft` | `upcoming` | `live` | `completed`.
  final String status;
  final String? logoUrl;
  final String? location;
  final String? description;
  final String? organizerName;
  final int? numberOfTeams;

  /// Only populated by `GET public/tournaments` (cross-org discovery) — the
  /// per-org `GET public/organizations/:organizationId/tournaments...`
  /// endpoints already have the org id in their route, so they don't repeat
  /// it in the response body.
  final String? organizationId;
  final String? organizationName;
}
