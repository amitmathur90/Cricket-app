import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { teamsApi } from '../api/teamsApi'
import type { CreateTeamPayload } from '../../../types/team'

export function useTeams() {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['teams', organizationId],
    queryFn: () => teamsApi.list(organizationId!),
    enabled: !!organizationId,
  })
}

export function useTeam(teamId: string | undefined) {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  return useQuery({
    queryKey: ['teams', organizationId, teamId],
    queryFn: () => teamsApi.get(organizationId!, teamId!),
    enabled: !!organizationId && !!teamId,
  })
}

export function useCreateTeam() {
  const organizationId = useAuthStore((s) => s.activeOrgId)
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: CreateTeamPayload) => teamsApi.create(organizationId!, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['teams', organizationId] })
    },
  })
}
