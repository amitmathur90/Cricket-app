import 'safe_user.dart';

/// Response body shared by `POST /auth/register` and `POST /auth/login`
/// (see AuthService.register/login).
class AuthResult {
  const AuthResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        user: SafeUser.fromJson(json['user'] as Map<String, dynamic>),
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );

  final SafeUser user;
  final String accessToken;
  final String refreshToken;
}
