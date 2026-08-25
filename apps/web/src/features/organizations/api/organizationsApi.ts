import { apiClient } from '../../../core/api/client'
import type { Organization } from '../../../types/organization'

export const organizationsApi = {
  async create(name: string, slug?: string): Promise<Organization> {
    const { data } = await apiClient.post<Organization>('/organizations', { name, slug })
    return data
  },
}
