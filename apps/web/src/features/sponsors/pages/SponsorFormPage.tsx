import { useState, type ChangeEvent } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useAuthStore } from '../../../core/auth/authStore'
import { resolveMediaUrl, uploadFile } from '../../../core/api/client'
import { Field, TextInput, SelectInput, PrimaryButton, SecondaryButton, ErrorText } from '../../../shared/components/FormPrimitives'
import { useSponsor } from '../hooks/useSponsors'
import { useCreateSponsor } from '../hooks/useCreateSponsor'
import { useUpdateSponsor } from '../hooks/useUpdateSponsor'
import type { CreateSponsorPayload, Sponsor, SponsorStatus } from '../../../types/sponsor'
import { SPONSOR_STATUS_LABELS } from '../../../types/sponsor'

function emptyToUndefined(text: string): string | undefined {
  const trimmed = text.trim()
  return trimmed === '' ? undefined : trimmed
}

const VISIBILITY_TOGGLES: { key: keyof VisibilityFlags; label: string }[] = [
  { key: 'visibleOnWebsite', label: 'Website' },
  { key: 'visibleOnApp', label: 'App' },
  { key: 'visibleOnMatchScreen', label: 'Match Screen' },
  { key: 'visibleOnScoreboard', label: 'Scoreboard' },
  { key: 'visibleOnSocialMedia', label: 'Social Media' },
]

interface VisibilityFlags {
  visibleOnWebsite: boolean
  visibleOnApp: boolean
  visibleOnMatchScreen: boolean
  visibleOnScoreboard: boolean
  visibleOnSocialMedia: boolean
}

/**
 * Create/edit sponsor — one form covering every field CreateSponsorDto/
 * UpdateSponsorDto accept, same "one route, presence of `:sponsorId` decides
 * create vs. edit" pattern as MatchFormPage. Ported from
 * SponsorFormDialog.dart's modal dialog to a dedicated page per this app's
 * routing convention (dialogs aren't used elsewhere in this app for
 * create/edit flows).
 *
 * Judgment call: unlike the mobile dialog (which never exposes `status`,
 * always defaulting new sponsors to "active"), this form includes a
 * Status select. `status` is a real, documented field on
 * CreateSponsorDto/UpdateSponsorDto and this is the only admin surface that
 * could ever flip a sponsor to "inactive" — leaving it out here would mean
 * no UI anywhere can set it.
 *
 * This outer component is just a data-fetching shell — it waits for the
 * existing sponsor (edit mode) to load, then hands it to `SponsorFormFields`
 * keyed by the sponsor id, so that component's state can be initialized
 * directly from props via `useState` initializers instead of a `useEffect`.
 */
export function SponsorFormPage() {
  const { sponsorId } = useParams<{ sponsorId?: string }>()
  const isEditing = !!sponsorId

  const { data: existing, isLoading: isLoadingExisting } = useSponsor(sponsorId)

  if (isEditing && isLoadingExisting) {
    return <div className="text-sm text-text-secondary">Loading sponsor…</div>
  }

  return <SponsorFormFields key={existing?.id ?? 'new'} sponsorId={sponsorId} existing={existing ?? null} />
}

function SponsorFormFields({ sponsorId, existing }: { sponsorId: string | undefined; existing: Sponsor | null }) {
  const isEditing = !!sponsorId
  const navigate = useNavigate()
  const organizationId = useAuthStore((s) => s.activeOrgId)

  const createMutation = useCreateSponsor()
  const updateMutation = useUpdateSponsor()
  const submitting = createMutation.isPending || updateMutation.isPending

  const [companyName, setCompanyName] = useState(existing?.companyName ?? '')
  const [logoUrl, setLogoUrl] = useState<string | null>(existing?.logoUrl ?? null)
  const [uploadingLogo, setUploadingLogo] = useState(false)
  const [packageName, setPackageName] = useState(existing?.packageName ?? '')
  const [amount, setAmount] = useState(existing?.amount ?? '')
  const [contractStartDate, setContractStartDate] = useState(existing?.contractStartDate ?? '')
  const [contractEndDate, setContractEndDate] = useState(existing?.contractEndDate ?? '')
  const [status, setStatus] = useState<SponsorStatus>(existing?.status ?? 'active')
  const [visibility, setVisibility] = useState<VisibilityFlags>({
    visibleOnWebsite: existing?.visibleOnWebsite ?? false,
    visibleOnApp: existing?.visibleOnApp ?? false,
    visibleOnMatchScreen: existing?.visibleOnMatchScreen ?? false,
    visibleOnScoreboard: existing?.visibleOnScoreboard ?? false,
    visibleOnSocialMedia: existing?.visibleOnSocialMedia ?? false,
  })
  const [error, setError] = useState<string | null>(null)

  function toggleVisibility(key: keyof VisibilityFlags) {
    setVisibility((prev) => ({ ...prev, [key]: !prev[key] }))
  }

  async function handleLogoChange(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    event.target.value = ''
    if (!file || !organizationId) return
    setUploadingLogo(true)
    try {
      const formData = new FormData()
      formData.append('file', file)
      const { data } = await uploadFile(`/organizations/${organizationId}/uploads`, formData)
      setLogoUrl((data as { url: string }).url)
    } catch {
      setError('Could not upload logo. You can continue without one.')
    } finally {
      setUploadingLogo(false)
    }
  }

  async function handleSubmit() {
    if (!companyName.trim()) {
      setError('Company name is required')
      return
    }
    if (amount.trim() && Number.isNaN(Number(amount.trim()))) {
      setError('Enter a valid amount')
      return
    }
    if (contractStartDate && contractEndDate && contractEndDate < contractStartDate) {
      setError('Contract end date must be on or after the start date')
      return
    }
    setError(null)

    const payload: CreateSponsorPayload = {
      companyName: companyName.trim(),
      logoUrl: logoUrl ?? undefined,
      packageName: emptyToUndefined(packageName),
      amount: emptyToUndefined(amount),
      contractStartDate: emptyToUndefined(contractStartDate),
      contractEndDate: emptyToUndefined(contractEndDate),
      status,
      ...visibility,
    }

    try {
      if (isEditing && sponsorId) {
        await updateMutation.mutateAsync({ sponsorId, payload })
      } else {
        await createMutation.mutateAsync(payload)
      }
      navigate('/sponsors')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save sponsor')
    }
  }

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="text-2xl font-bold text-text-primary">{isEditing ? 'Edit sponsor' : 'Add sponsor'}</h1>

      <div className="mt-6 flex flex-col gap-4 rounded-2xl border border-border bg-card p-6">
        <Field label="Company name *">
          <TextInput required value={companyName} onChange={(e) => setCompanyName(e.target.value)} />
        </Field>

        <Field label="Logo (optional)">
          <div className="flex items-center gap-3">
            <div className="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-lg">
              {uploadingLogo ? '…' : logoUrl ? <img src={resolveMediaUrl(logoUrl)} alt="" className="h-full w-full object-cover" /> : '🤝'}
            </div>
            <label className="cursor-pointer rounded-xl border border-border bg-page px-3.5 py-2 text-sm font-medium text-text-secondary hover:bg-border/30">
              {logoUrl ? 'Change logo' : 'Upload logo'}
              <input type="file" accept="image/*" className="hidden" onChange={handleLogoChange} disabled={uploadingLogo} />
            </label>
          </div>
        </Field>

        <Field label="Package (optional)">
          <TextInput
            placeholder="e.g. Title Sponsor, Gold, Silver"
            value={packageName}
            onChange={(e) => setPackageName(e.target.value)}
          />
        </Field>

        <Field label="Amount (optional)">
          <TextInput type="number" min={0} step="0.01" value={amount} onChange={(e) => setAmount(e.target.value)} />
        </Field>

        <div className="grid grid-cols-2 gap-4">
          <Field label="Contract start (optional)">
            <TextInput type="date" value={contractStartDate} onChange={(e) => setContractStartDate(e.target.value)} />
          </Field>
          <Field label="Contract end (optional)">
            <TextInput type="date" value={contractEndDate} onChange={(e) => setContractEndDate(e.target.value)} />
          </Field>
        </div>

        <Field label="Status">
          <SelectInput value={status} onChange={(e) => setStatus(e.target.value as SponsorStatus)}>
            {(Object.keys(SPONSOR_STATUS_LABELS) as SponsorStatus[]).map((value) => (
              <option key={value} value={value}>
                {SPONSOR_STATUS_LABELS[value]}
              </option>
            ))}
          </SelectInput>
        </Field>

        <div>
          <p className="mb-2 text-sm font-medium text-text-secondary">Visible on</p>
          <div className="flex flex-col gap-2">
            {VISIBILITY_TOGGLES.map(({ key, label }) => (
              <label key={key} className="flex items-center gap-2 text-sm text-text-primary">
                <input
                  type="checkbox"
                  className="h-4 w-4 rounded border-border text-primary focus:ring-primary/20"
                  checked={visibility[key]}
                  onChange={() => toggleVisibility(key)}
                />
                {label}
              </label>
            ))}
          </div>
        </div>

        <ErrorText>{error}</ErrorText>

        <div className="mt-2 flex justify-end gap-2">
          <SecondaryButton type="button" onClick={() => navigate('/sponsors')} disabled={submitting}>
            Cancel
          </SecondaryButton>
          <PrimaryButton type="button" className="w-auto" onClick={handleSubmit} disabled={submitting || uploadingLogo}>
            {submitting ? 'Saving…' : isEditing ? 'Save changes' : 'Add sponsor'}
          </PrimaryButton>
        </div>
      </div>
    </div>
  )
}
