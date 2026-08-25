import '../../../core/network/api_client.dart';
import 'models/coach.dart';

/// Talks to `CoachesController` (apps/backend/src/modules/coaches) —
/// org-level coach CRUD under `/organizations/:organizationId/coaches`.
///
/// [update] always sends every editable field, even ones left unchanged —
/// same "single form covers create and edit" convention as
/// MatchesRepository.update / PracticeSessionsRepository.update. A `null`
/// for phone/email/specialization/photoUrl explicitly clears it server-side
/// (`@IsOptional()` on `UpdateCoachDto` treats `null` the same as "not
/// provided" for validation, then `CoachesService.update`'s
/// `Object.assign(coach, dto)` stores that null).
class CoachesRepository {
  CoachesRepository(this._apiClient);

  final ApiClient _apiClient;

  String _base(String organizationId) => '/organizations/$organizationId/coaches';

  Future<List<Coach>> list(String organizationId) async {
    final response = await _apiClient.get(_base(organizationId));
    return (response.data as List<dynamic>)
        .map((e) => Coach.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Coach> get(String organizationId, String coachId) async {
    final response = await _apiClient.get('${_base(organizationId)}/$coachId');
    return Coach.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Coach> create(
    String organizationId, {
    required String fullName,
    String? phone,
    String? email,
    String? specialization,
    String? photoUrl,
  }) async {
    final response = await _apiClient.post(
      _base(organizationId),
      data: {
        'fullName': fullName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (specialization != null) 'specialization': specialization,
        if (photoUrl != null) 'photoUrl': photoUrl,
      },
    );
    return Coach.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Coach> update(
    String organizationId,
    String coachId, {
    required String fullName,
    String? phone,
    String? email,
    String? specialization,
    String? photoUrl,
  }) async {
    final response = await _apiClient.patch(
      '${_base(organizationId)}/$coachId',
      data: {
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'specialization': specialization,
        'photoUrl': photoUrl,
      },
    );
    return Coach.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String organizationId, String coachId) async {
    await _apiClient.delete('${_base(organizationId)}/$coachId');
  }
}
