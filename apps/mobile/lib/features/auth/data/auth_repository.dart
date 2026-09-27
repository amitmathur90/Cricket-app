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
    String? phone,
  }) async {
    final response = await _apiClient.post('/auth/register', data: {
      'email': email,
      'password': password,
      'fullName': fullName,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    });
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Step 1 of "Forgot password" — [identifier] is the account's email or
  /// phone. Backend always returns the same generic message regardless of
  /// whether a matching account exists, so there's nothing to branch on
  /// here beyond surfacing an actual network/server error.
  Future<String> requestPasswordReset(String identifier) async {
    final response = await _apiClient.post('/auth/forgot-password', data: {
      'identifier': identifier,
    });
    return (response.data as Map<String, dynamic>)['message'] as String;
  }

  /// Step 2 — verifies the OTP and returns the opaque resetToken step 3 needs.
  Future<String> verifyPasswordResetOtp({
    required String identifier,
    required String otp,
  }) async {
    final response = await _apiClient.post('/auth/forgot-password/verify-otp', data: {
      'identifier': identifier,
      'otp': otp,
    });
    return (response.data as Map<String, dynamic>)['resetToken'] as String;
  }

  /// Step 3 — sets the new password using the resetToken from step 2.
  Future<void> resetPassword({required String resetToken, required String newPassword}) async {
    await _apiClient.post('/auth/reset-password', data: {
      'resetToken': resetToken,
      'newPassword': newPassword,
    });
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final response = await _apiClient.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Step 1 of "Login with mobile OTP" — texts a 4-digit OTP to the account
  /// matching [phone]. Same generic-message-regardless-of-match posture as
  /// requestPasswordReset. `devOtp` is only ever present when the backend's
  /// DEV_OTP_FALLBACK testing toggle is on AND the real SMS send failed —
  /// see AuthService.requestMobileLoginOtp's doc comment; null in normal
  /// operation.
  Future<({String message, String? devOtp})> requestMobileLoginOtp(String phone) async {
    final response = await _apiClient.post('/auth/login/mobile/request-otp', data: {
      'phone': phone,
    });
    final data = response.data as Map<String, dynamic>;
    return (message: data['message'] as String, devOtp: data['devOtp'] as String?);
  }

  /// Step 2 — verifies the OTP and, on success, returns real access/refresh
  /// tokens (same shape as [login]).
  Future<AuthResult> verifyMobileLoginOtp({required String phone, required String otp}) async {
    final response = await _apiClient.post('/auth/login/mobile/verify-otp', data: {
      'phone': phone,
      'otp': otp,
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
