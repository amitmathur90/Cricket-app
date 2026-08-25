import '../../../core/network/api_client.dart';
import 'models/official.dart';

/// Talks to `OfficialsController` (apps/backend/src/modules/officials) —
/// org-level official (umpire/scorer/match referee) CRUD under
/// `/organizations/:organizationId/officials`.
///
/// [update] always sends every editable field, even ones left unchanged —
/// same "single form covers create and edit" convention as
/// CoachesRepository.update. A `null` for phone/email/photoUrl explicitly
/// clears it server-side (`@IsOptional()` on `UpdateOfficialDto` treats
/// `null` the same as "not provided" for validation, then
/// `OfficialsService.update`'s `Object.assign(official, dto)` stores that
/// null).
class OfficialsRepository {
  OfficialsRepository(this._apiClient);

  final ApiClient _apiClient;

  String _base(String organizationId) => '/organizations/$organizationId/officials';

  /// [role] mirrors `OfficialsController.findAll`'s optional `?role=` query
  /// filter (raw backend value, e.g. `'umpire'`).
  Future<List<Official>> list(String organizationId, {String? role}) async {
    final response = await _apiClient.get(
      _base(organizationId),
      queryParameters: {if (role != null) 'role': role},
    );
    return (response.data as List<dynamic>)
        .map((e) => Official.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Official> get(String organizationId, String officialId) async {
    final response = await _apiClient.get('${_base(organizationId)}/$officialId');
    return Official.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Official> create(
    String organizationId, {
    required String fullName,
    required OfficialRole role,
    String? phone,
    String? email,
    String? photoUrl,
  }) async {
    final response = await _apiClient.post(
      _base(organizationId),
      data: {
        'fullName': fullName,
        'role': role.value,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (photoUrl != null) 'photoUrl': photoUrl,
      },
    );
    return Official.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Official> update(
    String organizationId,
    String officialId, {
    required String fullName,
    required OfficialRole role,
    String? phone,
    String? email,
    String? photoUrl,
  }) async {
    final response = await _apiClient.patch(
      '${_base(organizationId)}/$officialId',
      data: {
        'fullName': fullName,
        'role': role.value,
        'phone': phone,
        'email': email,
        'photoUrl': photoUrl,
      },
    );
    return Official.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String organizationId, String officialId) async {
    await _apiClient.delete('${_base(organizationId)}/$officialId');
  }
}
