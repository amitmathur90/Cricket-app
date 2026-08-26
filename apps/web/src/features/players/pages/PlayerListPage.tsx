import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { StatusPill } from '../../../shared/components/StatusPill'
import { TextInput } from '../../../shared/components/FormPrimitives'
import { RoleGate } from '../../../core/router/RoleGate'
import { resolveMediaUrl } from '../../../core/api/client'
import { usePlayers } from '../hooks/usePlayers'
import { playerVerificationStatusTone } from '../statusTones'
import { PLAYER_VERIFICATION_STATUS_LABELS, type Player, type PlayerVerificationStatus } from '../../../types/player'

const FILTERS: { label: string; value: PlayerVerificationStatus | undefined }[] = [
  { label: 'All', value: undefined },
  { label: 'Pending', value: 'pending' },
  { label: 'Verified', value: 'verified' },
  { label: 'Approved', value: 'approved' },
  { label: 'Rejected', value: 'rejected' },
]

function FilterChip({ label, selected, onClick }: { label: string; selected: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`rounded-full border px-3 py-1 text-xs font-semibold transition ${
        selected
          ? 'border-primary bg-primary/10 text-primary'
          : 'border-border bg-card text-text-secondary hover:bg-page'
      }`}
    >
      {label}
    </button>
  )
}

function PlayerRow({ player }: { player: Player }) {
  return (
    <Link
      to={`/players/${player.id}`}
      className="flex items-center justify-between gap-3 border-b border-border px-4 py-3 last:border-b-0 hover:bg-page"
    >
      <div className="flex min-w-0 items-center gap-3">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-lg">
          {player.photoUrl ? (
            <img src={resolveMediaUrl(player.photoUrl)} alt="" className="h-full w-full object-cover" />
          ) : (
            '🧑'
          )}
        </div>
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <span className="truncate text-sm font-semibold text-text-primary">{player.fullName}</span>
            <StatusPill
              label={PLAYER_VERIFICATION_STATUS_LABELS[player.verificationStatus]}
              tone={playerVerificationStatusTone(player.verificationStatus)}
            />
            {!player.isAvailable && <StatusPill label="Unavailable" tone="negative" />}
          </div>
          <p className="truncate text-xs text-text-secondary">
            {[player.role.replace('_', '-'), player.ageCategory, player.battingStyle, player.bowlingStyle, player.rating ? `★ ${player.rating}` : null]
              .filter(Boolean)
              .join(' · ')}
          </p>
        </div>
      </div>
    </Link>
  )
}

/**
 * Org-wide player list — `GET .../players` (flat, org-level; there is no
 * tournament-scoped variant, see PlayersTab's doc comment) with a name
 * search box and verification-status filter chips (mirrors
 * ApplicationsTab's identical filter-chip pattern). Reviewing a player's
 * verification status happens on PlayerDetailPage
 * (RegistrationReviewPanel) — this list is deliberately read-mostly, one tap
 * away from the real actions, same "list links to detail for actions"
 * shape TeamsTab uses for roster management.
 */
export function PlayerListPage() {
  const { data: players, isLoading, isError } = usePlayers()
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<PlayerVerificationStatus | undefined>(undefined)

  const filtered = useMemo(() => {
    if (!players) return []
    const query = search.trim().toLowerCase()
    return players.filter((p) => {
      if (statusFilter && p.verificationStatus !== statusFilter) return false
      if (query && !p.fullName.toLowerCase().includes(query)) return false
      return true
    })
  }, [players, search, statusFilter])

  return (
    <div>
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-text-primary">Players</h1>
          <p className="mt-1 text-sm text-text-secondary">Every player profile in your organization.</p>
        </div>
        <RoleGate minRole="tournament_admin">
          <Link
            to="/players/create"
            className="rounded-xl bg-primary px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-primary-dark"
          >
            + Register Player
          </Link>
        </RoleGate>
      </div>

      <div className="mt-6 flex flex-col gap-3">
        <TextInput
          type="search"
          placeholder="Search by name…"
          className="max-w-sm"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <div className="flex flex-wrap gap-2">
          {FILTERS.map((f) => (
            <FilterChip key={f.label} label={f.label} selected={statusFilter === f.value} onClick={() => setStatusFilter(f.value)} />
          ))}
        </div>
      </div>

      <div className="mt-4 rounded-2xl border border-border bg-card">
        {isLoading && <div className="p-6 text-sm text-text-secondary">Loading players…</div>}

        {isError && <div className="p-6 text-sm text-negative">Could not load players. Try refreshing the page.</div>}

        {!isLoading && !isError && players && players.length === 0 && (
          <div className="p-10 text-center text-sm text-text-muted">
            No players in this organization yet.{' '}
            <RoleGate minRole="tournament_admin">
              <>
                Get started by{' '}
                <Link to="/players/create" className="font-semibold text-primary hover:underline">
                  registering one
                </Link>
                .
              </>
            </RoleGate>
          </div>
        )}

        {!isLoading && !isError && players && players.length > 0 && filtered.length === 0 && (
          <div className="p-10 text-center text-sm text-text-muted">No players match this search/filter.</div>
        )}

        {filtered.length > 0 && (
          <div>
            {filtered.map((player) => (
              <PlayerRow key={player.id} player={player} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
