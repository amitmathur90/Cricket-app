import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { playersApi } from '../api/playersApi'
import type { CreatePlayerPayload, UpdatePlayerPayload } from '../../../types/player'

export function usePlayers() {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['players', organizationId],
    queryFn: () => playersApi.list(organizationId!),
    enabled: !!organizationId,
  })
}

export function usePlayer(playerId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['players', organizationId, playerId],
    queryFn: () => playersApi.get(organizationId!, playerId!),
    enabled: !!organizationId && !!playerId,
  })
}

export function useCreatePlayer() {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: CreatePlayerPayload) => playersApi.create(organizationId!, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['players', organizationId] })
    },
  })
}

export function useUpdatePlayer(playerId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: UpdatePlayerPayload) => playersApi.update(organizationId!, playerId!, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['players', organizationId] })
    },
  })
}
