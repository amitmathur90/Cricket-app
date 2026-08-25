import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { useAuthStore } from '../../../core/auth/authStore'
import { roleAtOrAbove } from '../../../types/organization'
import { RoleGate } from '../../../core/router/RoleGate'
import { StatusPill } from '../../../shared/components/StatusPill'
import { Field, TextInput, PrimaryButton, SecondaryButton, ErrorText } from '../../../shared/components/FormPrimitives'
import { resolveMediaUrl } from '../../../core/api/client'
import { useTeams, useCreateTeam } from '../hooks/useTeams'
import { useTeamTournamentRoster, useRegisterTeamToTournament } from '../hooks/useTeamRoster'
import type { Team } from '../../../types/team'

/** Inline "Add team" form — creates an org-level Team (POST .../teams).
 * Mirrors apps/mobile's AddTeamDialog fields exactly (name + optional
 * short code); logo upload is left out here since it's editable later and
 * TournamentCreatePage already establishes the upload pattern if this needs
 * to grow one. */
function AddTeamForm({ onDone }: { onDone: () => void }) {
  const [name, setName] = useState('')
  const [shortCode, setShortCode] = useState('')
  const createMutation = useCreateTeam()

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    if (!name.trim()) return
    try {
      await createMutation.mutateAsync({ name: name.trim(), shortCode: shortCode.trim() || undefined })
      onDone()
    } catch {
      // stays open, error surfaced below
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-3 rounded-2xl border border-border bg-page p-4">
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Field label="Team name *">
          <TextInput required autoFocus value={name} onChange={(e) => setName(e.target.value)} />
        </Field>
        <Field label="Short code (optional)">
          <TextInput value={shortCode} onChange={(e) => setShortCode(e.target.value)} maxLength={16} />
        </Field>
      </div>
      <ErrorText>{createMutation.isError ? 'Could not create the team.' : null}</ErrorText>
      <div className="flex justify-end gap-2">
        <SecondaryButton type="button" onClick={onDone} disabled={createMutation.isPending}>
          Cancel
        </SecondaryButton>
        <PrimaryButton type="submit" className="w-auto" disabled={createMutation.isPending}>
          {createMutation.isPending ? 'Adding…' : 'Add team'}
        </PrimaryButton>
      </div>
    </form>
  )
}

/** Inline "Register to tournament" action — POST .../register with an
 * optional starting purse (RegisterTeamToTournamentDto.purseTotal). Group
 * assignment is left out: no endpoint lists a tournament's groups for a
 * picker, so offering that field would invite picking an unverifiable id. */
function RegisterAction({ teamId, tournamentId }: { teamId: string; tournamentId: string }) {
  const [open, setOpen] = useState(false)
  const [purse, setPurse] = useState('')
  const registerMutation = useRegisterTeamToTournament(teamId, tournamentId)

  if (!open) {
    return (
      <SecondaryButton type="button" className="w-auto px-3 py-1.5 text-xs" onClick={() => setOpen(true)}>
        Register to tournament
      </SecondaryButton>
    )
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    try {
      const purseTotal = purse.trim() ? Number(purse.trim()) : undefined
      await registerMutation.mutateAsync({ purseTotal })
      setOpen(false)
    } catch {
      // stays open, error surfaced below
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col items-end gap-1.5">
      <div className="flex items-center gap-1.5">
        <TextInput
          type="number"
          min={0}
          step="0.01"
          placeholder="Purse (optional)"
          className="w-32 py-1.5 text-xs"
          value={purse}
          onChange={(e) => setPurse(e.target.value)}
        />
        <SecondaryButton
          type="button"
          className="w-auto px-2 py-1.5 text-xs"
          onClick={() => setOpen(false)}
          disabled={registerMutation.isPending}
        >
          Cancel
        </SecondaryButton>
        <PrimaryButton type="submit" className="w-auto px-3 py-1.5 text-xs" disabled={registerMutation.isPending}>
          {registerMutation.isPending ? 'Registering…' : 'Confirm'}
        </PrimaryButton>
      </div>
      {registerMutation.isError && <ErrorText>Could not register this team.</ErrorText>}
    </form>
  )
}

function TeamRow({ team, tournamentId, canManage }: { team: Team; tournamentId: string; canManage: boolean }) {
  const { data, isLoading } = useTeamTournamentRoster(team.id, tournamentId)

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border px-4 py-4 last:border-b-0">
      <Link to={`/tournaments/${tournamentId}/teams/${team.id}`} className="flex min-w-0 items-center gap-3">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-lg">
          {team.logoUrl ? (
            <img src={resolveMediaUrl(team.logoUrl)} alt="" className="h-full w-full object-cover" />
          ) : (
            '🛡️'
          )}
        </div>
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <span className="truncate text-sm font-semibold text-text-primary">{team.name}</span>
            {team.shortCode && <span className="shrink-0 text-xs text-text-muted">{team.shortCode}</span>}
          </div>
          {!isLoading && data && (
            <p className="text-xs text-text-secondary">
              {data.registered
                ? `${data.roster.length} player${data.roster.length === 1 ? '' : 's'} on roster`
                : 'Not registered in this tournament'}
            </p>
          )}
        </div>
      </Link>

      <div className="flex shrink-0 items-center gap-2">
        {isLoading && <span className="text-xs text-text-muted">Checking…</span>}
        {!isLoading && data?.registered && <StatusPill label="Registered" tone="positive" />}
        {!isLoading && data && !data.registered && canManage && (
          <RegisterAction teamId={team.id} tournamentId={tournamentId} />
        )}
        {!isLoading && data?.registered && (
          <Link
            to={`/tournaments/${tournamentId}/teams/${team.id}`}
            className="text-xs font-semibold text-primary hover:underline"
          >
            View roster →
          </Link>
        )}
      </div>
    </div>
  )
}

/**
 * Teams tab content for TournamentDetailPage. The backend has no "list
 * TournamentTeam rows for a tournament, with team details joined" endpoint
 * — only an org-wide team list (`GET .../teams`) and per-team roster
 * lookups scoped by `teamId`+`tournamentId` (`TeamsController.getRoster`).
 * This mirrors apps/mobile's TeamListTab's own documented judgment call for
 * the identical gap: list every org-level team (the only real listing
 * endpoint) and resolve each one's registration status + roster count for
 * THIS tournament via its own roster lookup — a 404 there means "not
 * registered" (see useTeamTournamentRoster). That's N requests for N org
 * teams, the same accepted small-org tradeoff
 * PlayersService.getRankings documents server-side (N calls, not a bespoke
 * aggregate query, because org/roster sizes here are small).
 *
 * Registration (admin-only, POST .../register) and team creation
 * (POST .../teams) are both real, wired actions — gated by
 * `tournament_admin`, matching @Roles(ORG_ADMIN, TOURNAMENT_ADMIN) on both
 * TeamsController.create and .registerToTournament.
 */
export function TeamsTab({ tournamentId }: { tournamentId: string }) {
  const { data: teams, isLoading, isError } = useTeams()
  const role = useAuthStore((s) => s.role)
  const isSuperAdmin = useAuthStore((s) => s.isSuperAdmin)
  const canManage = roleAtOrAbove(role, 'tournament_admin', isSuperAdmin)
  const [addingTeam, setAddingTeam] = useState(false)

  return (
    <div className="flex flex-col gap-3">
      <RoleGate minRole="tournament_admin">
        {!addingTeam && (
          <div className="flex justify-end">
            <SecondaryButton type="button" className="w-auto" onClick={() => setAddingTeam(true)}>
              + Add team
            </SecondaryButton>
          </div>
        )}
        {addingTeam && <AddTeamForm onDone={() => setAddingTeam(false)} />}
      </RoleGate>

      <div className="rounded-2xl border border-border bg-card">
        {isLoading && <div className="p-6 text-sm text-text-secondary">Loading teams…</div>}

        {isError && <div className="p-6 text-sm text-negative">Could not load teams.</div>}

        {!isLoading && !isError && teams && teams.length === 0 && (
          <div className="p-10 text-center text-sm text-text-muted">
            No teams in this organization yet.{' '}
            {canManage && 'Use "+ Add team" above to create one, then register it into this tournament.'}
          </div>
        )}

        {teams && teams.length > 0 && (
          <div>
            {teams.map((team) => (
              <TeamRow key={team.id} team={team} tournamentId={tournamentId} canManage={canManage} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
