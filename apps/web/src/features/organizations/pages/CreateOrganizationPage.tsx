import { useState, type FormEvent } from 'react'
import { useAuthStore } from '../../../core/auth/authStore'
import { organizationsApi } from '../api/organizationsApi'
import { Field, TextInput, PrimaryButton, ErrorText } from '../../../shared/components/FormPrimitives'

/** Shown when a logged-in user has zero active org memberships — a
 * brand-new user with nothing to manage yet. The creator becomes an active
 * org_admin member of the new org automatically (see OrganizationsService),
 * so this just creates it, then selects it. */
export function CreateOrganizationPage() {
  const [name, setName] = useState('')
  const [isBusy, setIsBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const selectOrg = useAuthStore((s) => s.selectOrg)

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setIsBusy(true)
    setError(null)
    try {
      const org = await organizationsApi.create(name)
      await selectOrg(org.id)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create organization')
    } finally {
      setIsBusy(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-page px-4">
      <div className="w-full max-w-sm rounded-2xl border border-border bg-card p-8 shadow-sm">
        <h2 className="mb-1 text-xl font-bold text-text-primary">Create your organization</h2>
        <p className="mb-6 text-sm text-text-secondary">You'll be its admin.</p>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <Field label="Organization name">
            <TextInput required value={name} onChange={(e) => setName(e.target.value)} />
          </Field>
          <ErrorText>{error}</ErrorText>
          <PrimaryButton type="submit" disabled={isBusy}>
            {isBusy ? 'Creating…' : 'Create organization'}
          </PrimaryButton>
        </form>
      </div>
    </div>
  )
}
