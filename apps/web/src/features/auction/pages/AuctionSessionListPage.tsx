import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { RoleGate } from '../../../core/router/RoleGate'
import { StatusPill, type PillTone } from '../../../shared/components/StatusPill'
import { useAuctionSessions } from '../hooks/useAuctionSessions'
import { CreateAuctionSessionForm } from '../components/CreateAuctionSessionForm'
import { AUCTION_SESSION_STATUS_LABELS, type AuctionSession, type AuctionSessionStatus } from '../../../types/auction'

function statusTone(status: AuctionSessionStatus): PillTone {
  switch (status) {
    case 'live':
      return 'live'
    case 'paused':
      return 'warning'
    case 'completed':
      return 'neutral'
    default:
      return 'info'
  }
}

function SessionRow({ tournamentId, session }: { tournamentId: string; session: AuctionSession }) {
  // A scheduled session has nothing to watch yet — route to pool setup
  // (add lots / Start Auction) instead of the live room, which would just
  // show "hasn't started" with a link back here.
  const to =
    session.status === 'scheduled'
      ? `/tournaments/${tournamentId}/auction/${session.id}/pool`
      : `/tournaments/${tournamentId}/auction/${session.id}`

  return (
    <Link
      to={to}
      className="flex items-center justify-between gap-3 border-b border-border px-4 py-3 last:border-b-0 hover:bg-page"
    >
      <div className="min-w-0">
        <p className="truncate text-sm font-semibold text-text-primary">{session.name}</p>
        <p className="mt-0.5 text-xs text-text-secondary">
          {session.durationMinutes ? `${session.durationMinutes} min budget · ` : ''}
          {session.maxSquadSize ? `Max squad ${session.maxSquadSize}` : 'No squad cap'}
        </p>
      </div>
      <StatusPill label={AUCTION_SESSION_STATUS_LABELS[session.status]} tone={statusTone(session.status)} />
    </Link>
  )
}

/**
 * A tournament's auction sessions — list plus an inline "Create Auction
 * Session" form (toggled open/closed, no separate route: the task only
 * calls for "an action opening a settings form", and this keeps the create
 * flow one click away rather than a full page navigation). On create,
 * routes straight to the new session's pool page so the admin's next step
 * (add lots, then Start) is immediate.
 */
export function AuctionSessionListPage() {
  const { tournamentId } = useParams<{ tournamentId: string }>()
  const navigate = useNavigate()
  const { data: sessions, isLoading, isError } = useAuctionSessions(tournamentId)
  const [showCreate, setShowCreate] = useState(false)

  if (!tournamentId) return null

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-4">
      <div>
        <Link to={`/tournaments/${tournamentId}`} className="text-xs font-medium text-text-secondary hover:text-primary">
          ← Back to tournament
        </Link>
        <div className="mt-2 flex flex-wrap items-center justify-between gap-3">
          <h1 className="text-2xl font-bold text-text-primary">Auction Sessions</h1>
          <RoleGate minRole="tournament_admin">
            <button
              type="button"
              onClick={() => setShowCreate((v) => !v)}
              className="rounded-xl bg-primary px-4 py-2 text-sm font-semibold text-white transition hover:bg-primary-dark"
            >
              {showCreate ? 'Cancel' : '+ Create Auction Session'}
            </button>
          </RoleGate>
        </div>
      </div>

      {showCreate && (
        <CreateAuctionSessionForm
          tournamentId={tournamentId}
          onCreated={(session) => {
            setShowCreate(false)
            navigate(`/tournaments/${tournamentId}/auction/${session.id}/pool`)
          }}
        />
      )}

      <div className="rounded-2xl border border-border bg-card">
        {isLoading && <div className="p-6 text-sm text-text-secondary">Loading auction sessions…</div>}

        {isError && <div className="p-6 text-sm text-negative">Could not load auction sessions.</div>}

        {!isLoading && !isError && sessions && sessions.length === 0 && (
          <div className="p-10 text-center text-sm text-text-muted">No auction sessions yet.</div>
        )}

        {sessions && sessions.length > 0 && (
          <div>
            {sessions.map((session) => (
              <SessionRow key={session.id} tournamentId={tournamentId} session={session} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
