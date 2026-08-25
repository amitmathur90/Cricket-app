import { create } from 'zustand'
import { authApi, usersApi } from '../../features/auth/api/authApi'
import type { SafeUser } from '../../types/user'
import type { OrgMembership, OrgRole } from '../../types/organization'
import { decodeJwtPayload } from './jwt'
import { tokenStorage } from './tokenStorage'
import { registerAuthBridge } from '../api/authBridge'
import { refreshAccessToken } from '../api/client'
import { onSessionExpired } from './sessionEvents'

/** Drives ProtectedRoute's redirect decisions — mirrors
 * apps/mobile/lib/features/auth/application/session_controller.dart's
 * AuthStatus enum exactly. */
export type AuthStatus =
  | 'unknown'
  | 'unauthenticated'
  | 'needsOrgSelection'
  | 'needsOrgCreation'
  | 'authenticated'

interface AuthState {
  status: AuthStatus
  accessToken: string | null
  user: SafeUser | null
  activeOrgId: string | null
  role: OrgRole | null
  isSuperAdmin: boolean
  memberships: OrgMembership[]
  isBusy: boolean
  errorMessage: string | null

  bootstrap: () => Promise<void>
  login: (email: string, password: string) => Promise<void>
  selectOrg: (organizationId: string) => Promise<void>
  logout: () => void
  handleSessionExpired: () => void
}

/** Given a freshly-issued or stored access token, decides whether the app
 * can go straight to the authenticated area or needs to route through org
 * selection/creation first. Mirrors
 * SessionController._resolveFromAccessToken/_resolveOrgSelection. */
async function resolveFromAccessToken(
  accessToken: string,
  set: (partial: Partial<AuthState>) => void,
): Promise<void> {
  try {
    const claims = decodeJwtPayload(accessToken)
    const activeOrgId = (claims.activeOrgId as string | undefined) ?? null
    const role = (claims.role as OrgRole | undefined) ?? null
    const user = await usersApi.me()

    if (activeOrgId) {
      set({
        status: 'authenticated',
        accessToken,
        user,
        activeOrgId,
        role,
        isSuperAdmin: user.isSuperAdmin,
      })
      return
    }

    await resolveOrgSelection(user, set)
  } catch {
    tokenStorage.clear()
    set({
      status: 'unauthenticated',
      accessToken: null,
      user: null,
      activeOrgId: null,
      role: null,
      memberships: [],
    })
  }
}

async function resolveOrgSelection(
  user: SafeUser,
  set: (partial: Partial<AuthState>) => void,
): Promise<void> {
  const memberships = await usersApi.myMemberships()
  const activeMemberships = memberships.filter((m) => m.status === 'active')

  if (activeMemberships.length === 0) {
    set({ status: 'needsOrgCreation', user, memberships, isSuperAdmin: user.isSuperAdmin })
    return
  }

  if (activeMemberships.length === 1) {
    await selectOrgAndFinish(activeMemberships[0].organizationId, user, set)
    return
  }

  set({ status: 'needsOrgSelection', user, memberships: activeMemberships, isSuperAdmin: user.isSuperAdmin })
}

async function selectOrgAndFinish(
  organizationId: string,
  user: SafeUser,
  set: (partial: Partial<AuthState>) => void,
): Promise<void> {
  const newAccessToken = await authApi.selectOrg(organizationId)
  const claims = decodeJwtPayload(newAccessToken)
  set({
    status: 'authenticated',
    accessToken: newAccessToken,
    user,
    activeOrgId: organizationId,
    role: (claims.role as OrgRole | undefined) ?? null,
    isSuperAdmin: user.isSuperAdmin,
  })
}

export const useAuthStore = create<AuthState>((set, get) => ({
  status: 'unknown',
  accessToken: null,
  user: null,
  activeOrgId: null,
  role: null,
  isSuperAdmin: false,
  memberships: [],
  isBusy: false,
  errorMessage: null,

  async bootstrap() {
    const refreshToken = tokenStorage.readRefreshToken()
    if (!refreshToken) {
      set({ status: 'unauthenticated' })
      return
    }
    // No stored access token survives a hard refresh (in-memory only), so
    // bootstrap always exchanges the refresh token once on app start.
    const newAccessToken = await refreshAccessToken()
    if (!newAccessToken) {
      set({ status: 'unauthenticated' })
      return
    }
    await resolveFromAccessToken(newAccessToken, set)
  },

  async login(email, password) {
    set({ isBusy: true, errorMessage: null })
    try {
      const result = await authApi.login(email, password)
      tokenStorage.saveRefreshToken(result.refreshToken)
      set({ accessToken: result.accessToken })
      await resolveFromAccessToken(result.accessToken, set)
      set({ isBusy: false })
    } catch (error) {
      set({
        isBusy: false,
        status: 'unauthenticated',
        errorMessage: error instanceof Error ? error.message : 'Login failed',
      })
    }
  },

  async selectOrg(organizationId) {
    const user = get().user
    if (!user) return
    set({ isBusy: true, errorMessage: null })
    try {
      await selectOrgAndFinish(organizationId, user, set)
      set({ isBusy: false })
    } catch (error) {
      set({ isBusy: false, errorMessage: error instanceof Error ? error.message : 'Could not select org' })
    }
  },

  logout() {
    tokenStorage.clear()
    set({
      status: 'unauthenticated',
      accessToken: null,
      user: null,
      activeOrgId: null,
      role: null,
      memberships: [],
    })
  },

  handleSessionExpired() {
    tokenStorage.clear()
    set({
      status: 'unauthenticated',
      accessToken: null,
      user: null,
      activeOrgId: null,
      role: null,
      memberships: [],
    })
  },
}))

// Wire the API client's access-token get/set to this store (see
// core/api/authBridge.ts — avoids a circular import between client.ts and
// this file) and listen for unrecoverable-refresh-failure signals.
registerAuthBridge({
  getAccessToken: () => useAuthStore.getState().accessToken,
  setAccessToken: (token) => useAuthStore.setState({ accessToken: token }),
})
onSessionExpired(() => useAuthStore.getState().handleSessionExpired())
