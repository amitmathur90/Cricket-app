import { useAuthStore } from '../auth/authStore'
import { roleAtOrAbove, type OrgRole } from '../../types/organization'

/** Hides children unless the current user's role is at-or-above `minRole`.
 * This is UX only — the real boundary is RolesGuard on the backend; every
 * mutation still gets its authoritative 403 from the API regardless of
 * what this component shows or hides. */
export function RoleGate({ minRole, children }: { minRole: OrgRole; children: React.ReactNode }) {
  const role = useAuthStore((s) => s.role)
  const isSuperAdmin = useAuthStore((s) => s.isSuperAdmin)
  if (!roleAtOrAbove(role, minRole, isSuperAdmin)) return null
  return <>{children}</>
}
