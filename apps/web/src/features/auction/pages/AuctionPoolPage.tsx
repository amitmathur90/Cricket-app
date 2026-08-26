import { useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { RoleGate } from '../../../core/router/RoleGate'
import { StatusPill, type PillTone } from '../../../shared/components/StatusPill'
import { PrimaryButton, TextInput, ErrorText } from '../../../shared/components/FormPrimitives'
import { usePlayers } from '../../players/hooks/usePlayers'
import { useAuctionSession } from '../hooks/useAuctionSessions'
import { useAddToPool, useAuctionPool } from '../hooks/useAuctionPool'
import { useStartAuction } from '../hooks/useAuctionLifecycle'
import { auctionErrorMessage } from '../errorMessage'
import { AUCTION_POOL_STATUS_LABELS, type AddToPoolEntry, type AuctionPoolStatus } from '../../../types/auction'

interface Selection {
  playerId: string
  fullName: string
  basePrice: string
}

function poolStatusTone(status: AuctionPoolStatus): PillTone {
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
 * Pre-auction lot-pool setup: bulk-adds players (from this org's flat
 * player list — there is no tournament-scoped player list on the backend
 * yet, same documented limitation as features/players/components/
 * PlayersTab.tsx) to the session's pool with a base price each, shows the
 * pool built so far, and — once it's non-empty and the session is still
 * `scheduled` — offers "Start Auction", which hands off to the live room.
 * Read-only once the session has left `scheduled` (pool composition is
 * fixed for the rest of the session's lifecycle server-side).
 */
export function AuctionPoolPage() {
  const { tournamentId, sessionId } = useParams<{ tournamentId: string; sessionId: string }>()
  const navigate = useNavigate()
  const { data: session } = useAuctionSession(tournamentId, sessionId)
  const { data: players } = usePlayers()
  const { data: pool, isLoading: isPoolLoading, isError: isPoolError } = useAuctionPool(tournamentId, sessionId)
  const addToPoolMutation = useAddToPool(tournamentId, sessionId)
  const startMutation = useStartAuction(tournamentId, sessionId)

  const [selection, setSelection] = useState<Selection[]>([])
  const [error, setError] = useState<string | null>(null)

  const pooledPlayerIds = useMemo(() => new Set(pool?.map((p) => p.playerId) ?? []), [pool])
  const selectedPlayerIds = useMemo(() => new Set(selection.map((s) => s.playerId)), [selection])
  const candidates = useMemo(
    () => (players ?? []).filter((p) => !pooledPlayerIds.has(p.id) && !selectedPlayerIds.has(p.id)),
    [players, pooledPlayerIds, selectedPlayerIds],
  )

  if (!tournamentId || !sessionId) return null

  function addToSelection(playerId: string, fullName: string) {
    setSelection((prev) => [...prev, { playerId, fullName, basePrice: '' }])
  }
  function removeFromSelection(playerId: string) {
    setSelection((prev) => prev.filter((s) => s.playerId !== playerId))
  }
  function updateBasePrice(playerId: string, value: string) {
    setSelection((prev) => prev.map((s) => (s.playerId === playerId ? { ...s, basePrice: value } : s)))
  }

  async function handleSubmitPool() {
    if (selection.length === 0) return
    const startingLotOrder = (pool?.length ?? 0) + 1
    const entries: AddToPoolEntry[] = []
    for (const [index, s] of selection.entries()) {
      const basePrice = Number(s.basePrice)
      if (!s.basePrice.trim() || Number.isNaN(basePrice) || basePrice < 0) {
        setError(`Enter a valid base price for ${s.fullName}`)
        return
      }
      entries.push({ playerId: s.playerId, basePrice, lotOrder: startingLotOrder + index })
    }
    setError(null)
    try {
      await addToPoolMutation.mutateAsync({ entries })
      setSelection([])
    } catch (err) {
      setError(auctionErrorMessage(err))
    }
  }

  async function handleStart() {
    setError(null)
    try {
      await startMutation.mutateAsync()
      navigate(`/tournaments/${tournamentId}/auction/${sessionId}`)
    } catch (err) {
      setError(auctionErrorMessage(err))
    }
  }

  const canStart = session?.status === 'scheduled' && (pool?.length ?? 0) > 0
  const canEditPool = session?.status === 'scheduled'

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-4">
      <div>
        <Link to={`/tournaments/${tournamentId}/auction`} className="text-xs font-medium text-text-secondary hover:text-primary">
          ← Back to auction sessions
        </Link>
        <div className="mt-2 flex flex-wrap items-center justify-between gap-3">
          <h1 className="text-2xl font-bold text-text-primary">{session?.name ?? 'Auction pool'}</h1>
          <RoleGate minRole="tournament_admin">
            <PrimaryButton
              type="button"
              className="w-auto"
              onClick={handleStart}
              disabled={!canStart || startMutation.isPending}
              title={session?.status === 'scheduled' && !canStart ? 'Add at least one player to the pool first' : undefined}
            >
              {startMutation.isPending ? 'Starting…' : 'Start Auction'}
            </PrimaryButton>
          </RoleGate>
        </div>
        {session && !canEditPool && (
          <p className="mt-1 text-xs text-text-muted">
            This session is {session.status} — the pool can no longer be edited here.{' '}
            <Link to={`/tournaments/${tournamentId}/auction/${sessionId}`} className="font-semibold text-primary hover:underline">
              Go to the live room
            </Link>
            .
          </p>
        )}
      </div>

      <ErrorText>{error}</ErrorText>

      {canEditPool && (
        <RoleGate minRole="tournament_admin">
          <div className="rounded-2xl border border-border bg-card p-5">
            <h2 className="text-sm font-semibold text-text-primary">Add players to the lot pool</h2>
            <p className="mt-1 text-xs text-text-secondary">
              Every player in this organization is a candidate — there's no tournament-scoped player list on the
              backend yet (same limitation as the Players tab).
            </p>

            <div className="mt-3 max-h-56 overflow-y-auto rounded-xl border border-border">
              {candidates.length === 0 && (
                <div className="p-4 text-center text-xs text-text-muted">No more players to add.</div>
              )}
              {candidates.map((p) => (
                <div
                  key={p.id}
                  className="flex items-center justify-between gap-3 border-b border-border px-3 py-2 last:border-b-0"
                >
                  <span className="text-sm text-text-primary">{p.fullName}</span>
                  <button
                    type="button"
                    onClick={() => addToSelection(p.id, p.fullName)}
                    className="rounded-lg bg-primary/10 px-3 py-1 text-xs font-semibold text-primary hover:bg-primary/20"
                  >
                    + Add
                  </button>
                </div>
              ))}
            </div>

            {selection.length > 0 && (
              <div className="mt-4 flex flex-col gap-2">
                <span className="text-xs font-semibold text-text-secondary">Selected for this pool ({selection.length})</span>
                {selection.map((s) => (
                  <div key={s.playerId} className="flex items-center gap-2">
                    <span className="w-40 shrink-0 truncate text-sm text-text-primary">{s.fullName}</span>
                    <TextInput
                      type="number"
                      min={0}
                      placeholder="Base price"
                      value={s.basePrice}
                      onChange={(e) => updateBasePrice(s.playerId, e.target.value)}
                    />
                    <button
                      type="button"
                      onClick={() => removeFromSelection(s.playerId)}
                      className="shrink-0 rounded-lg px-2 py-1 text-xs text-negative hover:bg-negative/10"
                    >
                      Remove
                    </button>
                  </div>
                ))}
                <div className="mt-2 flex justify-end">
                  <PrimaryButton type="button" className="w-auto" onClick={handleSubmitPool} disabled={addToPoolMutation.isPending}>
                    {addToPoolMutation.isPending ? 'Adding…' : `Add ${selection.length} to pool`}
                  </PrimaryButton>
                </div>
              </div>
            )}
          </div>
        </RoleGate>
      )}

      <div className="rounded-2xl border border-border bg-card">
        <div className="border-b border-border px-5 py-3 text-sm font-semibold text-text-primary">Pool ({pool?.length ?? 0})</div>
        {isPoolLoading && <div className="p-6 text-sm text-text-secondary">Loading pool…</div>}
        {isPoolError && <div className="p-6 text-sm text-negative">Could not load the pool.</div>}
        {!isPoolLoading && !isPoolError && pool && pool.length === 0 && (
          <div className="p-10 text-center text-sm text-text-muted">No players added to this pool yet.</div>
        )}
        {pool && pool.length > 0 && (
          <div>
            {pool.map((entry) => (
              <div key={entry.id} className="flex items-center justify-between gap-3 border-b border-border px-5 py-3 last:border-b-0">
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium text-text-primary">
                    #{entry.lotOrder} · {entry.player.fullName}
                  </p>
                  <p className="text-xs text-text-secondary">
                    Base price {entry.basePrice}
                    {entry.status === 'sold' && entry.soldToTeam
                      ? ` · Sold to ${entry.soldToTeam.team.name} for ${entry.finalPrice}`
                      : ''}
                  </p>
                </div>
                <StatusPill label={AUCTION_POOL_STATUS_LABELS[entry.status]} tone={poolStatusTone(entry.status)} />
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
