/// Mirrors `PracticeType` in
/// apps/backend/src/database/entities/practice-session.entity.ts.
enum PracticeType {
  batting('batting', 'Batting'),
  bowling('bowling', 'Bowling'),
  fielding('fielding', 'Fielding'),
  fitness('fitness', 'Fitness'),
  netPractice('net_practice', 'Net Practice'),
  strategySession('strategy_session', 'Strategy Session');

  const PracticeType(this.value, this.label);

  final String value;
  final String label;

  static PracticeType fromValue(String value) => PracticeType.values.firstWhere(
        (type) => type.value == value,
        orElse: () => PracticeType.netPractice,
      );
}

/// Mirrors `PracticeSessionStatus` in
/// apps/backend/src/database/entities/practice-session.entity.ts.
enum PracticeSessionStatus {
  scheduled('scheduled', 'Scheduled'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const PracticeSessionStatus(this.value, this.label);

  final String value;
  final String label;

  static PracticeSessionStatus fromValue(String value) => PracticeSessionStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => PracticeSessionStatus.scheduled,
      );
}

/// Mirrors `PracticeSessionsService`'s response shape (apps/backend/src/
/// modules/practice/practice-sessions.service.ts) — the raw `PracticeSession`
/// entity fields plus the server-joined `coach` relation
/// (`RESPONSE_RELATIONS = ['coach']`). Rather than carry a full nested Coach
/// object (which would pull the coaches feature's model into this one), this
/// flattens the handful of coach fields the UI actually shows — same
/// resolved-flat-field approach as Match's `homeTeamName`/`awayTeamName`.
class PracticeSession {
  const PracticeSession({
    required this.id,
    required this.organizationId,
    required this.teamId,
    this.coachId,
    this.coachName,
    this.coachSpecialization,
    this.coachPhotoUrl,
    required this.scheduledAt,
    this.venueName,
    required this.practiceType,
    this.durationMinutes,
    this.notes,
    required this.status,
    required this.createdByUserId,
    required this.createdAt,
  });

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    final coach = json['coach'] as Map<String, dynamic>?;
    return PracticeSession(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
      teamId: json['teamId'] as String,
      coachId: json['coachId'] as String?,
      coachName: coach?['fullName'] as String?,
      coachSpecialization: coach?['specialization'] as String?,
      coachPhotoUrl: coach?['photoUrl'] as String?,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      venueName: json['venueName'] as String?,
      practiceType: PracticeType.fromValue(json['practiceType'] as String),
      durationMinutes: json['durationMinutes'] as int?,
      notes: json['notes'] as String?,
      status: PracticeSessionStatus.fromValue(json['status'] as String),
      createdByUserId: json['createdByUserId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String organizationId;
  final String teamId;

  final String? coachId;
  final String? coachName;
  final String? coachSpecialization;
  final String? coachPhotoUrl;

  final DateTime scheduledAt;
  final String? venueName;
  final PracticeType practiceType;
  final int? durationMinutes;
  final String? notes;
  final PracticeSessionStatus status;

  final String createdByUserId;
  final DateTime createdAt;
}
