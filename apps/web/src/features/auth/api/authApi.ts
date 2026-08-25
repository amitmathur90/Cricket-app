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
