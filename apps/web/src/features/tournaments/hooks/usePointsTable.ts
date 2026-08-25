import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { tournamentsApi } from '../api/tournamentsApi'

export function usePointsTable(tournamentId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['tournaments', organizationId, tournamentId, 'points-table'],
    queryFn: () => tournamentsApi.pointsTable(organizationId!, tournamentId!),
    enabled: !!organizationId && !!tournamentId,
  })
}
