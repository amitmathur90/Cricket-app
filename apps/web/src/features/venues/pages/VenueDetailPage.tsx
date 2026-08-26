import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { RoleGate } from '../../../core/router/RoleGate'
import { StatusPill } from '../../../shared/components/StatusPill'
import { Field, TextInput, PrimaryButton, SecondaryButton, ErrorText } from '../../../shared/components/FormPrimitives'
import { resolveMediaUrl } from '../../../core/api/client'
import { useVenue } from '../hooks/useVenues'
import { useDeleteVenue } from '../hooks/useDeleteVenue'
import { useVenueAvailability } from '../hooks/useVenueAvailability'
import { useAddVenueUnavailability, useRemoveVenueUnavailability, useVenueUnavailability } from '../hooks/useVenueUnavailability'
import { venueDayStatusTone, venueStatusTone } from '../statusTones'
import { VENUE_DAY_STATUS_LABELS, VENUE_STATUS_LABELS } from '../../../types/venue'

const CALENDAR_RANGE_DAYS = 14

function todayKey(): string {
  return new Date().toISOString().slice(0, 10)
}

function addDaysKey(dateKey: string, days: number): string {
  const d = new Date(`${dateKey}T00:00:00.000Z`)
  d.setUTCDate(d.getUTCDate() + days)
  return d.toISOString().slice(0, 10)
}

function formatDateKey(dateKey: string): string {
  const d = new Date(`${dateKey}T00:00:00.000Z`)
  if (Number.isNaN(d.getTime())) return dateKey
  return d.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' })
}

/**
 * Day-by-day availability calendar for a venue, defaulting to the next 14
 * days (mirrors VenueAvailabilityScreen's `_rangeDays` default), with
 * adjustable from/to bounds and a "Mark unavailable" mini-form.
 */
function AvailabilitySection({ venueId }: { venueId: string }) {
  const [from, setFrom] = useState(todayKey())
  const [to, setTo] = useState(addDaysKey(todayKey(), CALENDAR_RANGE_DAYS - 1))
  const [newDate, setNewDate] = useState(todayKey())
  const [newReason, setNewReason] = useState('')
  const [addError, setAddError] = useState<string | null>(null)

  const { data: days, isLoading, isError } = useVenueAvailability(venueId, from, to)
  const addMutation = useAddVenueUnavailability(venueId)

  async function handleMarkUnavailable() {
    if (!newDate) {
      setAddError('Pick a date')
      return
    }
    setAddError(null)
    try {
      await addMutation.mutateAsync({ date: newDate, reason: newReason.trim() || undefined })
      setNewReason('')
    } catch (err) {
      setAddError(err instanceof Error ? err.message : 'Could not mark this date unavailable')
    }
  }

  return (
    <div className="rounded-2xl border border-border bg-card p-5">
      <h3 className="mb-3 text-sm font-semibold text-text-primary">Availability</h3>

      <div className="mb-4 grid grid-cols-2 gap-4">
        <Field label="From">
          <TextInput type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
        </Field>
        <Field label="To">
          <TextInput type="date" value={to} onChange={(e) => setTo(e.target.value)} />
        </Field>
      </div>

      {isLoading && <div className="text-sm text-text-secondary">Loading availability…</div>}
      {isError && <div className="text-sm text-negative">Could not load availability for this range.</div>}

      {days && days.length > 0 && (
        <div className="mb-5 divide-y divide-border overflow-hidden rounded-xl border border-border">
          {days.map((day) => (
            <div key={day.date} className="flex items-center justify-between bg-page/40 px-3.5 py-2.5">
              <span className="text-sm text-text-primary">{formatDateKey(day.date)}</span>
              <StatusPill label={VENUE_DAY_STATUS_LABELS[day.status]} tone={venueDayStatusTone(day.status)} />
            </div>
          ))}
        </div>
      )}

      <RoleGate minRole="tournament_admin">
        <div className="border-t border-border pt-4">
          <h4 className="mb-2 text-xs font-semibold uppercase tracking-wide text-text-muted">Mark a date unavailable</h4>
          <div className="flex flex-wrap items-end gap-3">
            <Field label="Date">
              <TextInput type="date" value={newDate} onChange={(e) => setNewDate(e.target.value)} />
            </Field>
            <Field label="Reason (optional)">
              <TextInput
                placeholder="e.g. Maintenance, Ground re-turfing"
                value={newReason}
                onChange={(e) => setNewReason(e.target.value)}
              />
            </Field>
            <PrimaryButton type="button" className="w-auto" onClick={handleMarkUnavailable} disabled={addMutation.isPending}>
              {addMutation.isPending ? 'Saving…' : 'Mark unavailable'}
            </PrimaryButton>
          </div>
          <ErrorText>{addError}</ErrorText>
          <p className="mt-2 text-xs text-text-muted">
            Marks a single date (there's no date-range endpoint — a multi-day block means one entry per day).
          </p>
        </div>
      </RoleGate>
    </div>
  )
}

/**
 * Raw list of a venue's `VenueUnavailability` records, separate from the
 * derived calendar above — this is what lets an admin actually remove a
 * "Maintenance" entry once it's no longer needed. The mobile app's
 * VenuesRepository has the same list/remove methods but no screen wires
 * them up to a delete action; added here since the backend endpoint exists
 * and an admin has no other way to undo a mistaken "Mark unavailable".
 */
function UnavailabilityRecordsSection({ venueId }: { venueId: string }) {
  const { data: records, isLoading, isError } = useVenueUnavailability(venueId)
  const removeMutation = useRemoveVenueUnavailability(venueId)
  const [removeError, setRemoveError] = useState<string | null>(null)

  async function handleRemove(id: string) {
    setRemoveError(null)
    try {
      await removeMutation.mutateAsync(id)
    } catch (err) {
      setRemoveError(err instanceof Error ? err.message : 'Could not remove this record')
    }
  }

  return (
    <div className="rounded-2xl border border-border bg-card p-5">
      <h3 className="mb-3 text-sm font-semibold text-text-primary">Unavailability records</h3>

      {isLoading && <div className="text-sm text-text-secondary">Loading records…</div>}
      {isError && <div className="text-sm text-negative">Could not load unavailability records.</div>}
      {records && records.length === 0 && <div className="text-sm text-text-muted">No unavailability records.</div>}

      {records && records.length > 0 && (
        <div className="divide-y divide-border">
          {records.map((record) => (
            <div key={record.id} className="flex items-center justify-between gap-3 py-2.5">
              <div className="min-w-0">
                <span className="text-sm font-medium text-text-primary">{formatDateKey(record.date)}</span>
                {record.reason && <span className="ml-2 text-sm text-text-secondary">{record.reason}</span>}
              </div>
              <RoleGate minRole="tournament_admin">
                <button
                  type="button"
                  onClick={() => handleRemove(record.id)}
                  disabled={removeMutation.isPending}
                  className="shrink-0 text-xs font-semibold text-negative hover:underline disabled:opacity-60"
                >
                  Remove
                </button>
              </RoleGate>
            </div>
          ))}
        </div>
      )}

      <ErrorText>{removeError}</ErrorText>
    </div>
  )
}

function DetailRow({ label, value }: { label: string; value: string | null | undefined }) {
  if (!value) return null
  return (
    <div className="flex items-center justify-between gap-4 py-2.5">
      <span className="text-sm text-text-secondary">{label}</span>
      <span className="max-w-[60%] truncate text-right text-sm font-semibold text-text-primary">{value}</span>
    </div>
  )
}

/**
 * Venue detail page — profile card plus the full availability/unavailability
 * management surface (calendar + mark-unavailable + record list). Route
 * shape this expects to be wired: `/venues/:venueId`.
 */
export function VenueDetailPage() {
  const { venueId } = useParams<{ venueId: string }>()
  const navigate = useNavigate()
  const { data: venue, isLoading, isError } = useVenue(venueId)
  const deleteMutation = useDeleteVenue()
  const [deleteError, setDeleteError] = useState<string | null>(null)

  async function handleDelete() {
    if (!venue) return
    const confirmed = window.confirm(
      `Delete "${venue.name}"? Matches that reference this venue keep their history but show no venue assigned.`,
    )
    if (!confirmed) return
    setDeleteError(null)
    try {
      await deleteMutation.mutateAsync(venue.id)
      navigate('/venues')
    } catch (err) {
      setDeleteError(err instanceof Error ? err.message : 'Could not delete this venue')
    }
  }

  if (isLoading) {
    return <div className="text-sm text-text-secondary">Loading venue…</div>
  }

  if (isError || !venue || !venueId) {
    return (
      <div className="rounded-2xl border border-negative/30 bg-negative/5 p-6 text-sm text-negative">
        Could not load this venue.
      </div>
    )
  }

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-4">
      <Link to="/venues" className="text-xs font-medium text-text-secondary hover:text-primary">
        ← Venues
      </Link>

      <div className="rounded-2xl border border-border bg-card p-5">
        <div className="flex items-start justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-2xl">
              {venue.photoUrl ? (
                <img src={resolveMediaUrl(venue.photoUrl)} alt="" className="h-full w-full object-cover" />
              ) : (
                '📍'
              )}
            </div>
            <div className="min-w-0">
              <h1 className="truncate text-lg font-bold text-text-primary">{venue.name}</h1>
              <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
                <StatusPill label={VENUE_STATUS_LABELS[venue.status]} tone={venueStatusTone(venue.status)} />
                {venue.pitchType && <StatusPill label={venue.pitchType} tone="navy" />}
              </div>
            </div>
          </div>

          <RoleGate minRole="tournament_admin">
            <div className="flex shrink-0 gap-2">
              <Link
                to={`/venues/${venue.id}/edit`}
                className="rounded-xl border border-border bg-card px-5 py-2.5 text-sm font-semibold text-text-primary transition hover:bg-page"
              >
                Edit
              </Link>
              <SecondaryButton
                type="button"
                className="w-auto border-negative/30 text-negative hover:bg-negative/5"
                onClick={handleDelete}
                disabled={deleteMutation.isPending}
              >
                {deleteMutation.isPending ? 'Deleting…' : 'Delete'}
              </SecondaryButton>
            </div>
          </RoleGate>
        </div>

        <ErrorText>{deleteError}</ErrorText>

        <div className="mt-4 divide-y divide-border border-t border-border">
          <DetailRow label="Location" value={venue.location} />
          <DetailRow label="Capacity" value={venue.capacity != null ? String(venue.capacity) : null} />
          <DetailRow label="Pitch type" value={venue.pitchType} />
        </div>

        {venue.facilities && (
          <div className="mt-2 border-t border-border pt-3">
            <span className="text-sm text-text-secondary">Facilities</span>
            <p className="mt-1 whitespace-pre-wrap text-sm text-text-primary">{venue.facilities}</p>
          </div>
        )}
      </div>

      <AvailabilitySection venueId={venueId} />
      <UnavailabilityRecordsSection venueId={venueId} />
    </div>
  )
}
