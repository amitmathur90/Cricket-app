import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { auctionApi } from '../api/auctionApi'
import type { AddToPoolPayload } from '../../../types/auction'

export function useAuctionPool(tournamentId: string | undefined, sessionId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['auction-pool', organizationId, sessionId],
    queryFn: () => auctionApi.listPool(organizationId!, tournamentId!, sessionId!),
    enabled: !!organizationId && !!tournamentId && !!sessionId,
  })
}

export function useAddToPool(tournamentId: string | undefined, sessionId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: AddToPoolPayload) => auctionApi.addToPool(organizationId!, tournamentId!, sessionId!, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['auction-pool', organizationId, sessionId] })
    },
  })
}
