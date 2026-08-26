import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { RoleGate } from '../../../core/router/RoleGate'
import { StatusPill } from '../../../shared/components/StatusPill'
import { TextInput } from '../../../shared/components/FormPrimitives'
import { resolveMediaUrl } from '../../../core/api/client'
import { useVenues } from '../hooks/useVenues'
import { venueStatusTone } from '../statusTones'
import { VENUE_STATUS_LABELS, type Venue } from '../../../types/venue'

function VenueRow({ venue }: { venue: Venue }) {
  const subtitleParts = [venue.location, venue.capacity ? `${venue.capacity} capacity` : null].filter(Boolean)

  return (
    <Link
      to={`/venues/${venue.id}`}
      className="flex items-center justify-between gap-3 border-b border-border px-4 py-3 last:border-b-0 hover:bg-page"
    >
      <div className="flex min-w-0 items-center gap-3">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-lg">
          {venue.photoUrl ? (
            <img src={resolveMediaUrl(venue.photoUrl)} alt="" className="h-full w-full object-cover" />
          ) : (
            '📍'
          )}
        </div>
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <span className="truncate text-sm font-semibold text-text-primary">{venue.name}</span>
            {venue.pitchType && <StatusPill label={venue.pitchType} tone="navy" />}
            <StatusPill label={VENUE_STATUS_LABELS[venue.status]} tone={venueStatusTone(venue.status)} />
          </div>
          {subtitleParts.length > 0 && (
            <p className="truncate text-xs text-text-secondary">{subtitleParts.join(' · ')}</p>
          )}
        </div>
      </div>
    </Link>
  )
}

/**
 * Org-wide venue list — `GET .../venues`, name search only (no status
 * filter chips like PlayerListPage since there's no equivalent multi-stage
 * review flow here, just active/inactive). Mirrors VenuesListScreen's
 * "simple CRUD list, no wizard" framing from the mobile app; a click opens
 * VenueDetailPage rather than an edit dialog since the web app doesn't have
 * a modal-dialog component to match VenueFormDialog with.
 */
export function VenueListPage() {
  const { data: venues, isLoading, isError } = useVenues()
  const [search, setSearch] = useState('')

  const filtered = useMemo(() => {
    if (!venues) return []
    const query = search.trim().toLowerCase()
    if (!query) return venues
    return venues.filter((v) => v.name.toLowerCase().includes(query) || v.location?.toLowerCase().includes(query))
  }, [venues, search])

  return (
    <div>
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-text-primary">Venues</h1>
          <p className="mt-1 text-sm text-text-secondary">Grounds and venues available to schedule matches at.</p>
        </div>
        <RoleGate minRole="tournament_admin">
          <Link
            to="/venues/create"
            className="rounded-xl bg-primary px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-primary-dark"
          >
            + Create Venue
          </Link>
        </RoleGate>
      </div>

      <div className="mt-6">
        <TextInput
          type="search"
          placeholder="Search by name or location…"
          className="max-w-sm"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <div className="mt-4 rounded-2xl border border-border bg-card">
        {isLoading && <div className="p-6 text-sm text-text-secondary">Loading venues…</div>}

        {isError && <div className="p-6 text-sm text-negative">Could not load venues. Try refreshing the page.</div>}

        {!isLoading && !isError && venues && venues.length === 0 && (
          <div className="p-10 text-center text-sm text-text-muted">
            No venues yet.{' '}
            <RoleGate minRole="tournament_admin">
              <>
                Get started by{' '}
                <Link to="/venues/create" className="font-semibold text-primary hover:underline">
                  creating one
                </Link>
                .
              </>
            </RoleGate>
          </div>
        )}

        {!isLoading && !isError && venues && venues.length > 0 && filtered.length === 0 && (
          <div className="p-10 text-center text-sm text-text-muted">No venues match this search.</div>
        )}

        {filtered.length > 0 && (
          <div>
            {filtered.map((venue) => (
              <VenueRow key={venue.id} venue={venue} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
