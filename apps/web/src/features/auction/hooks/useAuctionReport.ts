import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { auctionApi } from '../api/auctionApi'

export function useAuctionReport(tournamentId: string | undefined, sessionId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['auction-report', organizationId, sessionId],
    queryFn: () => auctionApi.getReport(organizationId!, tournamentId!, sessionId!),
    enabled: !!organizationId && !!tournamentId && !!sessionId,
  })
}
