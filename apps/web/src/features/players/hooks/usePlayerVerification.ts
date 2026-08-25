import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { playersApi } from '../api/playersApi'
import type { RatePlayerPayload, VerifyPlayerPayload } from '../../../types/player'

/** Backs RegistrationReviewPanel — see that component and
 * ALLOWED_VERIFICATION_TRANSITIONS (types/player.ts) for the legal-transition
 * rules this must respect client-side (the server is the real enforcer). */
export function useSetVerification(playerId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: VerifyPlayerPayload) => playersApi.setVerification(organizationId!, playerId!, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['players', organizationId] })
    },
  })
}

export function useSetRating(playerId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: RatePlayerPayload) => playersApi.setRating(organizationId!, playerId!, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['players', organizationId] })
    },
  })
}
