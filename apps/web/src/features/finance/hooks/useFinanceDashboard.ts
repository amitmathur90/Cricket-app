import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { financeApi } from '../api/financeApi'

/** Org-wide revenue aggregate for the Dashboard's Revenue card. */
export function useOrgFinanceDashboard() {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['finance', 'dashboard', organizationId, 'org-wide'],
    queryFn: () => financeApi.dashboard(organizationId!),
    enabled: !!organizationId,
  })
}
