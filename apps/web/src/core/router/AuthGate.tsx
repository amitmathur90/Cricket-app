import { Navigate, useLocation } from 'react-router-dom'
import { useAuthStore, type AuthStatus } from '../auth/authStore'

/** The one path each status is allowed to be on. Any other pathname gets
 * redirected here. Mirrors the single `redirect` callback in
 * apps/mobile/lib/core/router/app_router.dart, which re-evaluates on every
 * navigation rather than gating each route independently — that avoids the
 * gap where e.g. a logged-out user could land directly on /select-org and
 * see an empty membership list instead of being sent to /login. */
const EXPECTED_PATH: Record<AuthStatus, string | null> = {
  unknown: null, // no redirect while resolving — show a loading state in place
  unauthenticated: '/login',
  needsOrgSelection: '/select-org',
  needsOrgCreation: '/create-organization',
  authenticated: null, // any path under the authenticated app is fine
}

// /forgot-password is reachable from 'unauthenticated' too (in addition to
// its EXPECTED_PATH, '/login') — see the allowlist check below.
const UNAUTHENTICATED_EXTRA_PATHS = ['/forgot-password']

const PRE_AUTH_PATHS = ['/login', '/forgot-password', '/select-org', '/create-organization']

export function AuthGate({ children }: { children: React.ReactNode }) {
  const status = useAuthStore((s) => s.status)
  const location = useLocation()

  if (status === 'unknown') {
    return (
      <div className="flex min-h-screen items-center justify-center bg-page text-text-secondary">
        Loading…
      </div>
    )
  }

  const expected = EXPECTED_PATH[status]
  const onAllowedExtraPath =
    status === 'unauthenticated' && UNAUTHENTICATED_EXTRA_PATHS.includes(location.pathname)
  if (expected && location.pathname !== expected && !onAllowedExtraPath) {
    return <Navigate to={expected} replace />
  }

  if (status === 'authenticated' && PRE_AUTH_PATHS.includes(location.pathname)) {
    return <Navigate to="/dashboard" replace />
  }

  return <>{children}</>
}
