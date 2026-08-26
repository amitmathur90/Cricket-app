import { apiClient } from '../../../core/api/client'
import type {
  CreateVenuePayload,
  CreateVenueUnavailabilityPayload,
  UpdateVenuePayload,
  Venue,
  VenueAvailabilityDay,
  VenueUnavailability,
} from '../../../types/venue'

function base(organizationId: string): string {
  return `/organizations/${organizationId}/venues`
}

/** Talks to VenuesController (apps/backend/src/modules/venues) — org-level
 * venue CRUD under `/organizations/:organizationId/venues`, plus the
 * per-venue availability calendar and unavailability ("Maintenance")
 * records. Every endpoint the controller exposes is covered here. */
export const venuesApi = {
  async list(organizationId: string): Promise<Venue[]> {
    const { data } = await apiClient.get<Venue[]>(base(organizationId))
    return data
  },

  async get(organizationId: string, venueId: string): Promise<Venue> {
    const { data } = await apiClient.get<Venue>(`${base(organizationId)}/${venueId}`)
    return data
  },

  async create(organizationId: string, payload: CreateVenuePayload): Promise<Venue> {
    const { data } = await apiClient.post<Venue>(base(organizationId), payload)
    return data
  },

  async update(organizationId: string, venueId: string, payload: UpdateVenuePayload): Promise<Venue> {
    const { data } = await apiClient.patch<Venue>(`${base(organizationId)}/${venueId}`, payload)
    return data
  },

  async remove(organizationId: string, venueId: string): Promise<void> {
    await apiClient.delete(`${base(organizationId)}/${venueId}`)
  },

  /** Day-by-day availability calendar for `[from, to]` (inclusive ISO
   * dates) — see VenuesService.getAvailability's doc comment for the
   * booked/maintenance/available precedence rules. */
  async getAvailability(organizationId: string, venueId: string, from: string, to: string): Promise<VenueAvailabilityDay[]> {
    const { data } = await apiClient.get<VenueAvailabilityDay[]>(`${base(organizationId)}/${venueId}/availability`, {
      params: { from, to },
    })
    return data
  },

  async listUnavailability(organizationId: string, venueId: string): Promise<VenueUnavailability[]> {
    const { data } = await apiClient.get<VenueUnavailability[]>(`${base(organizationId)}/${venueId}/unavailability`)
    return data
  },

  async addUnavailability(
    organizationId: string,
    venueId: string,
    payload: CreateVenueUnavailabilityPayload,
  ): Promise<VenueUnavailability> {
    const { data } = await apiClient.post<VenueUnavailability>(
      `${base(organizationId)}/${venueId}/unavailability`,
      payload,
    )
    return data
  },

  async removeUnavailability(organizationId: string, venueId: string, unavailabilityId: string): Promise<void> {
    await apiClient.delete(`${base(organizationId)}/${venueId}/unavailability/${unavailabilityId}`)
  },
}
