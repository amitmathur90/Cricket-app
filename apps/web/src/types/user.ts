/** Mirrors apps/mobile/lib/features/auth/data/models/safe_user.dart —
 * the password-hash-stripped user shape from register/login/GET /users/me. */
export interface SafeUser {
  id: string
  email: string
  fullName: string
  isSuperAdmin: boolean
}
