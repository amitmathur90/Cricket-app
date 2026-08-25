import { Link } from 'react-router-dom'
import type { Match } from '../../../types/match'

function TeamBadge({ name }: { name: string | null }) {
  return (
    <div className="flex h-9 w-9 items-center justify-center rounded-full bg-primary/10 text-xs font-bold text-primary">
      {name ? name.slice(0, 2).toUpperCase() : '?'}
    </div>
  )
}

/** No live score is shown — Match carries no live-score fields (reserved
 * for the Phase 2 scoring feature, never populated by this module). This
 * card shows what's genuinely known: teams, venue, and the LIVE state
 * itself. Fabricating a score line to match the mockup's visual would
 * violate the no-fabrication rule this whole dashboard follows. */
export function LiveMatchCard({ match }: { match: Match }) {
  const venue = match.venue?.name ?? match.venueName

  return (
    <Link
      to={`/tournaments/${match.tournamentId}/matches/${match.id}`}
      className="block rounded-2xl border border-border bg-card p-4 transition hover:border-primary hover:shadow-sm"
    >
      <span className="inline-flex items-center gap-1.5 rounded-full bg-live px-2.5 py-1 text-[11px] font-bold text-white">
        <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-white" />
        LIVE
      </span>

      <div className="mt-3 flex items-center gap-3">
        <TeamBadge name={match.homeTeamName} />
        <div className="flex-1 text-center">
          <p className="text-sm font-semibold text-text-primary">
            {match.homeTeamName ?? 'TBD'}
            <span className="mx-1.5 text-xs font-normal text-text-muted">vs</span>
            {match.awayTeamName ?? 'TBD'}
          </p>
        </div>
        <TeamBadge name={match.awayTeamName} />
      </div>

      {venue && <p className="mt-3 text-xs text-text-secondary">📍 {venue}</p>}
    </Link>
  )
}
