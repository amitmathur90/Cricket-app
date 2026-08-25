import { apiClient } from '../../../core/api/client'

export const notificationsApi = {
  async unreadCount(organizationId: string): Promise<number> {
    const { data } = await apiClient.get<{ count: number }>(
      `/organizations/${organizationId}/notifications/unread-count`,
    )
    return data.count
  },
}
