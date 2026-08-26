/** Mirrors `VenueStatus` in apps/backend/src/database/entities/venue.entity.ts. */
export type VenueStatus = 'active' | 'inactive'

export const VENUE_STATUS_LABELS: Record<VenueStatus, string> = {
  active: 'Active',
  inactive: 'Inactive',
}

/**
 * Mirrors the `Venue` entity (apps/backend/src/database/entities/venue.entity.ts)
 * exactly — a lightweight org-level venue/ground profile: no login/user
 * account, just enough identity (name, location, capacity, pitch type,
 * facilities, photo) to assign a real venue to a match instead of (or in
 * addition to) the free-text `Match.venueName` fallback.
 *
 * This is the canonical Venue shape for the web app. `MatchVenue` in
 * types/match.ts is a duplicated subset of these same fields, added earlier
 * so the matches feature could render/pick a venue before this Venues
 * feature module existed — see that file's doc comment. The two shapes are
 * identical field-for-field today; `MatchVenue` could be replaced by this
 * `Venue` type (or this one imported and reused) as a follow-up cleanup, but
 * that wasn't done here since it touches the matches feature's types file
 * and wasn't part of this task.
 */
export interface Venue {
  id: string
  organizationId: string
  name: string
  location: string | null
  capacity: number | null
  /** Free text, e.g. "Grass", "Turf", "Matting" — deliberately not an enum. */
  pitchType: string | null
  /** Free text list/description, e.g. "Parking, Floodlights, Pavilion". */
  facilities: string | null
  photoUrl: string | null
  status: VenueStatus
  createdAt: string
}

/** Mirrors CreateVenueDto (apps/backend/src/modules/venues/dto) — only
 * `name` is required. */
export interface CreateVenuePayload {
  name: string
  location?: string
  capacity?: number
  pitchType?: string
  facilities?: string
  photoUrl?: string
  status?: VenueStatus
}

/** Mirrors UpdateVenueDto — PartialType(CreateVenueDto). */
export type UpdateVenuePayload = Partial<CreateVenuePayload>

/** Mirrors `VenueDayStatus` in apps/backend/src/modules/venues/venues.service.ts. */
export type VenueDayStatus = 'available' | 'booked' | 'maintenance'

export const VENUE_DAY_STATUS_LABELS: Record<VenueDayStatus, string> = {
  available: 'Available',
  booked: 'Booked',
  maintenance: 'Maintenance',
}

/**
 * One day of the day-by-day availability calendar returned by
 * `GET .../venues/:venueId/availability`. "booked" is derived from matches
 * scheduled at this venue; "maintenance" from an explicit
 * `VenueUnavailability` record; booked wins if a day somehow has both (see
 * VenuesService.getAvailability's doc comment).
 */
export interface VenueAvailabilityDay {
  /** ISO date, YYYY-MM-DD. */
  date: string
  status: VenueDayStatus
}

/**
 * Mirrors apps/backend/src/database/entities/venue-unavailability.entity.ts
 * — an explicit "this venue is unavailable on this date" record (the
 * "Maintenance" side of the availability calendar; "Booked" days are
 * derived from matches and have no corresponding row here).
 */
export interface VenueUnavailability {
  id: string
  venueId: string
  /** ISO date, YYYY-MM-DD. */
  date: string
  reason: string | null
  createdAt: string
}

/** Mirrors CreateVenueUnavailabilityDto — one single date per record (the
 * backend has no date-range endpoint; marking a span unavailable means
 * creating one record per day). */
export interface CreateVenueUnavailabilityPayload {
  /** ISO date, YYYY-MM-DD. */
  date: string
  reason?: string
}
