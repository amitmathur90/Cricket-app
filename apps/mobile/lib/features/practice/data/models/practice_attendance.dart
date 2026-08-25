/// Mirrors `PracticeAttendanceStatus` in
/// apps/backend/src/database/entities/practice-attendance.entity.ts.
enum PracticeAttendanceStatus {
  present('present', 'Present'),
  absent('absent', 'Absent');

  const PracticeAttendanceStatus(this.value, this.label);

  final String value;
  final String label;

  static PracticeAttendanceStatus fromValue(String value) =>
      PracticeAttendanceStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => PracticeAttendanceStatus.absent,
      );
}

/// Mirrors `PracticeAttendanceService`'s response shape (apps/backend/src/
/// modules/practice/practice-attendance.service.ts) — the raw
/// `PracticeAttendance` entity fields plus the server-joined `player`
/// relation (`RESPONSE_RELATIONS = ['player']`), flattened the same way
/// [PracticeSession] flattens its `coach` relation.
///
/// Only rows that actually exist are ever returned by `GET .../attendance`
/// (see PracticeAttendanceService's doc comment) — a player with no
/// [PracticeAttendance] row is "not yet marked", not synthesized as absent.
/// Callers (see PracticeAttendanceScreen) render that missing-row state
/// against their own org player list, not from this model.
class PracticeAttendance {
  const PracticeAttendance({
    required this.id,
    required this.practiceSessionId,
    required this.playerId,
    this.playerName,
    this.playerPhotoUrl,
    required this.status,
    this.markedAt,
    required this.createdAt,
  });

  factory PracticeAttendance.fromJson(Map<String, dynamic> json) {
    final player = json['player'] as Map<String, dynamic>?;
    return PracticeAttendance(
      id: json['id'] as String,
      practiceSessionId: json['practiceSessionId'] as String,
      playerId: json['playerId'] as String,
      playerName: player?['fullName'] as String?,
      playerPhotoUrl: player?['photoUrl'] as String?,
      status: PracticeAttendanceStatus.fromValue(json['status'] as String),
      markedAt: json['markedAt'] != null ? DateTime.tryParse(json['markedAt'] as String) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String practiceSessionId;
  final String playerId;
  final String? playerName;
  final String? playerPhotoUrl;
  final PracticeAttendanceStatus status;
  final DateTime? markedAt;
  final DateTime createdAt;
}
