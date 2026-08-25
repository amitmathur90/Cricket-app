import { useState } from 'react'
import { useAuthStore } from '../../core/auth/authStore'
import { NotificationBell } from '../../features/notifications/components/NotificationBell'

export function TopBar() {
  const user = useAuthStore((s) => s.user)
  const memberships = useAuthStore((s) => s.memberships)
  const activeOrgId = useAuthStore((s) => s.activeOrgId)
  const logout = useAuthStore((s) => s.logout)
  const [menuOpen, setMenuOpen] = useState(false)

  const activeOrgName = memberships.find((m) => m.organizationId === activeOrgId)?.organization?.name

  return (
    <header className="flex h-16 shrink-0 items-center justify-between border-b border-border bg-card px-6">
      <input
        type="search"
        placeholder="Search…"
        className="w-72 rounded-xl bg-page px-3.5 py-2 text-sm text-text-primary outline-none placeholder:text-text-muted"
      />

      <div className="flex items-center gap-3">
        <NotificationBell />

        <div className="relative">
          <button
            type="button"
            onClick={() => setMenuOpen((v) => !v)}
            className="flex items-center gap-2 rounded-xl px-2 py-1.5 transition hover:bg-page"
          >
            <span className="flex h-8 w-8 items-center justify-center rounded-full bg-primary/10 text-sm font-semibold text-primary">
              {user?.fullName.slice(0, 1).toUpperCase() ?? '?'}
            </span>
            <span className="text-left">
              <span className="block text-sm font-medium text-text-primary">{user?.fullName}</span>
              {activeOrgName && <span className="block text-xs text-text-secondary">{activeOrgName}</span>}
            </span>
          </button>

          {menuOpen && (
            <div className="absolute right-0 top-full mt-2 w-40 rounded-xl border border-border bg-card py-1 shadow-lg">
              <button
                type="button"
                onClick={() => logout()}
                className="block w-full px-4 py-2 text-left text-sm text-negative hover:bg-page"
              >
                Sign out
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  )
}
