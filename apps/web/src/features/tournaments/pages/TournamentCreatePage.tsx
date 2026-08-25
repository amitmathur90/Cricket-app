import { useState, type ChangeEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '../../../core/auth/authStore'
import { resolveMediaUrl, uploadFile } from '../../../core/api/client'
import { Field, TextInput, Textarea, SelectInput, PrimaryButton, SecondaryButton, ErrorText } from '../../../shared/components/FormPrimitives'
import { useCreateTournament } from '../hooks/useCreateTournament'
import { useUpdateTournament } from '../hooks/useUpdateTournament'
import { TOURNAMENT_FORMATS, type CreateTournamentPayload, type TournamentFormat } from '../../../types/tournament'

const EMAIL_PATTERN = /^[^@\s]+@[^@\s]+\.[^@\s]+$/

const STEPS = ['Basic information', 'Tournament details', 'Rules', 'Registration', 'Review'] as const

interface WizardState {
  name: string
  description: string
  organizerName: string
  contactEmail: string
  contactPhone: string
  logoUrl: string | null

  format: TournamentFormat
  startDate: string
  endDate: string
  location: string
  numberOfTeams: string
  maxPlayersPerTeam: string
  auctionEnabled: boolean

  tournamentRules: string
  matchRules: string
  pointsSystem: string
  tieBreakerRules: string

  registrationOpensAt: string
  registrationClosesAt: string
  playerRegistrationFee: string
  teamRegistrationFee: string
}

const INITIAL_STATE: WizardState = {
  name: '',
  description: '',
  organizerName: '',
  contactEmail: '',
  contactPhone: '',
  logoUrl: null,
  format: 't20',
  startDate: '',
  endDate: '',
  location: '',
  numberOfTeams: '',
  maxPlayersPerTeam: '',
  auctionEnabled: false,
  tournamentRules: '',
  matchRules: '',
  pointsSystem: '',
  tieBreakerRules: '',
  registrationOpensAt: '',
  registrationClosesAt: '',
  playerRegistrationFee: '',
  teamRegistrationFee: '',
}

function emptyToUndefined(text: string): string | undefined {
  const trimmed = text.trim()
  return trimmed === '' ? undefined : trimmed
}

function parseIntOrUndefined(text: string): number | undefined {
  const trimmed = text.trim()
  if (trimmed === '') return undefined
  const n = Number.parseInt(trimmed, 10)
  return Number.isNaN(n) ? undefined : n
}

function parseNumOrUndefined(text: string): number | undefined {
  const trimmed = text.trim()
  if (trimmed === '') return undefined
  const n = Number(trimmed)
  return Number.isNaN(n) ? undefined : n
}

function buildPayload(state: WizardState): CreateTournamentPayload {
  return {
    name: state.name.trim(),
    format: state.format,
    startDate: state.startDate,
    endDate: state.endDate,
    auctionEnabled: state.auctionEnabled,
    logoUrl: state.logoUrl ?? undefined,
    description: emptyToUndefined(state.description),
    organizerName: emptyToUndefined(state.organizerName),
    contactEmail: emptyToUndefined(state.contactEmail),
    contactPhone: emptyToUndefined(state.contactPhone),
    location: emptyToUndefined(state.location),
    numberOfTeams: parseIntOrUndefined(state.numberOfTeams),
    maxPlayersPerTeam: parseIntOrUndefined(state.maxPlayersPerTeam),
    tournamentRules: emptyToUndefined(state.tournamentRules),
    matchRules: emptyToUndefined(state.matchRules),
    pointsSystem: emptyToUndefined(state.pointsSystem),
    tieBreakerRules: emptyToUndefined(state.tieBreakerRules),
    registrationOpensAt: emptyToUndefined(state.registrationOpensAt),
    registrationClosesAt: emptyToUndefined(state.registrationClosesAt),
    playerRegistrationFee: parseNumOrUndefined(state.playerRegistrationFee),
    teamRegistrationFee: parseNumOrUndefined(state.teamRegistrationFee),
  }
}

/** Validates one step; returns an error message or null. Mirrors
 * create_tournament_screen.dart's _validateStep. */
function validateStep(step: number, state: WizardState): string | null {
  switch (step) {
    case 0: {
      if (!state.name.trim()) return 'Tournament name is required'
      if (state.contactEmail.trim() && !EMAIL_PATTERN.test(state.contactEmail.trim())) {
        return 'Enter a valid contact email address'
      }
      return null
    }
    case 1: {
      if (!state.startDate || !state.endDate) return 'Pick a start and end date'
      if (state.endDate < state.startDate) return 'End date must be on or after the start date'
      const numberOfTeams = state.numberOfTeams.trim()
      if (numberOfTeams && (Number.parseInt(numberOfTeams, 10) < 1 || Number.isNaN(Number.parseInt(numberOfTeams, 10)))) {
        return 'Number of teams must be a whole number of at least 1'
      }
      const maxPlayers = state.maxPlayersPerTeam.trim()
      if (maxPlayers && (Number.parseInt(maxPlayers, 10) < 1 || Number.isNaN(Number.parseInt(maxPlayers, 10)))) {
        return 'Max players per team must be a whole number of at least 1'
      }
      return null
    }
    case 3: {
      if (state.registrationOpensAt && state.registrationClosesAt && state.registrationClosesAt < state.registrationOpensAt) {
        return 'Registration close date must be on or after the open date'
      }
      const playerFee = state.playerRegistrationFee.trim()
      if (playerFee && Number(playerFee) < 0) return 'Player registration fee must be non-negative'
      const teamFee = state.teamRegistrationFee.trim()
      if (teamFee && Number(teamFee) < 0) return 'Team registration fee must be non-negative'
      return null
    }
    default:
      return null
  }
}

function ReviewRow({ label, value }: { label: string; value: string | number | null | undefined }) {
  if (value === null || value === undefined || value === '') return null
  return (
    <div className="flex gap-4 py-1.5 text-sm">
      <span className="w-44 shrink-0 font-medium text-text-secondary">{label}</span>
      <span className="text-text-primary">{value}</span>
    </div>
  )
}

/**
 * 5-step "Create tournament" wizard, ported field-for-field from
 * create_tournament_screen.dart. Collect-then-submit-once: everything lives
 * in local state until the final step, then one POST .../tournaments (and,
 * for "Publish", a follow-up PATCH setting status: 'upcoming') — same
 * design decision as the mobile wizard's doc comment explains (avoids
 * littering the list with abandoned partial drafts, and logo upload doesn't
 * need a tournament id since uploads are org-scoped).
 */
export function TournamentCreatePage() {
  const navigate = useNavigate()
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const [state, setState] = useState<WizardState>(INITIAL_STATE)
  const [step, setStep] = useState(0)
  const [stepError, setStepError] = useState<string | null>(null)
  const [uploadingLogo, setUploadingLogo] = useState(false)
  const [submitError, setSubmitError] = useState<string | null>(null)

  const createMutation = useCreateTournament()
  const updateMutation = useUpdateTournament()
  const submitting = createMutation.isPending || updateMutation.isPending

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
      navigate('/tournaments')
      return
    }
    setStepError(null)
    setStep((s) => Math.max(s - 1, 0))
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
      update('logoUrl', (data as { url: string }).url)
    } catch {
      setSubmitError('Could not upload logo. You can continue without one.')
    } finally {
      setUploadingLogo(false)
    }
  }

  async function handleSubmit(publish: boolean) {
    // Re-validate every step, in case the user jumped back via a previous
    // "Continue" and left something invalid before returning to Review.
    for (let s = 0; s < 4; s++) {
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
      const created = await createMutation.mutateAsync(buildPayload(state))
      if (publish) {
        await updateMutation.mutateAsync({ tournamentId: created.id, payload: { status: 'upcoming' } })
      }
      navigate(`/tournaments/${created.id}`)
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Could not save tournament')
    }
  }

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="text-2xl font-bold text-text-primary">Create tournament</h1>

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
            <Field label="Tournament name *">
              <TextInput required value={state.name} onChange={(e) => update('name', e.target.value)} />
            </Field>

            <Field label="Logo (optional)">
              <div className="flex items-center gap-3">
                <div className="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-lg">
                  {uploadingLogo ? (
                    '…'
                  ) : state.logoUrl ? (
                    <img src={resolveMediaUrl(state.logoUrl)} alt="" className="h-full w-full object-cover" />
                  ) : (
                    '🏆'
                  )}
                </div>
                <label className="cursor-pointer rounded-xl border border-border bg-page px-3.5 py-2 text-sm font-medium text-text-secondary hover:bg-border/30">
                  {state.logoUrl ? 'Change logo' : 'Upload logo'}
                  <input type="file" accept="image/*" className="hidden" onChange={handleLogoChange} disabled={uploadingLogo} />
                </label>
              </div>
            </Field>

            <Field label="Description (optional)">
              <Textarea rows={3} value={state.description} onChange={(e) => update('description', e.target.value)} />
            </Field>
            <Field label="Organizer name (optional)">
              <TextInput value={state.organizerName} onChange={(e) => update('organizerName', e.target.value)} />
            </Field>
            <Field label="Contact email (optional)">
              <TextInput type="email" value={state.contactEmail} onChange={(e) => update('contactEmail', e.target.value)} />
            </Field>
            <Field label="Contact phone (optional)">
              <TextInput type="tel" value={state.contactPhone} onChange={(e) => update('contactPhone', e.target.value)} />
            </Field>
          </div>
        )}

        {step === 1 && (
          <div className="flex flex-col gap-4">
            <Field label="Format *">
              <SelectInput value={state.format} onChange={(e) => update('format', e.target.value as TournamentFormat)}>
                {TOURNAMENT_FORMATS.map((f) => (
                  <option key={f.value} value={f.value}>
                    {f.label}
                  </option>
                ))}
              </SelectInput>
            </Field>
            <div className="grid grid-cols-2 gap-4">
              <Field label="Start date *">
                <TextInput type="date" required value={state.startDate} onChange={(e) => update('startDate', e.target.value)} />
              </Field>
              <Field label="End date *">
                <TextInput type="date" required value={state.endDate} onChange={(e) => update('endDate', e.target.value)} />
              </Field>
            </div>
            <Field label="Location (optional)">
              <TextInput value={state.location} onChange={(e) => update('location', e.target.value)} />
            </Field>
            <div className="grid grid-cols-2 gap-4">
              <Field label="Number of teams (optional)">
                <TextInput type="number" min={1} value={state.numberOfTeams} onChange={(e) => update('numberOfTeams', e.target.value)} />
              </Field>
              <Field label="Max players per team (optional)">
                <TextInput type="number" min={1} value={state.maxPlayersPerTeam} onChange={(e) => update('maxPlayersPerTeam', e.target.value)} />
              </Field>
            </div>
            <label className="flex items-center gap-2 text-sm text-text-primary">
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-border text-primary focus:ring-primary/20"
                checked={state.auctionEnabled}
                onChange={(e) => update('auctionEnabled', e.target.checked)}
              />
              Auction enabled
            </label>
          </div>
        )}

        {step === 2 && (
          <div className="flex flex-col gap-4">
            <Field label="Tournament rules (optional)">
              <Textarea rows={4} value={state.tournamentRules} onChange={(e) => update('tournamentRules', e.target.value)} />
            </Field>
            <Field label="Match rules (optional)">
              <Textarea rows={4} value={state.matchRules} onChange={(e) => update('matchRules', e.target.value)} />
            </Field>
            <Field label="Points system (optional)">
              <Textarea
                rows={3}
                placeholder="e.g. 2 pts win, 1 pt tie, 0 pt loss"
                value={state.pointsSystem}
                onChange={(e) => update('pointsSystem', e.target.value)}
              />
            </Field>
            <Field label="Tie-breaker rules (optional)">
              <Textarea rows={3} value={state.tieBreakerRules} onChange={(e) => update('tieBreakerRules', e.target.value)} />
            </Field>
          </div>
        )}

        {step === 3 && (
          <div className="flex flex-col gap-4">
            <div className="grid grid-cols-2 gap-4">
              <Field label="Registration opens (optional)">
                <TextInput type="date" value={state.registrationOpensAt} onChange={(e) => update('registrationOpensAt', e.target.value)} />
              </Field>
              <Field label="Registration closes (optional)">
                <TextInput type="date" value={state.registrationClosesAt} onChange={(e) => update('registrationClosesAt', e.target.value)} />
              </Field>
            </div>
            <Field label="Player registration fee (optional)">
              <TextInput type="number" min={0} step="0.01" value={state.playerRegistrationFee} onChange={(e) => update('playerRegistrationFee', e.target.value)} />
            </Field>
            <Field label="Team registration fee (optional)">
              <TextInput type="number" min={0} step="0.01" value={state.teamRegistrationFee} onChange={(e) => update('teamRegistrationFee', e.target.value)} />
            </Field>
          </div>
        )}

        {step === 4 && (
          <div className="flex flex-col">
            <p className="mb-3 text-sm text-text-secondary">
              Review the details below, then save as a draft or publish (publishing sets the tournament status to
              "upcoming").
            </p>
            <div className="divide-y divide-border">
              <div className="pb-2">
                <ReviewRow label="Name" value={state.name} />
                <ReviewRow label="Description" value={state.description} />
                <ReviewRow label="Organizer" value={state.organizerName} />
                <ReviewRow label="Contact email" value={state.contactEmail} />
                <ReviewRow label="Contact phone" value={state.contactPhone} />
              </div>
              <div className="py-2">
                <ReviewRow label="Format" value={TOURNAMENT_FORMATS.find((f) => f.value === state.format)?.label} />
                <ReviewRow label="Dates" value={state.startDate && state.endDate ? `${state.startDate} to ${state.endDate}` : null} />
                <ReviewRow label="Location" value={state.location} />
                <ReviewRow label="Number of teams" value={state.numberOfTeams} />
                <ReviewRow label="Max players per team" value={state.maxPlayersPerTeam} />
                <ReviewRow label="Auction enabled" value={state.auctionEnabled ? 'Yes' : 'No'} />
              </div>
              <div className="py-2">
                <ReviewRow label="Tournament rules" value={state.tournamentRules} />
                <ReviewRow label="Match rules" value={state.matchRules} />
                <ReviewRow label="Points system" value={state.pointsSystem} />
                <ReviewRow label="Tie-breaker rules" value={state.tieBreakerRules} />
              </div>
              <div className="pt-2">
                <ReviewRow label="Registration opens" value={state.registrationOpensAt} />
                <ReviewRow label="Registration closes" value={state.registrationClosesAt} />
                <ReviewRow label="Player registration fee" value={state.playerRegistrationFee} />
                <ReviewRow label="Team registration fee" value={state.teamRegistrationFee} />
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
            <div className="flex gap-2">
              <SecondaryButton type="button" onClick={() => handleSubmit(false)} disabled={submitting}>
                Save as draft
              </SecondaryButton>
              <PrimaryButton type="button" className="w-auto" onClick={() => handleSubmit(true)} disabled={submitting}>
                {submitting ? 'Saving…' : 'Publish'}
              </PrimaryButton>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
