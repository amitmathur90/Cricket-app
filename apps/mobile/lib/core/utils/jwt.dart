import 'dart:convert';

/// Minimal, verification-free JWT payload decoder.
///
/// The mobile app never needs to verify the token's signature (the backend
/// already did that before issuing it) — it only needs to read claims like
/// `activeOrgId`/`role` locally to decide which screen to show next without
/// an extra round trip. See apps/backend/src/modules/auth/strategies/jwt.strategy.ts
/// for the payload shape this decodes (`sub`, `isSuperAdmin`, `activeOrgId`, `role`).
Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw const FormatException('Invalid JWT: expected 3 dot-separated segments');
  }
  final normalized = base64Url.normalize(parts[1]);
  final payloadJson = utf8.decode(base64Url.decode(normalized));
  return jsonDecode(payloadJson) as Map<String, dynamic>;
}
