import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { RoleGate } from '../../../core/router/RoleGate'
import { resolveMediaUrl } from '../../../core/api/client'
import { StatusPill, type PillTone } from '../../../shared/components/StatusPill'
import { SecondaryButton } from '../../../shared/components/FormPrimitives'
import { useTournament } from '../../tournaments/hooks/useTournaments'
import { usePlayer } from '../../players/hooks/usePlayers'
import { useAuctionSession } from '../hooks/useAuctionSessions'
import { useAuctionSocket, useAuctionLiveState } from '../hooks/useAuctionSocket'
import { useAuctionBids } from '../hooks/useAuctionBids'
import { useAuctionPool } from '../hooks/useAuctionPool'
import { useAuctionReport } from '../hooks/useAuctionReport'
import { useAuctionTimeRemaining } from '../hooks/useAuctionTimeRemaining'
import {
  useMarkSold,
  useMarkUnsold,
  useNextLot,
  usePauseAuction,
  useResumeAuction,
  useUndoLastBid,
} from '../hooks/useAuctionLifecycle'
import { computeMinIncrement } from '../bidIncrement'
import { auctionErrorMessage } from '../errorMessage'
import { AUCTION_SESSION_STATUS_LABELS, type AuctionSessionStatus } from '../../../types/auction'

function sessionStatusTone(status: AuctionSessionStatus): PillTone {
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

/**
 * The admin control room for a live auction — current lot, one fixed
 * PLACE BID button per team (this is a single operator running physical-room
 * bidding on behalf of every team, not remote self-service bidding — see the
 * per-team button section below), SOLD/UNSOLD/NEXT PLAYER/undo, a teams
 * overview (purse + squad-full + squad size), and recent bid history. Driven
 * by useAuctionSocket/useAuctionLiveState (see that hook's doc comment for
 * exactly how socket events keep the cache in sync) once connected;
 * `useAuctionSession`'s plain REST fetch supplies the header (name/status)
 * immediately on load and while the socket is still connecting, since
 * there's no REST endpoint returning the full live-state shape to prime the
 * room with before the socket joins.
 *
 * The header's "Auction Time Remaining" is a pure display countdown against
 * the session's total configured duration (startedAt + durationMinutes) —
 * see useAuctionTimeRemaining's doc comment. It is NOT a per-lot timer: a
 * lot only ever resolves via an explicit admin SOLD/UNSOLD click, and only
 * ever advances via an explicit "Next Player" click, exactly as before.
 */
export function LiveAuctionRoomPage() {
  const { tournamentId, sessionId } = useParams<{ tournamentId: string; sessionId: string }>()

  const { data: tournament } = useTournament(tournamentId)
  const { data: session } = useAuctionSession(tournamentId, sessionId)
  const { connected, lastError, placeBid } = useAuctionSocket(sessionId)
  const { data: liveState } = useAuctionLiveState(sessionId)
  // Scoped to the current lot's player so the panel resets cleanly on every
  // Next Player advance instead of accumulating every bid placed all
  // session long — useAuctionBids's query key includes this playerId, so a
  // new lot (new player id) naturally triggers a fresh, narrowly-scoped
  // fetch rather than carrying the previous lot's bids forward.
  const { data: bids } = useAuctionBids(tournamentId, sessionId, liveState?.currentLot?.player.id)
  const { data: pool } = useAuctionPool(tournamentId, sessionId)
  const isCompleted = session?.status === 'completed'
  const { data: report } = useAuctionReport(tournamentId, isCompleted ? sessionId : undefined)

  const markSoldMutation = useMarkSold(tournamentId, sessionId)
  const markUnsoldMutation = useMarkUnsold(tournamentId, sessionId)
  const nextLotMutation = useNextLot(tournamentId, sessionId)
  const undoLastBidMutation = useUndoLastBid(tournamentId, sessionId)
  const pauseMutation = usePauseAuction(tournamentId, sessionId)
  const resumeMutation = useResumeAuction(tournamentId, sessionId)

  const [actionError, setActionError] = useState<string | null>(null)
  // Which resolution confirm dialog (if any) is currently open — SOLD and
  // UNSOLD both stage their mutation behind a confirm step instead of firing
  // immediately on click.
  const [confirmAction, setConfirmAction] = useState<'sold' | 'unsold' | null>(null)
  // Which outcome the admin actually confirmed for the CURRENT lot, so the
  // resolved-state banner can say "Player Status: SOLD" vs "...UNSOLD"
  // precisely rather than guessing from currentBidTeamId (marking a lot
  // UNSOLD is allowed even when it already has a leading bid, so bid
  // presence alone can't reliably distinguish the two outcomes). Reset
  // below whenever a new lot comes up so it never carries over stale from
  // the previous lot.
  const [resolvedOutcome, setResolvedOutcome] = useState<'sold' | 'unsold' | null>(null)
  // Tracks the last lot resolvedOutcome was set for, so it can be reset the
  // moment a new lot comes in. Adjusted directly during render (React's
  // recommended "adjusting state when a prop changes" pattern) rather than
  // via a useEffect, so the reset is visible in the very same render instead
  // of trailing one render behind.
  const [resolvedOutcomeLotId, setResolvedOutcomeLotId] = useState<string | null>(null)

  const status = liveState?.session.status ?? session?.status
  const currentLot = liveState?.currentLot ?? null
  const teams = liveState?.teams ?? []

  if (currentLot?.poolEntryId !== resolvedOutcomeLotId) {
    setResolvedOutcomeLotId(currentLot?.poolEntryId ?? null)
    setResolvedOutcome(null)
  }

  const timeRemaining = useAuctionTimeRemaining(liveState?.session.startedAt, liveState?.session.durationMinutes)

  // Player pool status counts for the header — pool entries are
  // pending/in_progress (not yet resolved -> "remaining"), sold, or unsold.
  const poolEntries = pool ?? []
  const soldCount = poolEntries.filter((e) => e.status === 'sold').length
  const unsoldCount = poolEntries.filter((e) => e.status === 'unsold').length
  const remainingCount = poolEntries.filter((e) => e.status === 'pending' || e.status === 'in_progress').length

  // Squad-so-far per team, derived from the pool's soldToTeamId — counts
  // players won via THIS auction session only. Known limitation: a team's
  // true roster (what the backend's squad-full check counts) can also
  // include pre-existing direct-signing/retained members added outside this
  // auction, which this client has no endpoint to look up per-team (the
  // live-state teams list only carries tournamentTeamId, and the roster
  // endpoint is scoped by org-level teamId with no tournamentTeamId ->
  // teamId lookup exposed anywhere) — so this count can under-report a
  // team's actual squad size. squadFull itself (used for the disabled
  // state below) is unaffected — that's the real, server-computed flag.
  const squadWonByTeam = new Map<string, number>()
  for (const entry of poolEntries) {
    if (entry.status === 'sold' && entry.soldToTeamId) {
      squadWonByTeam.set(entry.soldToTeamId, (squadWonByTeam.get(entry.soldToTeamId) ?? 0) + 1)
    }
  }

  // Full player detail, enriching currentLot.player (which only carries
  // {id, fullName, role, photoUrl} — see AuctionLotPlayer) with
  // battingStyle/bowlingStyle for the current-player card. Cheap
  // single-record fetch, same hook the player-detail page uses.
  const { data: currentPlayerDetail } = usePlayer(currentLot?.player.id)

  const currentBidValue = currentLot ? parseFloat(currentLot.currentBidAmount ?? currentLot.basePrice) : 0
  const minNextBid = currentLot ? currentBidValue + computeMinIncrement(currentBidValue, session?.bidIncrementRules) : 0
  const canBidNow = !!currentLot && !currentLot.resolved && status === 'live'

  if (!tournamentId || !sessionId) return null

  const leadingTeamName = currentLot?.currentBidTeamId
    ? teams.find((t) => t.tournamentTeamId === currentLot.currentBidTeamId)?.teamName
    : null

  async function runAction(mutateAsync: () => Promise<unknown>) {
    setActionError(null)
    try {
      await mutateAsync()
    } catch (err) {
      setActionError(auctionErrorMessage(err))
    }
  }

  function handlePlaceBid(teamId: string) {
    if (!canBidNow) return
    setActionError(null)
    placeBid(teamId, minNextBid)
  }

  return (
    <div className="mx-auto flex max-w-4xl flex-col gap-4">
      <div>
        <Link to={`/tournaments/${tournamentId}/auction`} className="text-xs font-medium text-text-secondary hover:text-primary">
          ← Back to auction sessions
        </Link>
        <div className="mt-2 flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className="text-xs font-bold uppercase tracking-wide text-live">Live Player Auction</p>
            <div className="mt-1 flex flex-wrap items-center gap-3">
              <h1 className="text-2xl font-bold text-text-primary">{session?.name ?? 'Live Auction'}</h1>
              {status && <StatusPill label={AUCTION_SESSION_STATUS_LABELS[status]} tone={sessionStatusTone(status)} />}
              <span className={`text-xs font-medium ${connected ? 'text-positive' : 'text-negative'}`}>
                {connected ? '● Live' : '○ Connecting…'}
              </span>
            </div>
            {tournament && <p className="mt-0.5 text-sm text-text-secondary">{tournament.name}</p>}
            {timeRemaining && (
              <p className="mt-1 text-sm font-semibold text-text-primary">
                Auction Time Remaining: <span className="font-mono tabular-nums text-primary">{timeRemaining}</span>
              </p>
            )}
          </div>
          <RoleGate minRole="tournament_admin">
            <>
              {status === 'live' && (
                <SecondaryButton type="button" onClick={() => runAction(() => pauseMutation.mutateAsync())} disabled={pauseMutation.isPending}>
                  {pauseMutation.isPending ? 'Pausing…' : 'Pause'}
                </SecondaryButton>
              )}
              {status === 'paused' && (
                <SecondaryButton type="button" onClick={() => runAction(() => resumeMutation.mutateAsync())} disabled={resumeMutation.isPending}>
                  {resumeMutation.isPending ? 'Resuming…' : 'Resume'}
                </SecondaryButton>
              )}
            </>
          </RoleGate>
        </div>

        {pool && (
          <div className="mt-3 flex flex-wrap gap-x-5 gap-y-1 text-xs font-medium text-text-secondary">
            <span>
              Players Sold: <span className="font-semibold text-positive">{soldCount}</span>
            </span>
            <span>
              Players Unsold: <span className="font-semibold text-negative">{unsoldCount}</span>
            </span>
            <span>
              Players Remaining: <span className="font-semibold text-text-primary">{remainingCount}</span>
            </span>
          </div>
        )}
      </div>

      {status === 'scheduled' && (
        <div className="rounded-2xl border border-dashed border-border p-8 text-center text-sm text-text-muted">
          This session hasn't started.{' '}
          <Link to={`/tournaments/${tournamentId}/auction/${sessionId}/pool`} className="font-semibold text-primary hover:underline">
            Manage the pool and start it
          </Link>
          .
        </div>
      )}

      {(actionError || lastError) && (
        <div className="rounded-lg bg-negative/10 px-3 py-2 text-sm text-negative">{actionError ?? lastError}</div>
      )}

      {status !== 'scheduled' && (
        <div className="grid gap-4 md:grid-cols-[2fr_1fr]">
          <div className="flex flex-col gap-4">
            <div className="rounded-2xl border border-border bg-card p-6">
              {!liveState && <div className="text-sm text-text-secondary">Connecting to the live auction…</div>}

              {liveState && !currentLot && (
                <div className="text-sm text-text-muted">
                  {status === 'completed'
                    ? 'This auction has completed — every lot has been resolved.'
                    : 'No lot is currently under the hammer.'}
                </div>
              )}

              {currentLot && (
                <div className="flex flex-col gap-4">
                  <div className="flex items-center gap-4">
                    <div className="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-2xl">
                      {currentLot.player.photoUrl ? (
                        <img src={resolveMediaUrl(currentLot.player.photoUrl)} alt="" className="h-full w-full object-cover" />
                      ) : (
                        '🧑'
                      )}
                    </div>
                    <div>
                      <p className="text-lg font-bold text-text-primary">{currentLot.player.fullName}</p>
                      <p className="text-xs uppercase tracking-wide text-text-secondary">{currentLot.player.role.replace('_', '-')}</p>
                      {currentPlayerDetail?.battingStyle && (
                        <p className="text-xs text-text-secondary">Batting: {currentPlayerDetail.battingStyle}</p>
                      )}
                      {currentPlayerDetail?.bowlingStyle && (
                        <p className="text-xs text-text-secondary">Bowling: {currentPlayerDetail.bowlingStyle}</p>
                      )}
                    </div>
                  </div>

                  <div className="flex flex-col gap-1.5 rounded-xl bg-page px-4 py-3">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="text-xs text-text-secondary">Base price</p>
                        <p className="text-sm font-semibold text-text-primary">{currentLot.basePrice}</p>
                      </div>
                      <div className="text-right">
                        <p className="text-xs text-text-secondary">Current bid</p>
                        <p className="text-lg font-bold text-primary">₹{currentLot.currentBidAmount ?? currentLot.basePrice}</p>
                      </div>
                    </div>
                    <p className="text-xs text-text-secondary">
                      Highest Bidder: <span className="font-semibold text-text-primary">{leadingTeamName ?? '—'}</span>
                    </p>
                    {canBidNow && <p className="text-xs font-semibold text-primary">Next Bid ₹{minNextBid}</p>}
                  </div>

                  {currentLot.resolved &&
                    (() => {
                      // resolvedOutcome (set by the confirm dialogs below) is
                      // the precise signal for which action the admin took
                      // this session; currentBidTeamId is only a fallback for
                      // a resolved lot inherited from a stateSync (e.g. a
                      // fresh page load / reconnect after the fact), where we
                      // have no record of which button was clicked.
                      const wasSold = resolvedOutcome ? resolvedOutcome === 'sold' : !!currentLot.currentBidTeamId
                      const soldTeam = wasSold
                        ? teams.find((t) => t.tournamentTeamId === currentLot.currentBidTeamId)
                        : null
                      const squadWon = soldTeam ? (squadWonByTeam.get(soldTeam.tournamentTeamId) ?? 0) : 0
                      return (
                        <div className="rounded-xl bg-primary/10 px-4 py-3 text-primary">
                          <p className="text-sm font-semibold">Player Status: {wasSold ? 'SOLD' : 'UNSOLD'}</p>
                          {wasSold && soldTeam && (
                            <div className="mt-1.5 flex flex-wrap gap-x-5 gap-y-1 text-xs font-medium">
                              <span>Team: {soldTeam.teamName}</span>
                              <span>Final Bid: ₹{currentLot.currentBidAmount}</span>
                              <span>Remaining Points: ₹{soldTeam.purseRemaining ?? '—'}</span>
                              {liveState?.session.maxSquadSize != null && (
                                <span>
                                  Squad: {squadWon}/{liveState.session.maxSquadSize}
                                </span>
                              )}
                            </div>
                          )}
                        </div>
                      )
                    })()}

                  <RoleGate minRole="tournament_admin">
                    <div className="flex flex-wrap gap-2">
                      <button
                        type="button"
                        disabled={currentLot.resolved || status !== 'live' || !currentLot.currentBidTeamId || markSoldMutation.isPending}
                        onClick={() => setConfirmAction('sold')}
                        className="rounded-xl bg-positive px-4 py-2.5 text-sm font-semibold text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40"
                      >
                        SOLD
                      </button>
                      <button
                        type="button"
                        disabled={currentLot.resolved || status !== 'live' || markUnsoldMutation.isPending}
                        onClick={() => setConfirmAction('unsold')}
                        className="rounded-xl bg-negative px-4 py-2.5 text-sm font-semibold text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40"
                      >
                        UNSOLD
                      </button>
                      <SecondaryButton
                        type="button"
                        disabled={!currentLot.currentBidTeamId || currentLot.resolved || status !== 'live' || undoLastBidMutation.isPending}
                        onClick={() => runAction(() => undoLastBidMutation.mutateAsync())}
                      >
                        Undo last bid
                      </SecondaryButton>
                      <button
                        type="button"
                        disabled={!currentLot.resolved || status !== 'live' || nextLotMutation.isPending}
                        onClick={() => runAction(() => nextLotMutation.mutateAsync())}
                        className="ml-auto rounded-xl bg-primary px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-40"
                      >
                        NEXT PLAYER →
                      </button>
                    </div>
                  </RoleGate>
                </div>
              )}
            </div>

            <div className="rounded-2xl border border-border bg-card">
              <div className="border-b border-border px-5 py-3 text-sm font-semibold text-text-primary">Recent bids</div>
              {(!bids || bids.length === 0) && <div className="p-6 text-center text-sm text-text-muted">No bids yet.</div>}
              {bids && bids.length > 0 && (
                <div className="max-h-64 overflow-y-auto">
                  {[...bids]
                    .reverse()
                    .slice(0, 25)
                    .map((bid) => (
                      <div
                        key={bid.id}
                        className={`flex items-center justify-between gap-3 border-b border-border px-5 py-2.5 text-sm last:border-b-0 ${bid.voided ? 'text-text-muted line-through' : 'text-text-primary'}`}
                      >
                        <span>{bid.team.team.name}</span>
                        <span className="font-semibold">{bid.bidAmount}</span>
                      </div>
                    ))}
                </div>
              )}
            </div>
          </div>

          {/* One fixed PLACE BID button per team — a single admin operator
              bids on behalf of the physical teams in the room, so each
              card's button submits that team's exact next-bid amount
              immediately, with no manual amount entry or separate confirm
              step. */}
          <div className="rounded-2xl border border-border bg-card">
            <div className="border-b border-border px-5 py-3 text-sm font-semibold text-text-primary">Teams ({teams.length})</div>
            {teams.length === 0 && <div className="p-6 text-center text-sm text-text-muted">Waiting for live state…</div>}
            {teams.map((t) => {
              const remaining = t.purseRemaining != null ? parseFloat(t.purseRemaining) : null
              // Proactive client-side check, same spirit as squadFull below —
              // greys the button out before the admin ever clicks it, rather
              // than relying solely on the server's after-the-fact rejection
              // (which remains the authoritative check regardless).
              const cannotAfford = remaining != null && remaining < minNextBid
              // A team can't out-bid its own standing bid — this is a
              // client-side UX guard only; nothing server-side currently
              // rejects a same-team re-bid (see placeBid in
              // auction-realtime.service.ts), so this button-disable is the
              // only thing preventing it today.
              const isLeadingBidder = !!currentLot?.currentBidTeamId && currentLot.currentBidTeamId === t.tournamentTeamId
              const disableBid = !canBidNow || t.squadFull || cannotAfford || isLeadingBidder
              const squadWon = squadWonByTeam.get(t.tournamentTeamId) ?? 0
              const bidLabel = !canBidNow
                ? 'PLACE BID'
                : t.squadFull
                  ? 'SQUAD FULL'
                  : cannotAfford
                    ? 'Insufficient Points'
                    : isLeadingBidder
                      ? 'Leading Bidder'
                      : `PLACE BID ₹${minNextBid}`
              const bidTitle = t.squadFull
                ? 'Squad full'
                : cannotAfford
                  ? 'Purse too low for the next bid'
                  : isLeadingBidder
                    ? 'This team is already the leading bidder for this lot'
                    : undefined
              return (
                <div
                  key={t.tournamentTeamId}
                  className={`flex flex-col gap-2 border-b border-border px-5 py-3 last:border-b-0 ${currentLot?.currentBidTeamId === t.tournamentTeamId ? 'bg-primary/5' : ''}`}
                >
                  <div className="flex items-center justify-between gap-3">
                    <p className="truncate text-sm font-medium text-text-primary">{t.teamName}</p>
                    {t.squadFull && <StatusPill label="SQUAD FULL" tone="negative" />}
                  </div>
                  <div className="flex items-center gap-4 text-xs text-text-secondary">
                    <span>Points {t.purseRemaining ?? '—'}</span>
                    {liveState?.session.maxSquadSize != null && (
                      <span>
                        Squad {squadWon}/{liveState.session.maxSquadSize}
                      </span>
                    )}
                  </div>
                  <button
                    type="button"
                    disabled={disableBid}
                    title={bidTitle}
                    onClick={() => handlePlaceBid(t.tournamentTeamId)}
                    className="w-full rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-40"
                  >
                    {bidLabel}
                  </button>
                </div>
              )
            })}
          </div>
        </div>
      )}

      {isCompleted && report && (
        <div className="rounded-2xl border border-border bg-card p-5">
          <h2 className="text-sm font-semibold text-text-primary">Auction report</h2>
          <div className="mt-3 flex flex-col gap-2">
            {report.teams.map((t) => (
              <div key={t.tournamentTeamId} className="flex items-center justify-between text-sm">
                <span className="text-text-primary">{t.teamName}</span>
                <span className="text-text-secondary">
                  {t.playersBought} players · spent {t.totalSpent} · purse left {t.purseRemaining ?? '—'}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {confirmAction === 'sold' &&
        currentLot &&
        (() => {
          const leadingTeam = teams.find((t) => t.tournamentTeamId === currentLot.currentBidTeamId)
          const finalBid = currentLot.currentBidAmount ?? currentLot.basePrice
          const finalBidValue = parseFloat(finalBid)
          // "Before" is the leading team's CURRENT purseRemaining from live
          // state — pre-deduction, since the mutation hasn't run yet.
          // "Remaining" is computed client-side for display only; the
          // server computes and broadcasts the authoritative value via
          // auction.playerSold, which the live state picks up immediately
          // after confirm.
          const before = leadingTeam?.purseRemaining != null ? parseFloat(leadingTeam.purseRemaining) : null
          const remainingAfter = before != null ? before - finalBidValue : null
          return (
            <ConfirmDialog
              title="Confirm Player Sale?"
              confirmLabel="Confirm SOLD"
              confirmTone="positive"
              confirming={markSoldMutation.isPending}
              onCancel={() => setConfirmAction(null)}
              onConfirm={() => {
                setConfirmAction(null)
                setResolvedOutcome('sold')
                runAction(() => markSoldMutation.mutateAsync())
              }}
            >
              <div className="flex flex-col gap-1 text-sm text-text-primary">
                <p>
                  Player: <span className="font-semibold">{currentLot.player.fullName}</span>
                </p>
                <p>
                  Team: <span className="font-semibold">{leadingTeam?.teamName ?? '—'}</span>
                </p>
                <p>
                  Final Bid: <span className="font-semibold">₹{finalBid}</span>
                </p>
                <div className="mt-2 flex flex-col gap-0.5 rounded-lg bg-page px-3 py-2 text-xs">
                  <p className="mb-1 font-semibold text-text-secondary">Team Points</p>
                  <p>Before: ₹{before ?? '—'}</p>
                  <p>Spent: ₹{finalBid}</p>
                  <p>Remaining: ₹{remainingAfter ?? '—'}</p>
                </div>
              </div>
            </ConfirmDialog>
          )
        })()}

      {confirmAction === 'unsold' && currentLot && (
        <ConfirmDialog
          title="Mark Player as Unsold?"
          confirmLabel="Confirm UNSOLD"
          confirmTone="negative"
          confirming={markUnsoldMutation.isPending}
          onCancel={() => setConfirmAction(null)}
          onConfirm={() => {
            setConfirmAction(null)
            setResolvedOutcome('unsold')
            runAction(() => markUnsoldMutation.mutateAsync())
          }}
        >
          <p className="text-sm font-semibold text-text-primary">{currentLot.player.fullName}</p>
        </ConfirmDialog>
      )}
    </div>
  )
}

/**
 * Minimal fixed-overlay confirm modal — there's no existing modal/dialog
 * primitive in shared/components to reuse (checked: StatusPill,
 * FormPrimitives, TopBar, PageShell, Sidebar are the only exports there),
 * so this is a small local one rather than a new dependency. Used for both
 * the SOLD and UNSOLD confirm steps above; only the "confirm" action ever
 * calls into a mutation — Cancel (and the component unmounting via
 * `confirmAction` flipping back to null) never does.
 */
function ConfirmDialog({
  title,
  children,
  onCancel,
  onConfirm,
  confirmLabel,
  confirmTone,
  confirming,
}: {
  title: string
  children: React.ReactNode
  onCancel: () => void
  onConfirm: () => void
  confirmLabel: string
  confirmTone: 'positive' | 'negative'
  confirming?: boolean
}) {
  const confirmClass = confirmTone === 'positive' ? 'bg-positive hover:opacity-90' : 'bg-negative hover:opacity-90'
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
      <div className="w-full max-w-sm rounded-2xl border border-border bg-card p-5 shadow-lg">
        <h2 className="text-base font-bold text-text-primary">{title}</h2>
        <div className="mt-3">{children}</div>
        <div className="mt-5 flex justify-end gap-2">
          <SecondaryButton type="button" onClick={onCancel} disabled={confirming}>
            Cancel
          </SecondaryButton>
          <button
            type="button"
            onClick={onConfirm}
            disabled={confirming}
            className={`rounded-xl px-4 py-2.5 text-sm font-semibold text-white transition disabled:cursor-not-allowed disabled:opacity-60 ${confirmClass}`}
          >
            {confirming ? 'Working…' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}
