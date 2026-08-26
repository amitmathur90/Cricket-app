import { Link, useParams } from 'react-router-dom'
import { useTournament } from '../../tournaments/hooks/useTournaments'
import { useAuctionSession } from '../hooks/useAuctionSessions'
import { useAuctionReport } from '../hooks/useAuctionReport'
import type { AuctionReportPlayerOutcome, AuctionReportTeamSummary } from '../../../types/auction'

/**
 * Per-team auction dashboard: every team from the report, each with its
 * points (initial/remaining/spent), squad-so-far count, and the exact list
 * of players it won — all sourced straight from useAuctionReport (teams[]
 * for the aggregates, players[] filtered client-side by soldToTeamId for
 * the purchased-players list), no separate fetch. Shows every team on one
 * page rather than a single-team route — a session usually has few enough
 * teams that scrolling one page beats picking a team first, and it matches
 * how LiveAuctionRoomPage's "Teams" panel already lists every team at once.
 */
export function TeamAuctionDashboardPage() {
  const { tournamentId, sessionId } = useParams<{ tournamentId: string; sessionId: string }>()
  const { data: tournament } = useTournament(tournamentId)
  const { data: session } = useAuctionSession(tournamentId, sessionId)
  const { data: report, isLoading, isError } = useAuctionReport(tournamentId, sessionId)

  if (!tournamentId || !sessionId) return null

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-4">
      <div>
        <Link
          to={`/tournaments/${tournamentId}/auction/${sessionId}`}
          className="text-xs font-medium text-text-secondary hover:text-primary"
        >
          ← Back to auction room
        </Link>
        <h1 className="mt-2 text-2xl font-bold text-text-primary">Team Auction Dashboard</h1>
        {tournament && session && (
          <p className="mt-0.5 text-sm text-text-secondary">
            {tournament.name} · {session.name}
          </p>
        )}
      </div>

      {isLoading && <div className="text-sm text-text-secondary">Loading team dashboards…</div>}

      {isError && (
        <div className="rounded-2xl border border-negative/30 bg-negative/5 p-6 text-sm text-negative">
          Could not load the auction report.
        </div>
      )}

      {report && report.teams.length === 0 && (
        <div className="rounded-2xl border border-dashed border-border p-10 text-center text-sm text-text-muted">
          No teams are registered for this auction session yet.
        </div>
      )}

      {report && report.teams.length > 0 && (
        <div className="flex flex-col gap-4">
          {report.teams.map((team) => (
            <TeamDashboardCard
              key={team.tournamentTeamId}
              team={team}
              players={report.players.filter((p) => p.soldToTeamId === team.tournamentTeamId)}
              maxSquadSize={session?.maxSquadSize ?? null}
            />
          ))}
        </div>
      )}
    </div>
  )
}

function TeamDashboardCard({
  team,
  players,
  maxSquadSize,
}: {
  team: AuctionReportTeamSummary
  players: AuctionReportPlayerOutcome[]
  maxSquadSize: number | null
}) {
  const squadLabel = maxSquadSize != null ? `${team.playersBought}/${maxSquadSize}` : `${team.playersBought}`

  return (
    <div className="rounded-2xl border border-border bg-card p-5">
      <h2 className="text-base font-bold text-text-primary">{team.teamName}</h2>

      <div className="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Stat label="Initial Points" value={team.purseTotal ?? '—'} />
        <Stat label="Remaining Points" value={team.purseRemaining ?? '—'} />
        <Stat label="Players" value={squadLabel} />
        <Stat label="Total Spent" value={team.totalSpent} />
      </div>

      <div className="mt-4">
        <p className="text-xs font-semibold uppercase tracking-wide text-text-secondary">
          Purchased Players ({players.length})
        </p>
        {players.length === 0 ? (
          <p className="mt-1.5 text-xs text-text-muted">No players purchased yet.</p>
        ) : (
          <div className="mt-2 flex flex-col gap-0.5">
            {players.map((p) => (
              <div
                key={p.playerId}
                className="flex items-center justify-between border-b border-border py-1.5 text-sm last:border-b-0"
              >
                <span className="text-text-primary">{p.playerName}</span>
                <span className="font-semibold text-text-primary">₹{p.finalPrice}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-page px-3 py-2.5">
      <p className="text-xs text-text-secondary">{label}</p>
      <p className="text-base font-bold text-text-primary">{value}</p>
    </div>
  )
}
