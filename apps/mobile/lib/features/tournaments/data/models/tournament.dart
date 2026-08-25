/// Mirrors `TournamentFormat` in
/// apps/backend/src/database/entities/tournament.entity.ts.
enum TournamentFormat { t20, odi, t10, custom }

extension TournamentFormatX on TournamentFormat {
  String get apiValue => switch (this) {
        TournamentFormat.t20 => 't20',
        TournamentFormat.odi => 'odi',
        TournamentFormat.t10 => 't10',
        TournamentFormat.custom => 'custom',
      };

  String get label => switch (this) {
        TournamentFormat.t20 => 'T20',
        TournamentFormat.odi => 'ODI',
        TournamentFormat.t10 => 'T10',
        TournamentFormat.custom => 'Custom',
      };

  static TournamentFormat fromApi(String value) => TournamentFormat.values.firstWhere(
        (f) => f.apiValue == value,
        orElse: () => TournamentFormat.custom,
      );
}

/// Mirrors the `RegistrationStatus` enum computed at response time by
/// `TournamentsService.computeRegistrationStatus` (never persisted —
/// derived from `registrationOpensAt`/`registrationClosesAt` vs. now).
enum RegistrationStatus { notOpen, open, closed }

extension RegistrationStatusX on RegistrationStatus {
  String get apiValue => switch (this) {
        RegistrationStatus.notOpen => 'not_open',
        RegistrationStatus.open => 'open',
        RegistrationStatus.closed => 'closed',
      };

  String get label => switch (this) {
        RegistrationStatus.notOpen => 'Not open',
        RegistrationStatus.open => 'Open',
        RegistrationStatus.closed => 'Closed',
      };

  static RegistrationStatus fromApi(String? value) => switch (value) {
        'open' => RegistrationStatus.open,
        'closed' => RegistrationStatus.closed,
        _ => RegistrationStatus.notOpen,
      };
}

/// Mirrors apps/backend/src/database/entities/tournament.entity.ts, plus the
/// `teamsCount` / `registrationStatus` fields computed at response time by
/// `TournamentsService` (see `TournamentResponse`) — never persisted, only
/// present in API responses.
class Tournament {
  const Tournament({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.format,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.auctionEnabled,
    required this.teamsCount,
    required this.registrationStatus,
    this.logoUrl,
    this.description,
    this.organizerName,
    this.contactEmail,
    this.contactPhone,
    this.location,
    this.numberOfTeams,
    this.maxPlayersPerTeam,
    this.tournamentRules,
    this.matchRules,
    this.pointsSystem,
    this.tieBreakerRules,
    this.registrationOpensAt,
    this.registrationClosesAt,
    this.playerRegistrationFee,
    this.teamRegistrationFee,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
        id: json['id'] as String,
        organizationId: json['organizationId'] as String,
        name: json['name'] as String,
        format: TournamentFormatX.fromApi(json['format'] as String),
        startDate: json['startDate'] as String,
        endDate: json['endDate'] as String,
        status: json['status'] as String? ?? 'draft',
        auctionEnabled: json['auctionEnabled'] as bool? ?? false,
        teamsCount: (json['teamsCount'] as num?)?.toInt() ?? 0,
        registrationStatus: RegistrationStatusX.fromApi(json['registrationStatus'] as String?),
        logoUrl: json['logoUrl'] as String?,
        description: json['description'] as String?,
        organizerName: json['organizerName'] as String?,
        contactEmail: json['contactEmail'] as String?,
        contactPhone: json['contactPhone'] as String?,
        location: json['location'] as String?,
        numberOfTeams: (json['numberOfTeams'] as num?)?.toInt(),
        maxPlayersPerTeam: (json['maxPlayersPerTeam'] as num?)?.toInt(),
        tournamentRules: json['tournamentRules'] as String?,
        matchRules: json['matchRules'] as String?,
        pointsSystem: json['pointsSystem'] as String?,
        tieBreakerRules: json['tieBreakerRules'] as String?,
        registrationOpensAt: json['registrationOpensAt'] as String?,
        registrationClosesAt: json['registrationClosesAt'] as String?,
        playerRegistrationFee: json['playerRegistrationFee'] as String?,
        teamRegistrationFee: json['teamRegistrationFee'] as String?,
      );

  final String id;
  final String organizationId;
  final String name;
  final TournamentFormat format;

  /// ISO date string (`YYYY-MM-DD`), as stored/returned by the backend.
  final String startDate;
  final String endDate;

  /// One of `draft` | `upcoming` | `live` | `completed` (TournamentStatus).
  final String status;
  final bool auctionEnabled;

  /// Computed at response time — number of teams currently registered to
  /// this tournament (`TournamentTeam` rows), not a DB column.
  final int teamsCount;

  /// Computed at response time from `registrationOpensAt`/`registrationClosesAt`
  /// vs. now — not a DB column.
  final RegistrationStatus registrationStatus;

  // --- Basic info ---
  final String? logoUrl;
  final String? description;
  final String? organizerName;
  final String? contactEmail;
  final String? contactPhone;

  // --- Tournament details ---
  final String? location;

  /// Target/max number of teams for this tournament.
  final int? numberOfTeams;
  final int? maxPlayersPerTeam;

  // --- Rules ---
  final String? tournamentRules;
  final String? matchRules;

  /// Free-text points system, e.g. "2 pts win, 1 pt tie".
  final String? pointsSystem;
  final String? tieBreakerRules;

  // --- Registration ---
  /// ISO date strings (`YYYY-MM-DD`).
  final String? registrationOpensAt;
  final String? registrationClosesAt;

  /// Decimal amounts come back from the backend as strings (Postgres
  /// `decimal` columns serialize as strings to avoid float precision loss).
  final String? playerRegistrationFee;
  final String? teamRegistrationFee;
}
