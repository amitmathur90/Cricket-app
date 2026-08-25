import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { tournamentsApi } from '../api/tournamentsApi'

export function useAwards(tournamentId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['tournaments', organizationId, tournamentId, 'awards'],
    queryFn: () => tournamentsApi.awards(organizationId!, tournamentId!),
    enabled: !!organizationId && !!tournamentId,
  })
}
