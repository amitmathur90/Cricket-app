import { useState, type FormEvent } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useAuthStore } from '../../../core/auth/authStore'
import { roleAtOrAbove } from '../../../types/organization'
import { StatusPill } from '../../../shared/components/StatusPill'
import { Field, SelectInput, TextInput, PrimaryButton, SecondaryButton, ErrorText } from '../../../shared/components/FormPrimitives'
import { resolveMediaUrl } from '../../../core/api/client'
import { useTeam } from '../hooks/useTeams'
import { useTeamTournamentRoster, useUpdateRosterEntry, useTournamentTeamId } from '../hooks/useTeamRoster'
import { usePlayers } from '../../players/hooks/usePlayers'
import { useAddToRoster } from '../../players/hooks/useAddToRoster'
import { PLAYER_ROLES } from '../../../types/player'
import type { RosterEntry } from '../../../types/team'

function roleLabel(role: RosterEntry['player']['role']): string {
  return PLAYER_ROLES.find((r) => r.value === role)?.label ?? role
}

function RosterRow({
  entry,
  canManage,
  onUpdate,
  isBusy,
}: {
  entry: RosterEntry
  canManage: boolean
  onUpdate: (payload: { isCaptain?: boolean; isViceCaptain?: boolean; isWicketkeeper?: boolean; jerseyNumber?: number }) => void
  isBusy: boolean
}) {
  const [jersey, setJersey] = useState(entry.jerseyNumber?.toString() ?? '')

  function handleJerseySubmit(e: FormEvent) {
    e.preventDefault()
    const trimmed = jersey.trim()
    if (trimmed === '') return
    const n = Number.parseInt(trimmed, 10)
    if (!Number.isNaN(n) && n >= 0) onUpdate({ jerseyNumber: n })
  }

  return (
    <tr className="border-b border-border last:border-b-0">
      <td className="px-4 py-3">
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-base">
            {entry.player.photoUrl ? (
              <img src={resolveMediaUrl(entry.player.photoUrl)} alt="" className="h-full w-full object-cover" />
            ) : (
              '🧑'
            )}
          </div>
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-1.5">
              <span className="text-sm font-medium text-text-primary">{entry.player.fullName}</span>
              {entry.isCaptain && <StatusPill label="C" tone="warning" />}
              {entry.isViceCaptain && <StatusPill label="VC" tone="info" />}
              {entry.isWicketkeeper && <StatusPill label="WK" tone="navy" />}
              {!entry.player.isAvailable && <StatusPill label="Unavailable" tone="negative" />}
            </div>
            <p className="text-xs text-text-secondary">{roleLabel(entry.player.role)}</p>
          </div>
        </div>
      </td>
      <td className="px-4 py-3 text-sm text-text-primary">
        {canManage ? (
          <form className="flex items-center gap-1.5" onSubmit={handleJerseySubmit}>
            <TextInput
              type="number"
              min={0}
              className="w-16 px-2 py-1.5 text-xs"
              value={jersey}
              onChange={(e) => setJersey(e.target.value)}
              disabled={isBusy}
            />
            <SecondaryButton type="submit" className="w-auto px-2 py-1.5 text-xs" disabled={isBusy}>
              Set
            </SecondaryButton>
          </form>
        ) : (
          (entry.jerseyNumber ?? '—')
        )}
      </td>
      {canManage && (
        <td className="px-4 py-3">
          <div className="flex flex-wrap gap-1.5">
            <SecondaryButton
              type="button"
              className="w-auto px-2 py-1.5 text-xs"
              disabled={isBusy}
              onClick={() => onUpdate({ isCaptain: !entry.isCaptain })}
            >
              {entry.isCaptain ? 'Unset captain' : 'Make captain'}
            </SecondaryButton>
            <SecondaryButton
              type="button"
              className="w-auto px-2 py-1.5 text-xs"
              disabled={isBusy}
              onClick={() => onUpdate({ isViceCaptain: !entry.isViceCaptain })}
            >
              {entry.isViceCaptain ? 'Unset VC' : 'Make VC'}
            </SecondaryButton>
            <SecondaryButton
              type="button"
              className="w-auto px-2 py-1.5 text-xs"
              disabled={isBusy}
              onClick={() => onUpdate({ isWicketkeeper: !entry.isWicketkeeper })}
            >
              {entry.isWicketkeeper ? 'Unset WK' : 'Make WK'}
            </SecondaryButton>
          </div>
        </td>
      )}
    </tr>
  )
}

/** Add-to-roster form. `AddToRosterDto`/`PlayersController.addToRoster` is
 * scoped by `tournamentTeamId`, not `teamId`+`tournamentId` — see
 * useTournamentTeamId's doc comment for how that id is resolved (a
 * documented, pre-existing gap in the backend, not something invented
 * here). While that id is still resolving (or if it can't be resolved,
 * e.g. this team really isn't registered in the tournament) the form is
 * disabled with an explanatory note instead of silently failing. */
function AddPlayerForm({
  teamId,
  tournamentId,
  rosterPlayerIds,
  onDone,
}: {
  teamId: string
  tournamentId: string
  rosterPlayerIds: Set<string>
  onDone: () => void
}) {
  const { data: team } = useTeam(teamId)
  const { data: tournamentTeamId, isLoading: resolvingId } = useTournamentTeamId(team, tournamentId)
  const { data: allPlayers } = usePlayers()
  const addMutation = useAddToRoster(tournamentTeamId ?? undefined)
  const [playerId, setPlayerId] = useState('')

  const candidates = (allPlayers ?? []).filter((p) => !rosterPlayerIds.has(p.id))

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    if (!playerId || !tournamentTeamId) return
    try {
      await addMutation.mutateAsync({ playerId, payload: {} })
      setPlayerId('')
      onDone()
    } catch {
      // stays open, error surfaced below
    }
  }

  if (!resolvingId && !tournamentTeamId) {
    return (
      <div className="rounded-2xl border border-dashed border-border p-4 text-sm text-text-muted">
        Couldn't confirm this team's registration for this tournament (needed to add players to its roster) — try
        again from the Teams tab.
      </div>
    )
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-3 rounded-2xl border border-border bg-page p-4">
      <Field label="Player">
        <SelectInput value={playerId} onChange={(e) => setPlayerId(e.target.value)} disabled={resolvingId}>
          <option value="">{resolvingId ? 'Loading…' : 'Select a player'}</option>
          {candidates.map((p) => (
            <option key={p.id} value={p.id}>
              {p.fullName}
            </option>
          ))}
        </SelectInput>
      </Field>
      {candidates.length === 0 && !resolvingId && (
        <p className="text-xs text-text-muted">Every org player is already on this roster.</p>
      )}
      <ErrorText>{addMutation.isError ? 'Could not add this player to the roster.' : null}</ErrorText>
      <div className="flex justify-end gap-2">
        <SecondaryButton type="button" onClick={onDone} disabled={addMutation.isPending}>
          Cancel
        </SecondaryButton>
        <PrimaryButton type="submit" className="w-auto" disabled={addMutation.isPending || !playerId}>
          {addMutation.isPending ? 'Adding…' : 'Add to roster'}
        </PrimaryButton>
      </div>
    </form>
  )
}

/**
 * Team detail — reached from TeamsTab's "View roster" link. Route shape
 * this expects to be wired: `/tournaments/:tournamentId/teams/:teamId`.
 *
 * Roster mutations supported, gated to `tournament_admin`+ (matches
 * `@Roles(ORG_ADMIN, TOURNAMENT_ADMIN)` on both
 * `TeamsController.updateRosterEntry` and `PlayersController.addToRoster`):
 *  - Add a player to the roster (create) — see AddPlayerForm.
 *  - Edit an entry's captain/vice-captain/wicketkeeper flags and jersey
 *    number (`PATCH .../roster/:teamPlayerId`).
 *
 * Deliberately NOT offered: removing a roster entry. Neither
 * `TeamsController` nor `PlayersController` exposes a DELETE for
 * `team_players` — there is no backend support for it, so no such action is
 * shown here (an honest gap, not an oversight).
 */
export function TeamDetailPage() {
  const { tournamentId, teamId } = useParams<{ tournamentId: string; teamId: string }>()
  const { data: team, isLoading: teamLoading, isError: teamError } = useTeam(teamId)
  const { data: rosterData, isLoading: rosterLoading, isError: rosterError } = useTeamTournamentRoster(teamId, tournamentId)
  const role = useAuthStore((s) => s.role)
  const isSuperAdmin = useAuthStore((s) => s.isSuperAdmin)
  const canManage = roleAtOrAbove(role, 'tournament_admin', isSuperAdmin)
  const updateMutation = useUpdateRosterEntry(teamId, tournamentId)
  const [addingPlayer, setAddingPlayer] = useState(false)

  if (!tournamentId || !teamId) {
    return <div className="text-sm text-negative">Missing tournament or team id.</div>
  }

  if (teamLoading) {
    return <div className="text-sm text-text-secondary">Loading team…</div>
  }

  if (teamError || !team) {
    return (
      <div className="rounded-2xl border border-negative/30 bg-negative/5 p-6 text-sm text-negative">
        Could not load this team.
      </div>
    )
  }

  const roster = rosterData?.roster ?? []
  const rosterPlayerIds = new Set(roster.map((r) => r.playerId))

  return (
    <div className="flex flex-col gap-4">
      <div>
        <Link to={`/tournaments/${tournamentId}`} className="text-xs font-medium text-text-secondary hover:text-primary">
          ← Tournament
        </Link>
        <div className="mt-1 flex flex-wrap items-center gap-3">
          <div className="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-xl">
            {team.logoUrl ? (
              <img src={resolveMediaUrl(team.logoUrl)} alt="" className="h-full w-full object-cover" />
            ) : (
              '🛡️'
            )}
          </div>
          <div>
            <h1 className="text-2xl font-bold text-text-primary">{team.name}</h1>
            {team.shortCode && <p className="text-sm text-text-secondary">{team.shortCode}</p>}
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between">
        <h2 className="text-sm font-semibold text-text-primary">
          Roster {rosterData?.registered && `(${roster.length})`}
        </h2>
        {canManage && rosterData?.registered && !addingPlayer && (
          <SecondaryButton type="button" className="w-auto" onClick={() => setAddingPlayer(true)}>
            + Add player
          </SecondaryButton>
        )}
      </div>

      {addingPlayer && (
        <AddPlayerForm
          teamId={teamId}
          tournamentId={tournamentId}
          rosterPlayerIds={rosterPlayerIds}
          onDone={() => setAddingPlayer(false)}
        />
      )}

      {rosterLoading && <div className="text-sm text-text-secondary">Loading roster…</div>}

      {rosterError && (
        <div className="rounded-2xl border border-negative/30 bg-negative/5 p-6 text-sm text-negative">
          Could not load this team's roster.
        </div>
      )}

      {!rosterLoading && !rosterError && rosterData && !rosterData.registered && (
        <div className="rounded-2xl border border-dashed border-border p-10 text-center text-sm text-text-muted">
          {team.name} is not registered in this tournament yet. Register it from the Teams tab to build a roster.
        </div>
      )}

      {!rosterLoading && !rosterError && rosterData?.registered && roster.length === 0 && (
        <div className="rounded-2xl border border-dashed border-border p-10 text-center text-sm text-text-muted">
          {team.name} has no roster entries in this tournament yet.
        </div>
      )}

      {roster.length > 0 && (
        <div className="overflow-x-auto rounded-2xl border border-border bg-card">
          <table className="w-full min-w-[520px] border-collapse text-sm">
            <thead>
              <tr className="bg-page text-xs font-semibold uppercase tracking-wide text-text-secondary">
                <th className="px-4 py-3 text-left">Player</th>
                <th className="px-4 py-3 text-left">Jersey</th>
                {canManage && <th className="px-4 py-3 text-left">Actions</th>}
              </tr>
            </thead>
            <tbody>
              {roster.map((entry) => (
                <RosterRow
                  key={entry.id}
                  entry={entry}
                  canManage={canManage}
                  isBusy={updateMutation.isPending}
                  onUpdate={(payload) => updateMutation.mutate({ teamPlayerId: entry.id, payload })}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
