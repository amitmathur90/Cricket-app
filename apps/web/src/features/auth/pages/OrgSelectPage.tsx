import { useAuthStore } from '../../../core/auth/authStore'
import { ErrorText } from '../../../shared/components/FormPrimitives'

export function OrgSelectPage() {
  const memberships = useAuthStore((s) => s.memberships)
  const selectOrg = useAuthStore((s) => s.selectOrg)
  const isBusy = useAuthStore((s) => s.isBusy)
  const errorMessage = useAuthStore((s) => s.errorMessage)

  return (
    <div className="flex min-h-screen items-center justify-center bg-page px-4">
      <div className="w-full max-w-md rounded-2xl border border-border bg-card p-8 shadow-sm">
        <h2 className="mb-1 text-xl font-bold text-text-primary">Choose an organization</h2>
        <p className="mb-6 text-sm text-text-secondary">You belong to more than one — pick which to manage.</p>

        <ErrorText>{errorMessage}</ErrorText>

        <div className="mt-4 flex flex-col gap-2">
          {memberships.map((m) => (
            <button
              key={m.id}
              type="button"
              disabled={isBusy}
              onClick={() => void selectOrg(m.organizationId)}
              className="flex items-center justify-between rounded-xl border border-border bg-page px-4 py-3 text-left transition hover:border-primary disabled:opacity-60"
            >
              <div>
                <p className="text-sm font-semibold text-text-primary">
                  {m.organization?.name ?? m.organizationId}
                </p>
                <p className="text-xs capitalize text-text-secondary">{m.role.replace('_', ' ')}</p>
              </div>
              <span className="text-text-muted">→</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
