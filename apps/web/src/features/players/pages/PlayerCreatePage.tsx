import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { resolveMediaUrl, uploadFile } from '../../../core/api/client'
import { Field, TextInput, Textarea, SelectInput, PrimaryButton, SecondaryButton, ErrorText } from '../../../shared/components/FormPrimitives'
import { useCreatePlayer } from '../hooks/usePlayers'
import { playersApi } from '../api/playersApi'
import { PLAYER_ROLES, type CreatePlayerPayload, type PlayerRole } from '../../../types/player'

const EMAIL_PATTERN = /^[^@\s]+@[^@\s]+\.[^@\s]+$/

/** Backend caps `otherDocumentUrls` at 20 (`@ArrayMaxSize(20)` on
 * CreatePlayerDto) — 10 is a friendlier UI cap well under that limit, same
 * as create_player_screen.dart's `_maxOtherDocuments`. */
const MAX_OTHER_DOCUMENTS = 10

const GENDER_OPTIONS = ['Male', 'Female', 'Other', 'Prefer not to say']

const STEPS = ['Personal information', 'Cricket information', 'Documents', 'Availability', 'Submit'] as const

interface OtherDocumentSlot {
  url: string | null
  uploading: boolean
}

interface WizardState {
  // --- Step 0: Personal information ---
  fullName: string
  photoUrl: string | null
  dob: string
  gender: string
  phone: string
  email: string
  address: string

  // --- Step 1: Cricket information ---
  role: PlayerRole
  ageCategory: string
  battingStyle: string
  bowlingStyle: string
  experience: string
  preferredPosition: string
  previousStatsNotes: string

  // --- Step 2: Documents ---
  idDocumentUrl: string | null
  addressProofUrl: string | null

  // --- Step 3: Availability (update-only flags, PATCHed after create — see handleSubmit) ---
  isAvailableForTournaments: boolean
  isAvailableForMatches: boolean
  isAvailableForPractice: boolean
}

const INITIAL_STATE: WizardState = {
  fullName: '',
  photoUrl: null,
  dob: '',
  gender: '',
  phone: '',
  email: '',
  address: '',
  role: 'batsman',
  ageCategory: '',
  battingStyle: '',
  bowlingStyle: '',
  experience: '',
  preferredPosition: '',
  previousStatsNotes: '',
  idDocumentUrl: null,
  addressProofUrl: null,
  isAvailableForTournaments: true,
  isAvailableForMatches: true,
  isAvailableForPractice: true,
}

function emptyToUndefined(text: string): string | undefined {
  const trimmed = text.trim()
  return trimmed === '' ? undefined : trimmed
}

function buildPayload(state: WizardState, otherDocumentUrls: string[]): CreatePlayerPayload {
  return {
    fullName: state.fullName.trim(),
    role: state.role,
    photoUrl: state.photoUrl!,
    idDocumentUrl: state.idDocumentUrl!,
    ageCategory: state.ageCategory.trim(),
    previousStatsNotes: state.previousStatsNotes.trim(),
    dob: emptyToUndefined(state.dob),
    gender: emptyToUndefined(state.gender),
    phone: emptyToUndefined(state.phone),
    email: emptyToUndefined(state.email),
    address: emptyToUndefined(state.address),
    battingStyle: emptyToUndefined(state.battingStyle),
    bowlingStyle: emptyToUndefined(state.bowlingStyle),
    experience: emptyToUndefined(state.experience),
    preferredPosition: emptyToUndefined(state.preferredPosition),
    addressProofUrl: state.addressProofUrl ?? undefined,
    otherDocumentUrls: otherDocumentUrls.length > 0 ? otherDocumentUrls : undefined,
  }
}

/** Validates one step; returns an error message or null. Mirrors
 * create_player_screen.dart's `_validateStep`. */
function validateStep(step: number, state: WizardState): string | null {
  switch (step) {
    case 0: {
      if (!state.fullName.trim()) return 'Full name is required'
      if (!state.photoUrl) return 'Please upload a player photo'
      if (state.email.trim() && !EMAIL_PATTERN.test(state.email.trim())) {
        return 'Enter a valid email address'
      }
      return null
    }
    case 1: {
      if (!state.ageCategory.trim()) return 'Age category is required'
      if (!state.previousStatsNotes.trim()) return 'Previous teams / statistics are required'
      return null
    }
    case 2: {
      if (!state.idDocumentUrl) return 'Please upload an ID document'
      return null
    }
    default:
      return null
  }
}

function ReviewRow({ label, value }: { label: string; value: string | null | undefined }) {
  if (value === null || value === undefined || value === '') return null
  return (
    <div className="flex gap-4 py-1.5 text-sm">
      <span className="w-52 shrink-0 font-medium text-text-secondary">{label}</span>
      <span className="text-text-primary">{value}</span>
    </div>
  )
}

function UploadTile({
  label,
  url,
  uploading,
  required,
  onChange,
}: {
  label: string
  url: string | null
  uploading: boolean
  required: boolean
  onChange: (file: File) => void
}) {
  return (
    <div className="flex items-center gap-3 rounded-xl border border-border bg-page px-3.5 py-2.5">
      <div className="flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-primary/10 text-base">
        {uploading ? '…' : url ? <img src={resolveMediaUrl(url)} alt="" className="h-full w-full object-cover" /> : '📄'}
      </div>
      <span className={`flex-1 text-sm ${url ? 'font-medium text-positive' : 'text-text-secondary'}`}>
        {url ? `${label} uploaded` : `Upload ${label}${required ? ' *' : ' (optional)'}`}
      </span>
      <label className="cursor-pointer rounded-lg border border-border bg-card px-3 py-1.5 text-xs font-semibold text-text-secondary hover:bg-border/30">
        {url ? 'Change' : 'Upload'}
        <input
          type="file"
          accept="image/*,application/pdf"
          className="hidden"
          disabled={uploading}
          onChange={(e) => {
            const file = e.target.files?.[0]
            e.target.value = ''
            if (file) onChange(file)
          }}
        />
      </label>
    </div>
  )
}

/**
 * 5-step "Register player" wizard, ported step-for-step from
 * create_player_screen.dart (Personal Information, Cricket Information,
 * Documents, Availability, Submit). Collect-then-submit-once, same pattern
 * as TournamentCreatePage: everything lives in local state until the final
 * step, then one POST .../players via useCreatePlayer. The granular
 * `isAvailableFor*` flags default to `true` server-side and aren't part of
 * CreatePlayerDto (update-only per player.entity.ts's doc comment), so a
 * follow-up PATCH .../players/:id only fires when the user actually turned
 * one off — avoids a pointless extra call, mirroring the mobile wizard's
 * `_submit` exactly.
 */
export function PlayerCreatePage() {
  const navigate = useNavigate()
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  const [state, setState] = useState<WizardState>(INITIAL_STATE)
  const [otherDocuments, setOtherDocuments] = useState<OtherDocumentSlot[]>([])
  const [step, setStep] = useState(0)
  const [stepError, setStepError] = useState<string | null>(null)
  const [submitError, setSubmitError] = useState<string | null>(null)
  const [uploadingPhoto, setUploadingPhoto] = useState(false)
  const [uploadingIdDocument, setUploadingIdDocument] = useState(false)
  const [uploadingAddressProof, setUploadingAddressProof] = useState(false)
  const [followUpPending, setFollowUpPending] = useState(false)

  const createMutation = useCreatePlayer()
  const submitting = createMutation.isPending || followUpPending

  function update<K extends keyof WizardState>(key: K, value: WizardState[K]) {
    setState((prev) => ({ ...prev, [key]: value }))
  }

  function goNext() {
    const error = validateStep(step, state)
    if (error) {
      setStepError(error)
      return
    }
    setStepError(null)
    setStep((s) => Math.min(s + 1, STEPS.length - 1))
  }

  function goBack() {
    if (step === 0) {
      navigate('/players')
      return
    }
    setStepError(null)
    setStep((s) => Math.max(s - 1, 0))
  }

  async function uploadAndSet(file: File, onSuccess: (url: string) => void, setUploading: (b: boolean) => void) {
    if (!organizationId) return
    setSubmitError(null)
    setUploading(true)
    try {
      const formData = new FormData()
      formData.append('file', file)
      const { data } = await uploadFile(`/organizations/${organizationId}/uploads`, formData)
      onSuccess((data as { url: string }).url)
    } catch {
      setSubmitError('Could not upload the file. Please try again.')
    } finally {
      setUploading(false)
    }
  }

  function handlePhotoChange(file: File) {
    void uploadAndSet(file, (url) => update('photoUrl', url), setUploadingPhoto)
  }

  function handleIdDocumentChange(file: File) {
    void uploadAndSet(file, (url) => update('idDocumentUrl', url), setUploadingIdDocument)
  }

  function handleAddressProofChange(file: File) {
    void uploadAndSet(file, (url) => update('addressProofUrl', url), setUploadingAddressProof)
  }

  function addOtherDocumentSlot() {
    setOtherDocuments((prev) => [...prev, { url: null, uploading: false }])
  }

  function removeOtherDocumentSlot(index: number) {
    setOtherDocuments((prev) => prev.filter((_, i) => i !== index))
  }

  function handleOtherDocumentChange(index: number, file: File) {
    setOtherDocuments((prev) => prev.map((slot, i) => (i === index ? { ...slot, uploading: true } : slot)))
    void uploadAndSet(
      file,
      (url) => setOtherDocuments((prev) => prev.map((slot, i) => (i === index ? { ...slot, url } : slot))),
      (uploading) => setOtherDocuments((prev) => prev.map((slot, i) => (i === index ? { ...slot, uploading } : slot))),
    )
  }

  async function handleSubmit() {
    // Re-validate every step, in case the user jumped back and left something
    // invalid before returning to the Submit step.
    for (let s = 0; s < 3; s++) {
      const error = validateStep(s, state)
      if (error) {
        setStep(s)
        setStepError(error)
        return
      }
    }
    if (!organizationId) return

    setSubmitError(null)
    try {
      const otherDocumentUrls = otherDocuments.map((slot) => slot.url).filter((url): url is string => url !== null)
      const created = await createMutation.mutateAsync(buildPayload(state, otherDocumentUrls))

      if (!state.isAvailableForTournaments || !state.isAvailableForMatches || !state.isAvailableForPractice) {
        setFollowUpPending(true)
        try {
          await playersApi.update(organizationId, created.id, {
            isAvailableForTournaments: state.isAvailableForTournaments,
            isAvailableForMatches: state.isAvailableForMatches,
            isAvailableForPractice: state.isAvailableForPractice,
          })
          queryClient.invalidateQueries({ queryKey: ['players', organizationId] })
        } finally {
          setFollowUpPending(false)
        }
      }

      navigate(`/players/${created.id}`)
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Could not register player')
    }
  }

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="text-2xl font-bold text-text-primary">Register player</h1>

      <ol className="mt-4 flex flex-wrap gap-2">
        {STEPS.map((label, index) => (
          <li
            key={label}
            className={`rounded-full px-3 py-1 text-xs font-semibold ${
              index === step
                ? 'bg-primary text-white'
                : index < step
                  ? 'bg-primary/10 text-primary'
                  : 'bg-page text-text-muted'
            }`}
          >
            {index + 1}. {label}
          </li>
        ))}
      </ol>

      <div className="mt-6 rounded-2xl border border-border bg-card p-6">
        {step === 0 && (
          <div className="flex flex-col gap-4">
            <Field label="Player photo *">
              <UploadTile label="photo" url={state.photoUrl} uploading={uploadingPhoto} required onChange={handlePhotoChange} />
            </Field>
            <Field label="Full name *">
              <TextInput required value={state.fullName} onChange={(e) => update('fullName', e.target.value)} />
            </Field>
            <Field label="Date of birth (optional)">
              <TextInput type="date" value={state.dob} onChange={(e) => update('dob', e.target.value)} />
            </Field>
            <Field label="Gender (optional)">
              <SelectInput value={state.gender} onChange={(e) => update('gender', e.target.value)}>
                <option value="">Not specified</option>
                {GENDER_OPTIONS.map((g) => (
                  <option key={g} value={g}>
                    {g}
                  </option>
                ))}
              </SelectInput>
            </Field>
            <Field label="Phone (optional)">
              <TextInput type="tel" value={state.phone} onChange={(e) => update('phone', e.target.value)} />
            </Field>
            <Field label="Email (optional)">
              <TextInput type="email" value={state.email} onChange={(e) => update('email', e.target.value)} />
            </Field>
            <Field label="Address (optional)">
              <Textarea rows={3} value={state.address} onChange={(e) => update('address', e.target.value)} />
            </Field>
          </div>
        )}

        {step === 1 && (
          <div className="flex flex-col gap-4">
            <Field label="Playing role *">
              <SelectInput value={state.role} onChange={(e) => update('role', e.target.value as PlayerRole)}>
                {PLAYER_ROLES.map((r) => (
                  <option key={r.value} value={r.value}>
                    {r.label}
                  </option>
                ))}
              </SelectInput>
            </Field>
            <Field label="Age category *">
              <TextInput
                required
                placeholder="e.g. U16, U19, Senior, Open"
                value={state.ageCategory}
                onChange={(e) => update('ageCategory', e.target.value)}
              />
            </Field>
            <Field label="Batting style (optional)">
              <TextInput value={state.battingStyle} onChange={(e) => update('battingStyle', e.target.value)} />
            </Field>
            <Field label="Bowling style (optional)">
              <TextInput value={state.bowlingStyle} onChange={(e) => update('bowlingStyle', e.target.value)} />
            </Field>
            <Field label="Experience (optional)">
              <Textarea
                rows={3}
                placeholder="e.g. 5 years club cricket"
                value={state.experience}
                onChange={(e) => update('experience', e.target.value)}
              />
            </Field>
            <Field label="Preferred position (optional)">
              <TextInput
                placeholder="e.g. Opening batsman / slip fielder"
                value={state.preferredPosition}
                onChange={(e) => update('preferredPosition', e.target.value)}
              />
            </Field>
            <Field label="Previous teams / statistics *">
              <Textarea
                rows={3}
                placeholder="Prior experience, notable numbers, past clubs..."
                value={state.previousStatsNotes}
                onChange={(e) => update('previousStatsNotes', e.target.value)}
              />
            </Field>
          </div>
        )}

        {step === 2 && (
          <div className="flex flex-col gap-4">
            {/* Photograph is captured in step 0 (Personal information) — not
                repeated here, since photoUrl is a single field on the
                player, not a "document" in the DTO's document group. */}
            <Field label="ID document *">
              <UploadTile label="ID document" url={state.idDocumentUrl} uploading={uploadingIdDocument} required onChange={handleIdDocumentChange} />
            </Field>
            <Field label="Address proof (optional)">
              <UploadTile
                label="address proof"
                url={state.addressProofUrl}
                uploading={uploadingAddressProof}
                required={false}
                onChange={handleAddressProofChange}
              />
            </Field>

            <div>
              <p className="mb-2 text-sm font-medium text-text-secondary">Other documents (optional)</p>
              <div className="flex flex-col gap-2">
                {otherDocuments.map((slot, index) => (
                  <div key={index} className="flex items-center gap-2">
                    <div className="flex-1">
                      <UploadTile
                        label={`document ${index + 1}`}
                        url={slot.url}
                        uploading={slot.uploading}
                        required={false}
                        onChange={(file) => handleOtherDocumentChange(index, file)}
                      />
                    </div>
                    <button
                      type="button"
                      onClick={() => removeOtherDocumentSlot(index)}
                      className="rounded-lg border border-border bg-card px-2.5 py-2 text-xs font-semibold text-text-secondary hover:bg-page"
                      aria-label="Remove document"
                    >
                      ✕
                    </button>
                  </div>
                ))}
              </div>
              {otherDocuments.length < MAX_OTHER_DOCUMENTS && (
                <SecondaryButton type="button" className="mt-2 w-auto" onClick={addOtherDocumentSlot}>
                  + Add another document
                </SecondaryButton>
              )}
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="flex flex-col gap-4">
            <p className="text-sm text-text-secondary">
              These are separate from the single "mark unavailable" toggle in the player list — they let the player
              be picked (or not) for specific kinds of activity.
            </p>
            <label className="flex items-center justify-between gap-2 rounded-xl border border-border bg-page px-3.5 py-2.5 text-sm text-text-primary">
              Available for tournaments
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-border text-primary focus:ring-primary/20"
                checked={state.isAvailableForTournaments}
                onChange={(e) => update('isAvailableForTournaments', e.target.checked)}
              />
            </label>
            <label className="flex items-center justify-between gap-2 rounded-xl border border-border bg-page px-3.5 py-2.5 text-sm text-text-primary">
              Available for matches
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-border text-primary focus:ring-primary/20"
                checked={state.isAvailableForMatches}
                onChange={(e) => update('isAvailableForMatches', e.target.checked)}
              />
            </label>
            <label className="flex items-center justify-between gap-2 rounded-xl border border-border bg-page px-3.5 py-2.5 text-sm text-text-primary">
              Available for practice
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-border text-primary focus:ring-primary/20"
                checked={state.isAvailableForPractice}
                onChange={(e) => update('isAvailableForPractice', e.target.checked)}
              />
            </label>
          </div>
        )}

        {step === 4 && (
          <div className="flex flex-col">
            <p className="mb-3 text-sm text-text-secondary">Review the details below, then register the player.</p>
            <div className="divide-y divide-border">
              <div className="pb-2">
                <ReviewRow label="Full name" value={state.fullName} />
                <ReviewRow label="Photo" value={state.photoUrl ? 'Uploaded' : null} />
                <ReviewRow label="Date of birth" value={state.dob} />
                <ReviewRow label="Gender" value={state.gender} />
                <ReviewRow label="Phone" value={state.phone} />
                <ReviewRow label="Email" value={state.email} />
                <ReviewRow label="Address" value={state.address} />
              </div>
              <div className="py-2">
                <ReviewRow label="Playing role" value={PLAYER_ROLES.find((r) => r.value === state.role)?.label} />
                <ReviewRow label="Age category" value={state.ageCategory} />
                <ReviewRow label="Batting style" value={state.battingStyle} />
                <ReviewRow label="Bowling style" value={state.bowlingStyle} />
                <ReviewRow label="Experience" value={state.experience} />
                <ReviewRow label="Preferred position" value={state.preferredPosition} />
                <ReviewRow label="Previous teams / statistics" value={state.previousStatsNotes} />
              </div>
              <div className="py-2">
                <ReviewRow label="ID document" value={state.idDocumentUrl ? 'Uploaded' : null} />
                <ReviewRow label="Address proof" value={state.addressProofUrl ? 'Uploaded' : null} />
                <ReviewRow
                  label="Other documents"
                  value={otherDocuments.filter((s) => s.url).length > 0 ? `${otherDocuments.filter((s) => s.url).length} uploaded` : null}
                />
              </div>
              <div className="pt-2">
                <ReviewRow label="Available for tournaments" value={state.isAvailableForTournaments ? 'Yes' : 'No'} />
                <ReviewRow label="Available for matches" value={state.isAvailableForMatches ? 'Yes' : 'No'} />
                <ReviewRow label="Available for practice" value={state.isAvailableForPractice ? 'Yes' : 'No'} />
              </div>
            </div>
          </div>
        )}

        <div className="mt-6 flex flex-col gap-2">
          <ErrorText>{stepError}</ErrorText>
          <ErrorText>{submitError}</ErrorText>
        </div>

        <div className="mt-2 flex justify-between gap-2">
          <SecondaryButton type="button" onClick={goBack} disabled={submitting}>
            Back
          </SecondaryButton>

          {step < STEPS.length - 1 ? (
            <PrimaryButton type="button" className="w-auto" onClick={goNext}>
              Continue
            </PrimaryButton>
          ) : (
            <PrimaryButton type="button" className="w-auto" onClick={handleSubmit} disabled={submitting}>
              {submitting ? 'Registering…' : 'Register player'}
            </PrimaryButton>
          )}
        </div>
      </div>
    </div>
  )
}
