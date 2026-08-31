import { apiClient } from '../../../core/api/client'
import type { SafeUser } from '../../../types/user'
import type { OrgMembership } from '../../../types/organization'

export interface AuthResult {
  user: SafeUser
  accessToken: string
  refreshToken: string
}

export const authApi = {
  async login(email: string, password: string): Promise<AuthResult> {
    const { data } = await apiClient.post<AuthResult>('/auth/login', { email, password })
    return data
  },

  async register(email: string, password: string, fullName: string): Promise<AuthResult> {
    const { data } = await apiClient.post<AuthResult>('/auth/register', {
      email,
      password,
      fullName,
    })
    return data
  },

  /** Mints a new access token scoped to organizationId. The backend only
   * returns {accessToken} here — the refresh token from login/register
   * keeps working and isn't reissued. */
  async selectOrg(organizationId: string): Promise<string> {
    const { data } = await apiClient.post<{ accessToken: string }>('/auth/select-org', {
      organizationId,
    })
    return data.accessToken
  },

  /** Step 1 of "Forgot password" — identifier is the account's email or
   * phone. Backend always returns the same generic message regardless of
   * whether a matching account exists. */
  async requestPasswordReset(identifier: string): Promise<string> {
    const { data } = await apiClient.post<{ message: string }>('/auth/forgot-password', {
      identifier,
    })
    return data.message
  },

  /** Step 2 — verifies the OTP and returns the opaque resetToken step 3 needs. */
  async verifyPasswordResetOtp(identifier: string, otp: string): Promise<string> {
    const { data } = await apiClient.post<{ resetToken: string }>('/auth/forgot-password/verify-otp', {
      identifier,
      otp,
    })
    return data.resetToken
  },

  /** Step 3 — sets the new password using the resetToken from step 2. */
  async resetPassword(resetToken: string, newPassword: string): Promise<void> {
    await apiClient.post('/auth/reset-password', { resetToken, newPassword })
  },
}

export const usersApi = {
  async me(): Promise<SafeUser> {
    const { data } = await apiClient.get<SafeUser>('/users/me')
    return data
  },

  async myMemberships(): Promise<OrgMembership[]> {
    const { data } = await apiClient.get<OrgMembership[]>('/users/me/memberships')
    return data
  },
}
