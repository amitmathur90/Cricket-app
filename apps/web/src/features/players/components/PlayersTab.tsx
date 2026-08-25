import { Link } from 'react-router-dom'
import { StatusPill } from '../../../shared/components/StatusPill'
import { resolveMediaUrl } from '../../../core/api/client'
import { usePlayers } from '../hooks/usePlayers'
import { playerVerificationStatusTone } from '../statusTones'
import { PLAYER_VERIFICATION_STATUS_LABELS, type Player } from '../../../types/player'

function PlayerRow({ player }: { player: Player }) {
  return (
    <Link
      to={`/players/${player.id}`}
      className="flex items-center justify-between gap-3 border-b border-border px-4 py-3 last:border-b-0 hover:bg-page"
    >
      <div className="flex min-w-0 items-center gap-3">
        <div className="flex h-9 w-9 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-base">
          {player.photoUrl ? (
            <img src={resolveMediaUrl(player.photoUrl)} alt="" className="h-full w-full object-cover" />
          ) : (
            '🧑'
          )}
        </div>
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <span className="truncate text-sm font-medium text-text-primary">{player.fullName}</span>
            <StatusPill
              label={PLAYER_VERIFICATION_STATUS_LABELS[player.verificationStatus]}
              tone={playerVerificationStatusTone(player.verificationStatus)}
            />
          </div>
          <p className="truncate text-xs text-text-secondary">
            {[player.role.replace('_', '-'), player.ageCategory, player.rating ? `★ ${player.rating}` : null]
              .filter(Boolean)
              .join(' · ')}
          </p>
        </div>
      </div>
      {!player.isAvailable && <StatusPill label="Unavailable" tone="negative" />}
    </Link>
  )
}

/**
 * Players tab content for TournamentDetailPage. `tournamentId` is accepted
 * for prop-shape consistency with the other tabs but is NOT used to filter
 * this list — the backend has no "players registered/rostered for this
 * tournament" endpoint (`PlayersController.findAll` is a flat, org-wide
 * list; the tournament-scoped player relationship only exists indirectly,
 * via TournamentApplication for self-service applications — see
 * ApplicationsTab — or via a team's roster once assigned — see
 * features/teams/TeamsTab). This mirrors apps/mobile's PlayerListTab, which
 * documents the identical finding ("org-level players for the caller's
 * active org... see teams_providers.dart for why this is org-level rather
 * than tournament-roster-scoped").
 */
export function PlayersTab({ tournamentId: _tournamentId }: { tournamentId: string }) {
  const { data: players, isLoading, isError } = usePlayers()

  return (
    <div className="flex flex-col gap-3">
      <p className="text-xs text-text-muted">
        Every player in this organization — there's no tournament-scoped player list on the backend yet (see{' '}
        <Link to="/players" className="font-medium text-primary hover:underline">
          the full Players page
        </Link>{' '}
        for search/filtering, or the Applications tab for this tournament's actual registrations).
      </p>

      <div className="rounded-2xl border border-border bg-card">
        {isLoading && <div className="p-6 text-sm text-text-secondary">Loading players…</div>}

        {isError && <div className="p-6 text-sm text-negative">Could not load players.</div>}

        {!isLoading && !isError && players && players.length === 0 && (
          <div className="p-10 text-center text-sm text-text-muted">No players in this organization yet.</div>
        )}

        {players && players.length > 0 && (
          <div>
            {players.map((player) => (
              <PlayerRow key={player.id} player={player} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
