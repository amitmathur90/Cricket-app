import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  Field,
  TextInput,
  SelectInput,
  PrimaryButton,
  SecondaryButton,
  ErrorText,
} from '../../../shared/components/FormPrimitives'
import { useMatch } from '../hooks/useMatches'
import { useCreateMatch } from '../hooks/useCreateMatch'
import { useUpdateMatch } from '../hooks/useUpdateMatch'
import { useOfficialOptions, useTournamentTeamOptions, useVenueOptions } from '../hooks/useMatchOptions'
import type { CreateMatchPayload, Match } from '../../../types/match'

/** `<input type="datetime-local">` wants local "yyyy-MM-ddTHH:mm", no
 * timezone/seconds — converts to/from the ISO strings the API sends/expects. */
function toDatetimeLocalValue(iso: string | null): string {
  if (!iso) return ''
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return ''
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

function fromDatetimeLocalValue(value: string): string | undefined {
  if (!value) return undefined
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return undefined
  return date.toISOString()
}

function emptyToUndefined(value: string): string | undefined {
  const trimmed = value.trim()
  return trimmed === '' ? undefined : trimmed
}

/**
 * Create/edit match — a single form covering every field CreateMatchDto/
 * UpdateMatchDto accept, same "one route, presence of `:matchId` decides
 * create vs. edit" pattern as the rest of this app (mirrors
 * match_form_screen.dart's `existing != null` check, adapted to a route
 * param instead of a passed-in object). The backend documents "Create
 * match", "Assign teams", "Assign venue", "Assign umpire/scorer" and
 * "Reschedule" as distinct admin actions, but they're all the same PATCH
 * under the hood — so one form covers all of them for both create and edit.
 *
 * Venue/umpire/scorer each have two independent ways to set them, mirroring
 * the backend's dual-field approach: the legacy free-text field, and an
 * optional dropdown picking a real Venue/Official record. Neither clears
 * the other. Match referee has no free-text legacy field (never existed),
 * so its dropdown is the only way to assign one.
 *
 * This outer component is just a data-fetching shell — it waits for the
 * existing match (edit mode) to load, then hands it to `MatchFormFields`
 * keyed by the match id, so that component's state can be initialized
 * directly from props (a `useState` initializer) instead of copied in via
 * a `useEffect`, which would re-render an extra time and trip
 * react/set-state-in-effect for no benefit here.
 */
export function MatchFormPage() {
  const { tournamentId, matchId } = useParams<{ tournamentId: string; matchId?: string }>()
  const isEditing = !!matchId

  const { data: existing, isLoading: isLoadingExisting } = useMatch(tournamentId, matchId)

  if (!tournamentId) return null

  if (isEditing && isLoadingExisting) {
    return <div className="text-sm text-text-secondary">Loading match…</div>
  }

  return (
    <MatchFormFields
      key={existing?.id ?? 'new'}
      tournamentId={tournamentId}
      matchId={matchId}
      existing={existing ?? null}
    />
  )
}

function MatchFormFields({
  tournamentId,
  matchId,
  existing,
}: {
  tournamentId: string
  matchId: string | undefined
  existing: Match | null
}) {
  const isEditing = !!matchId
  const navigate = useNavigate()

  const { data: teams } = useTournamentTeamOptions(tournamentId)
  const { data: venues } = useVenueOptions()
  const { data: umpires } = useOfficialOptions('umpire')
  const { data: scorers } = useOfficialOptions('scorer')
  const { data: matchReferees } = useOfficialOptions('match_referee')

  const createMutation = useCreateMatch(tournamentId)
  const updateMutation = useUpdateMatch(tournamentId)
  const submitting = createMutation.isPending || updateMutation.isPending

  const [homeTournamentTeamId, setHomeTournamentTeamId] = useState(existing?.homeTournamentTeamId ?? '')
  const [awayTournamentTeamId, setAwayTournamentTeamId] = useState(existing?.awayTournamentTeamId ?? '')
  const [scheduledAt, setScheduledAt] = useState(toDatetimeLocalValue(existing?.scheduledAt ?? null))
  const [venueName, setVenueName] = useState(existing?.venueName ?? '')
  const [venueId, setVenueId] = useState(existing?.venueId ?? '')
  const [umpireName, setUmpireName] = useState(existing?.umpireName ?? '')
  const [umpireOfficialId, setUmpireOfficialId] = useState(existing?.umpireOfficialId ?? '')
  const [scorerName, setScorerName] = useState(existing?.scorerName ?? '')
  const [scorerOfficialId, setScorerOfficialId] = useState(existing?.scorerOfficialId ?? '')
  const [matchRefereeOfficialId, setMatchRefereeOfficialId] = useState(existing?.matchRefereeOfficialId ?? '')
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit() {
    if (homeTournamentTeamId && awayTournamentTeamId && homeTournamentTeamId === awayTournamentTeamId) {
      setError('Home and away team must be different')
      return
    }
    setError(null)

    const payload: CreateMatchPayload = {
      homeTournamentTeamId: emptyToUndefined(homeTournamentTeamId),
      awayTournamentTeamId: emptyToUndefined(awayTournamentTeamId),
      scheduledAt: fromDatetimeLocalValue(scheduledAt),
      venueName: emptyToUndefined(venueName),
      umpireName: emptyToUndefined(umpireName),
      scorerName: emptyToUndefined(scorerName),
      venueId: emptyToUndefined(venueId),
      umpireOfficialId: emptyToUndefined(umpireOfficialId),
      scorerOfficialId: emptyToUndefined(scorerOfficialId),
      matchRefereeOfficialId: emptyToUndefined(matchRefereeOfficialId),
    }

    try {
      if (isEditing && matchId) {
        await updateMutation.mutateAsync({ matchId, payload })
        navigate(`/tournaments/${tournamentId}/matches/${matchId}`)
      } else {
        const created = await createMutation.mutateAsync(payload)
        navigate(`/tournaments/${tournamentId}/matches/${created.id}`)
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save match')
    }
  }

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="text-2xl font-bold text-text-primary">{isEditing ? 'Edit match' : 'Add match'}</h1>

      <div className="mt-6 flex flex-col gap-4 rounded-2xl border border-border bg-card p-6">
        {teams && teams.length === 0 && (
          <p className="rounded-lg bg-page px-3 py-2 text-xs text-text-secondary">
            No teams are registered in this tournament yet — this match will be created as TBD vs TBD. Venue,
            officials, and the date can still be set below, and teams can be assigned later.
          </p>
        )}

        <div className="grid grid-cols-2 gap-4">
          <Field label="Home team">
            <SelectInput value={homeTournamentTeamId} onChange={(e) => setHomeTournamentTeamId(e.target.value)}>
              <option value="">TBD</option>
              {teams?.map((team) => (
                <option key={team.tournamentTeamId} value={team.tournamentTeamId}>
                  {team.name}
                </option>
              ))}
            </SelectInput>
          </Field>
          <Field label="Away team">
            <SelectInput value={awayTournamentTeamId} onChange={(e) => setAwayTournamentTeamId(e.target.value)}>
              <option value="">TBD</option>
              {teams?.map((team) => (
                <option key={team.tournamentTeamId} value={team.tournamentTeamId}>
                  {team.name}
                </option>
              ))}
            </SelectInput>
          </Field>
        </div>

        <Field label="Date & time (optional)">
          <TextInput type="datetime-local" value={scheduledAt} onChange={(e) => setScheduledAt(e.target.value)} />
        </Field>

        <Field label="Venue (optional)">
          <TextInput value={venueName} onChange={(e) => setVenueName(e.target.value)} placeholder="Venue name" />
        </Field>
        <Field label="Or select an existing venue (optional)">
          <SelectInput value={venueId} onChange={(e) => setVenueId(e.target.value)}>
            <option value="">None</option>
            {venues?.map((venue) => (
              <option key={venue.id} value={venue.id}>
                {venue.name}
              </option>
            ))}
          </SelectInput>
        </Field>

        <Field label="Umpire (optional)">
          <TextInput value={umpireName} onChange={(e) => setUmpireName(e.target.value)} placeholder="Umpire name" />
        </Field>
        <Field label="Or select an umpire (optional)">
          <SelectInput value={umpireOfficialId} onChange={(e) => setUmpireOfficialId(e.target.value)}>
            <option value="">None</option>
            {umpires?.map((official) => (
              <option key={official.id} value={official.id}>
                {official.fullName}
              </option>
            ))}
          </SelectInput>
        </Field>

        <Field label="Scorer (optional)">
          <TextInput value={scorerName} onChange={(e) => setScorerName(e.target.value)} placeholder="Scorer name" />
        </Field>
        <Field label="Or select a scorer (optional)">
          <SelectInput value={scorerOfficialId} onChange={(e) => setScorerOfficialId(e.target.value)}>
            <option value="">None</option>
            {scorers?.map((official) => (
              <option key={official.id} value={official.id}>
                {official.fullName}
              </option>
            ))}
          </SelectInput>
        </Field>

        <Field label="Match referee (optional)">
          <SelectInput value={matchRefereeOfficialId} onChange={(e) => setMatchRefereeOfficialId(e.target.value)}>
            <option value="">None</option>
            {matchReferees?.map((official) => (
              <option key={official.id} value={official.id}>
                {official.fullName}
              </option>
            ))}
          </SelectInput>
        </Field>

        <ErrorText>{error}</ErrorText>

        <div className="mt-2 flex justify-end gap-2">
          <SecondaryButton
            type="button"
            onClick={() =>
              navigate(isEditing ? `/tournaments/${tournamentId}/matches/${matchId}` : `/tournaments/${tournamentId}`)
            }
            disabled={submitting}
          >
            Cancel
          </SecondaryButton>
          <PrimaryButton type="button" className="w-auto" onClick={handleSubmit} disabled={submitting}>
            {submitting ? 'Saving…' : isEditing ? 'Save changes' : 'Create match'}
          </PrimaryButton>
        </div>
      </div>
    </div>
  )
}
