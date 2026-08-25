import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { playersApi } from '../api/playersApi'

export function usePlayerStatistics(playerId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['players', organizationId, playerId, 'statistics'],
    queryFn: () => playersApi.getStatistics(organizationId!, playerId!),
    enabled: !!organizationId && !!playerId,
  })
}
