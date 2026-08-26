import { apiClient } from '../../../core/api/client'
import type { CreateSponsorPayload, Sponsor, UpdateSponsorPayload } from '../../../types/sponsor'

/** Wraps apps/backend/src/modules/sponsors (SponsorsController) — org-level
 * sponsor CRUD under `/organizations/:organizationId/sponsors`, including
 * the 5 display-surface visibility flags. All 5 controller endpoints. */
export const sponsorsApi = {
  async list(organizationId: string): Promise<Sponsor[]> {
    const { data } = await apiClient.get<Sponsor[]>(`/organizations/${organizationId}/sponsors`)
    return data
  },

  async get(organizationId: string, sponsorId: string): Promise<Sponsor> {
    const { data } = await apiClient.get<Sponsor>(`/organizations/${organizationId}/sponsors/${sponsorId}`)
    return data
  },

  async create(organizationId: string, payload: CreateSponsorPayload): Promise<Sponsor> {
    const { data } = await apiClient.post<Sponsor>(`/organizations/${organizationId}/sponsors`, payload)
    return data
  },

  async update(organizationId: string, sponsorId: string, payload: UpdateSponsorPayload): Promise<Sponsor> {
    const { data } = await apiClient.patch<Sponsor>(
      `/organizations/${organizationId}/sponsors/${sponsorId}`,
      payload,
    )
    return data
  },

  async remove(organizationId: string, sponsorId: string): Promise<void> {
    await apiClient.delete(`/organizations/${organizationId}/sponsors/${sponsorId}`)
  },
}
