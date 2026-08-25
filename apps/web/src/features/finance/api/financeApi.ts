import { apiClient } from '../../../core/api/client'
import type { FinanceDashboard } from '../../../types/finance'

export const financeApi = {
  /** Omitting tournamentId aggregates org-wide (see FinanceController.getDashboard). */
  async dashboard(organizationId: string): Promise<FinanceDashboard> {
    const { data } = await apiClient.get<FinanceDashboard>(
      `/organizations/${organizationId}/finance/dashboard`,
    )
    return data
  },
}
