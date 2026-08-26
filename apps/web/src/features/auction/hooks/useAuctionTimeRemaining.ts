import { useEffect, useState } from 'react'

function formatHms(ms: number): string {
  const totalSeconds = Math.max(0, Math.floor(ms / 1000))
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`
}

/**
 * Display-only "auction time remaining" countdown for the session header —
 * ticks every second down to `new Date(startedAt).getTime() +
 * durationMinutes * 60_000`, formatted as HH:MM:SS. Nothing server-side
 * enforces this deadline (see AuctionStateSync.session's doc comment); nor
 * does this hook do anything once it hits zero besides display "00:00:00" —
 * there is deliberately no auto-pause/auto-complete client-side either,
 * matching the backend's own "no timer" design (see
 * AuctionRealtimeService's class doc comment).
 *
 * Returns null when either input is missing (session not started yet, or
 * this session has no configured duration) — callers should omit the
 * countdown entirely in that case rather than show a meaningless value.
 */
export function useAuctionTimeRemaining(startedAt: string | null | undefined, durationMinutes: number | null | undefined): string | null {
  const [now, setNow] = useState(() => Date.now())

  const active = !!startedAt && durationMinutes != null

  useEffect(() => {
    if (!active) return
    const interval = setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(interval)
  }, [active])

  if (!active) return null

  const deadline = new Date(startedAt).getTime() + durationMinutes * 60_000
  return formatHms(deadline - now)
}
