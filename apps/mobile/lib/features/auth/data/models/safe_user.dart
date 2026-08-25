/// Mirrors `AuthService.SafeUser` in apps/backend/src/modules/auth/auth.service.ts
/// (the password-hash-stripped user shape returned by register/login), and
/// the body of `GET /users/me`.
class SafeUser {
  const SafeUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isSuperAdmin,
  });

  factory SafeUser.fromJson(Map<String, dynamic> json) => SafeUser(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
        isSuperAdmin: json['isSuperAdmin'] as bool? ?? false,
      );

  final String id;
  final String email;
  final String fullName;
  final bool isSuperAdmin;
}
