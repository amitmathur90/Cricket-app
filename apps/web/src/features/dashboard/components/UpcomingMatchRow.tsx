import { Link } from 'react-router-dom'
import { StatusPill } from '../../../shared/components/StatusPill'
import type { Match } from '../../../types/match'

export function UpcomingMatchRow({ match }: { match: Match }) {
  const venue = match.venue?.name ?? match.venueName
  const when = match.scheduledAt
    ? new Date(match.scheduledAt).toLocaleString(undefined, {
        month: 'short',
        day: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
      })
    : 'TBD'

  return (
    <Link
      to={`/tournaments/${match.tournamentId}/matches/${match.id}`}
      className="flex items-center justify-between rounded-xl px-3 py-2.5 transition hover:bg-page"
    >
      <div>
        <p className="text-sm font-medium text-text-primary">
          {match.homeTeamName ?? 'TBD'} vs {match.awayTeamName ?? 'TBD'}
        </p>
        <p className="text-xs text-text-secondary">
          {when}
          {venue ? ` · ${venue}` : ''}
        </p>
      </div>
      <StatusPill label="Upcoming" tone="info" />
    </Link>
  )
}
