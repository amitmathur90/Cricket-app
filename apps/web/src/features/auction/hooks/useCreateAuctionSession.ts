import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { auctionApi } from '../api/auctionApi'
import type { CreateAuctionSessionPayload } from '../../../types/auction'

export function useCreateAuctionSession(tournamentId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: CreateAuctionSessionPayload) => auctionApi.create(organizationId!, tournamentId!, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['auction-sessions', organizationId, tournamentId] })
    },
  })
}
