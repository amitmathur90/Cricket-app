import '../../../core/network/api_client.dart';
import 'models/practice_attendance.dart';

/// Talks to `PracticeAttendanceController` (apps/backend/src/modules/
/// practice/practice-attendance.controller.ts) — attendance for one
/// practice session under
/// `/organizations/:organizationId/teams/:teamId/practice-sessions/:sessionId/attendance`.
class PracticeAttendanceRepository {
  PracticeAttendanceRepository(this._apiClient);

  final ApiClient _apiClient;

  String _base(String organizationId, String teamId, String sessionId) =>
      '/organizations/$organizationId/teams/$teamId/practice-sessions/$sessionId/attendance';

  /// Only rows that actually exist are returned — see
  /// [PracticeAttendance]'s doc comment.
  Future<List<PracticeAttendance>> get(
    String organizationId,
    String teamId,
    String sessionId,
  ) async {
    final response = await _apiClient.get(_base(organizationId, teamId, sessionId));
    return (response.data as List<dynamic>)
        .map((e) => PracticeAttendance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Bulk create-or-update, matching `MarkAttendanceDto`'s `{ entries:
  /// [{playerId, status}, ...] }` shape. [entries] should only contain
  /// players the caller has actually marked — players left in the
  /// "not yet marked" state are simply omitted, not sent as a synthesized
  /// default.
  Future<List<PracticeAttendance>> markAttendance(
    String organizationId,
    String teamId,
    String sessionId,
    Map<String, PracticeAttendanceStatus> entries,
  ) async {
    final response = await _apiClient.put(
      _base(organizationId, teamId, sessionId),
      data: {
        'entries': [
          for (final entry in entries.entries)
            {'playerId': entry.key, 'status': entry.value.value},
        ],
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => PracticeAttendance.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
