import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useAuthStore } from '../../../core/auth/authStore'
import { roleAtOrAbove } from '../../../types/organization'
import { StatusPill, type PillTone } from '../../../shared/components/StatusPill'
import { useTournament } from '../../tournaments/hooks/useTournaments'
import { useAuctionSession } from '../hooks/useAuctionSessions'
import { useAuctionReport } from '../hooks/useAuctionReport'
import { useAuctionBids } from '../hooks/useAuctionBids'
import {
  AUCTION_POOL_STATUS_LABELS,
  type AuctionPoolStatus,
  type AuctionReportPlayerOutcome,
} from '../../../types/auction'

function outcomeTone(status: AuctionPoolStatus): PillTone {
  switch (status) {
    case 'sold':
      return 'positive'
    case 'unsold':
      return 'negative'
    case 'in_progress':
      return 'live'
    default:
      return 'neutral'
  }
}

/**
 * Read-only auction history: every player from the session's report
 * (Player | Team | Final Bid | Status — SOLD rows show the winning team +
 * price, everything else shows "—"), with each row expandable to that
 * player's full bid sequence via useAuctionBids. Reachable from
 * LiveAuctionRoomPage's header nav; works for a live/paused session too
 * (report.players already reflects whatever has resolved so far), not just
 * a completed one.
 */
export function AuctionHistoryPage() {
  const { tournamentId, sessionId } = useParams<{ tournamentId: string; sessionId: string }>()
  const { data: tournament } = useTournament(tournamentId)
  const { data: session } = useAuctionSession(tournamentId, sessionId)
  const { data: report, isLoading, isError } = useAuctionReport(tournamentId, sessionId)
  const [expandedPlayerId, setExpandedPlayerId] = useState<string | null>(null)

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
        <h1 className="mt-2 text-2xl font-bold text-text-primary">Auction History</h1>
        {tournament && session && (
          <p className="mt-0.5 text-sm text-text-secondary">
            {tournament.name} · {session.name}
          </p>
        )}
        <p className="mt-1 text-xs text-text-muted">Click a player to see their complete bid history.</p>
      </div>

      {isLoading && <div className="text-sm text-text-secondary">Loading auction history…</div>}

      {isError && (
        <div className="rounded-2xl border border-negative/30 bg-negative/5 p-6 text-sm text-negative">
          Could not load the auction report.
        </div>
      )}

      {report && report.players.length === 0 && (
        <div className="rounded-2xl border border-dashed border-border p-10 text-center text-sm text-text-muted">
          No players have gone under the hammer in this session yet.
        </div>
      )}

      {report && report.players.length > 0 && (
        <div className="overflow-x-auto rounded-2xl border border-border bg-card">
          <table className="w-full min-w-[560px] border-collapse text-sm">
            <thead>
              <tr className="bg-page text-xs font-semibold uppercase tracking-wide text-text-secondary">
                <th className="px-4 py-3 text-left">Player</th>
                <th className="px-4 py-3 text-left">Team</th>
                <th className="px-4 py-3 text-right">Final Bid</th>
                <th className="px-4 py-3 text-left">Status</th>
              </tr>
            </thead>
            <tbody>
              {report.players.map((player, index) => (
                <PlayerHistoryRow
                  key={player.playerId}
                  tournamentId={tournamentId}
                  sessionId={sessionId}
                  player={player}
                  zebra={index % 2 === 1}
                  expanded={expandedPlayerId === player.playerId}
                  onToggle={() =>
                    setExpandedPlayerId((prev) => (prev === player.playerId ? null : player.playerId))
                  }
                />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

function PlayerHistoryRow({
  tournamentId,
  sessionId,
  player,
  zebra,
  expanded,
  onToggle,
}: {
  tournamentId: string
  sessionId: string
  player: AuctionReportPlayerOutcome
  zebra: boolean
  expanded: boolean
  onToggle: () => void
}) {
  // The bids endpoint is now admin-gated server-side (ORG_ADMIN/
  // TOURNAMENT_ADMIN only) — a lower-privileged viewer would just get a
  // 401/403 from useAuctionBids, so this checks client-side first and never
  // even fires the query for them, showing a clear message in its place
  // instead of an unhandled error state. Mirrors the same
  // roleAtOrAbove(...,'tournament_admin',...) check MatchesTab uses for its
  // own admin-only affordance.
  const role = useAuthStore((s) => s.role)
  const isSuperAdmin = useAuthStore((s) => s.isSuperAdmin)
  const canViewBids = roleAtOrAbove(role, 'tournament_admin', isSuperAdmin)

  const {
    data: bids,
    isLoading: bidsLoading,
    isError: bidsError,
  } = useAuctionBids(tournamentId, sessionId, player.playerId, { enabled: expanded && canViewBids })

  const isSold = player.status === 'sold'
  const rowBg = zebra ? 'bg-page' : 'bg-card'

  return (
    <>
      <tr className={`cursor-pointer ${rowBg} hover:bg-primary/5`} onClick={onToggle}>
        <td className="px-4 py-3 font-medium text-text-primary">{player.playerName}</td>
        <td className="px-4 py-3 text-text-primary">{isSold ? (player.soldToTeamName ?? '—') : '—'}</td>
        <td className="px-4 py-3 text-right text-text-primary">{isSold ? `₹${player.finalPrice}` : '—'}</td>
        <td className="px-4 py-3">
          <StatusPill label={AUCTION_POOL_STATUS_LABELS[player.status]} tone={outcomeTone(player.status)} />
        </td>
      </tr>
      {expanded && (
        <tr className={rowBg}>
          <td colSpan={4} className="border-t border-border px-4 py-3">
            {!canViewBids && (
              <p className="text-xs text-text-muted">
                Bid history is visible to organization and tournament admins only.
              </p>
            )}
            {canViewBids && bidsLoading && <p className="text-xs text-text-secondary">Loading bid history…</p>}
            {canViewBids && bidsError && (
              <p className="text-xs text-negative">Could not load bid history for this player.</p>
            )}
            {canViewBids && bids && bids.length === 0 && (
              <p className="text-xs text-text-muted">No bids were placed for this player.</p>
            )}
            {canViewBids && bids && bids.length > 0 && (
              <div className="flex flex-col gap-1">
                {[...bids]
                  .sort((a, b) => a.bidSequence - b.bidSequence)
                  .map((bid) => (
                    <div
                      key={bid.id}
                      className={`flex items-center justify-between text-xs ${bid.voided ? 'text-text-muted line-through' : 'text-text-primary'}`}
                    >
                      <span>
                        #{bid.bidSequence} · {bid.team.team.name}
                      </span>
                      <span className="font-semibold">₹{bid.bidAmount}</span>
                    </div>
                  ))}
              </div>
            )}
          </td>
        </tr>
      )}
    </>
  )
}
