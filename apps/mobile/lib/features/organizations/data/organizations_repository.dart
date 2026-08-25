import '../../../core/network/api_client.dart';
import 'models/organization.dart';

/// Talks to `OrganizationsController`
/// (apps/backend/src/modules/organizations).
class OrganizationsRepository {
  OrganizationsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Creates a new organization; the caller becomes its `org_admin`.
  Future<Organization> create({required String name, String? slug}) async {
    final response = await _apiClient.post('/organizations', data: {
      'name': name,
      if (slug != null && slug.trim().isNotEmpty) 'slug': slug.trim(),
    });
    return Organization.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Organization> getById(String organizationId) async {
    final response = await _apiClient.get('/organizations/$organizationId');
    return Organization.fromJson(response.data as Map<String, dynamic>);
  }

  /// Self-service join via an org's join code — auto-creates an ACTIVE
  /// `player`-role membership for the caller (see
  /// OrganizationsService.join). Returns the (partial — no `joinCode`)
  /// organization from the response's `organization` field.
  Future<Organization> join(String joinCode) async {
    final response = await _apiClient.post('/organizations/join', data: {
      'joinCode': joinCode.trim(),
    });
    final data = response.data as Map<String, dynamic>;
    return Organization.fromJson(data['organization'] as Map<String, dynamic>);
  }

  /// org_admin only (enforced server-side): rotates the org's join code.
  Future<Organization> regenerateJoinCode(String organizationId) async {
    final response =
        await _apiClient.post('/organizations/$organizationId/join-code/regenerate');
    return Organization.fromJson(response.data as Map<String, dynamic>);
  }
}
