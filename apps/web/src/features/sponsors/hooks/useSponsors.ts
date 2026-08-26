import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { sponsorsApi } from '../api/sponsorsApi'

export function useSponsors() {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['sponsors', organizationId],
    queryFn: () => sponsorsApi.list(organizationId!),
    enabled: !!organizationId,
  })
}

export function useSponsor(sponsorId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['sponsors', organizationId, sponsorId],
    queryFn: () => sponsorsApi.get(organizationId!, sponsorId!),
    enabled: !!organizationId && !!sponsorId,
  })
}
