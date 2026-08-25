import '../../../core/network/api_client.dart';
import '../../organizations/data/models/org_membership.dart';
import 'models/auth_result.dart';
import 'models/safe_user.dart';

/// Talks to `AuthController`/`UsersController` on the backend
/// (apps/backend/src/modules/auth, apps/backend/src/modules/users).
class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthResult> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _apiClient.post('/auth/register', data: {
      'email': email,
      'password': password,
      'fullName': fullName,
    });
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final response = await _apiClient.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Mints a new access token scoped to [organizationId]. Note the backend
  /// only returns `{ accessToken }` here — the refresh token from
  /// login/register keeps working and isn't reissued (see
  /// AuthService.selectOrg).
  Future<String> selectOrg(String organizationId) async {
    final response = await _apiClient.post('/auth/select-org', data: {
      'organizationId': organizationId,
    });
    return (response.data as Map<String, dynamic>)['accessToken'] as String;
  }

  Future<SafeUser> me() async {
    final response = await _apiClient.get('/users/me');
    return SafeUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<OrgMembership>> myMemberships() async {
    final response = await _apiClient.get('/users/me/memberships');
    return (response.data as List<dynamic>)
        .map((e) => OrgMembership.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
