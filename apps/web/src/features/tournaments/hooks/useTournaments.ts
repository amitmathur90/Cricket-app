import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { tournamentsApi } from '../api/tournamentsApi'

export function useTournaments() {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['tournaments', organizationId],
    queryFn: () => tournamentsApi.list(organizationId!),
    enabled: !!organizationId,
  })
}

export function useTournament(tournamentId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['tournaments', organizationId, tournamentId],
    queryFn: () => tournamentsApi.get(organizationId!, tournamentId!),
    enabled: !!organizationId && !!tournamentId,
  })
}
