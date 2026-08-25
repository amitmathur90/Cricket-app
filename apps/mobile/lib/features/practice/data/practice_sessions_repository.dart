import '../../../core/network/api_client.dart';
import 'models/practice_session.dart';

/// Talks to `PracticeSessionsController` (apps/backend/src/modules/practice)
/// — per-team practice session CRUD under
/// `/organizations/:organizationId/teams/:teamId/practice-sessions`.
/// Deliberately NOT tournament-scoped, unlike MatchesRepository — see
/// PracticeSession entity's doc comment.
///
/// [update] always sends `practiceType` + `scheduledAt` (both required on
/// create, so always known at edit time) plus every other editable field,
/// even ones left unchanged — same "single form covers create and edit,
/// null explicitly clears" convention as MatchesRepository.update. Sending
/// `coachId: null` un-assigns the coach; `@IsOptional()` on
/// `UpdatePracticeSessionDto` treats that null as "not provided" for
/// validation, then `PracticeSessionsService.update`'s
/// `Object.assign(session, rest)` stores it.
class PracticeSessionsRepository {
  PracticeSessionsRepository(this._apiClient);

  final ApiClient _apiClient;

  String _base(String organizationId, String teamId) =>
      '/organizations/$organizationId/teams/$teamId/practice-sessions';

  Future<List<PracticeSession>> list(
    String organizationId,
    String teamId, {
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _apiClient.get(
      _base(organizationId, teamId),
      queryParameters: {
        if (status != null) 'status': status,
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => PracticeSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PracticeSession> get(String organizationId, String teamId, String sessionId) async {
    final response = await _apiClient.get('${_base(organizationId, teamId)}/$sessionId');
    return PracticeSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PracticeSession> create(
    String organizationId,
    String teamId, {
    required PracticeType practiceType,
    required DateTime scheduledAt,
    String? coachId,
    String? venueName,
    int? durationMinutes,
    String? notes,
  }) async {
    final response = await _apiClient.post(
      _base(organizationId, teamId),
      data: {
        'practiceType': practiceType.value,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        if (coachId != null) 'coachId': coachId,
        if (venueName != null) 'venueName': venueName,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (notes != null) 'notes': notes,
      },
    );
    return PracticeSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PracticeSession> update(
    String organizationId,
    String teamId,
    String sessionId, {
    required PracticeType practiceType,
    required DateTime scheduledAt,
    String? coachId,
    String? venueName,
    int? durationMinutes,
    String? notes,
    PracticeSessionStatus? status,
  }) async {
    final response = await _apiClient.patch(
      '${_base(organizationId, teamId)}/$sessionId',
      data: {
        'practiceType': practiceType.value,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'coachId': coachId,
        'venueName': venueName,
        'durationMinutes': durationMinutes,
        'notes': notes,
        if (status != null) 'status': status.value,
      },
    );
    return PracticeSession.fromJson(response.data as Map<String, dynamic>);
  }

  /// Soft "Cancel session" — `PATCH { status: 'cancelled' }` — mirrors
  /// MatchesRepository.cancel. Deliberately does not touch any other field.
  Future<PracticeSession> cancel(String organizationId, String teamId, String sessionId) async {
    final response = await _apiClient.patch(
      '${_base(organizationId, teamId)}/$sessionId',
      data: {'status': PracticeSessionStatus.cancelled.value},
    );
    return PracticeSession.fromJson(response.data as Map<String, dynamic>);
  }

  /// Hard delete. Unlike MatchesRepository.delete (deliberately unused by
  /// this app's UI), `PracticeSessionsController.remove`'s own doc comment
  /// frames practice sessions as "lower-stakes than matches" with a plain
  /// hard delete rather than a soft-cancel/hard-delete split — so this app's
  /// UI does offer it, alongside [cancel], as a real user-facing action.
  Future<void> delete(String organizationId, String teamId, String sessionId) async {
    await _apiClient.delete('${_base(organizationId, teamId)}/$sessionId');
  }
}
