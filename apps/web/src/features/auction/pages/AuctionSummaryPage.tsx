import { Link, useParams } from 'react-router-dom'
import { useTournament } from '../../tournaments/hooks/useTournaments'
import { useAuctionSession } from '../hooks/useAuctionSessions'
import { useAuctionReport } from '../hooks/useAuctionReport'
import { AuctionCompletionSummary } from '../components/AuctionCompletionSummary'

/**
 * Dedicated end-of-auction summary page — renders via
 * AuctionCompletionSummary, the same component LiveAuctionRoomPage embeds
 * inline once a session completes, so there is exactly one place computing
 * "AUCTION COMPLETED" totals rather than two divergent renderings of the
 * same completed-session state. Only meaningful once the session is
 * actually `completed`; anything else shows a plain message pointing back
 * to the live room instead of guessing at partial totals.
 */
export function AuctionSummaryPage() {
  const { tournamentId, sessionId } = useParams<{ tournamentId: string; sessionId: string }>()
  const { data: tournament } = useTournament(tournamentId)
  const { data: session } = useAuctionSession(tournamentId, sessionId)
  const isCompleted = session?.status === 'completed'
  const { data: report, isLoading, isError } = useAuctionReport(tournamentId, isCompleted ? sessionId : undefined)

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
        <h1 className="mt-2 text-2xl font-bold text-text-primary">Auction Summary</h1>
        {tournament && session && (
          <p className="mt-0.5 text-sm text-text-secondary">
            {tournament.name} · {session.name}
          </p>
        )}
      </div>

      {session && !isCompleted && (
        <div className="rounded-2xl border border-dashed border-border p-10 text-center text-sm text-text-muted">
          The summary is available once this auction has completed — it's currently {session.status}.{' '}
          <Link to={`/tournaments/${tournamentId}/auction/${sessionId}`} className="font-semibold text-primary hover:underline">
            Go to the live room
          </Link>
          .
        </div>
      )}

      {isCompleted && isLoading && <div className="text-sm text-text-secondary">Loading auction summary…</div>}

      {isCompleted && isError && (
        <div className="rounded-2xl border border-negative/30 bg-negative/5 p-6 text-sm text-negative">
          Could not load the auction report.
        </div>
      )}

      {isCompleted && report && <AuctionCompletionSummary report={report} />}
    </div>
  )
}
