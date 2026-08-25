import { Link } from 'react-router-dom'
import { StatusPill } from '../../../shared/components/StatusPill'
import { matchStatusTone } from '../statusTones'
import { formatTime } from '../dateUtils'
import { MATCH_STATUS_LABELS, type Match } from '../../../types/match'

/** Team accent palette for the initials indicator either side of "vs" —
 * cycles by name hash, mirroring match_card.dart's `_TeamIndicator._colorFor`
 * (AppColors.accents[name.hashCode % accents.length]). Tailwind v4 needs
 * full class names present at build time, so this is a static lookup table
 * rather than a dynamically-built class string. */
const ACCENTS = [
  { text: 'text-info', bg: 'bg-info/15', border: 'border-info/40' },
  { text: 'text-purple', bg: 'bg-purple/15', border: 'border-purple/40' },
  { text: 'text-orange', bg: 'bg-orange/15', border: 'border-orange/40' },
  { text: 'text-amber', bg: 'bg-amber/15', border: 'border-amber/40' },
  { text: 'text-teal', bg: 'bg-teal/15', border: 'border-teal/40' },
  { text: 'text-primary', bg: 'bg-primary/15', border: 'border-primary/40' },
]

function accentFor(name: string) {
  let hash = 0
  for (let i = 0; i < name.length; i++) hash = (hash * 31 + name.charCodeAt(i)) | 0
  return ACCENTS[Math.abs(hash) % ACCENTS.length]
}

function initials(name: string): string {
  const words = name.trim().split(/\s+/).filter(Boolean)
  if (words.length === 0) return '?'
  if (words.length === 1) return words[0].slice(0, 2).toUpperCase()
  return (words[0][0] + words[1][0]).toUpperCase()
}

function TeamIndicator({ name, strikeThrough }: { name: string; strikeThrough: boolean }) {
  const accent = accentFor(name)
  return (
    <div className="flex min-w-0 items-center gap-1.5">
      <span
        className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full border text-[10px] font-bold ${accent.bg} ${accent.border} ${accent.text}`}
      >
        {initials(name)}
      </span>
      <span
        className={`truncate text-sm font-semibold text-text-primary ${strikeThrough ? 'line-through opacity-70' : ''}`}
      >
        {name}
      </span>
    </div>
  )
}

/**
 * One match's row card — used by MatchesTab's date-grouped schedule list and
 * MatchListPage. Ports match_card.dart's just-redesigned layout: kickoff
 * time + StatusPill on one line, small colored team-initial circles either
 * side of "vs", venue below. Cancelled matches are visually de-emphasized
 * (dimmed + strikethrough team names) rather than hidden, same as mobile.
 */
export function MatchCard({ match, to }: { match: Match; to: string }) {
  const cancelled = match.status === 'cancelled'
  const homeLabel = match.homeTeamName ?? 'TBD'
  const awayLabel = match.awayTeamName ?? 'TBD'
  const scheduledAt = match.scheduledAt ? new Date(match.scheduledAt) : null
  const timeLabel = scheduledAt ? formatTime(scheduledAt) : 'Time TBD'
  // Dual-field approach (see types/match.ts): prefer the resolved venue
  // object's name, fall back to the legacy free-text venueName.
  const venue = (match.venue?.name ?? match.venueName ?? '').trim()

  return (
    <Link
      to={to}
      className={`flex flex-col gap-2.5 rounded-2xl border border-border bg-card p-4 transition hover:border-primary/40 hover:shadow-sm ${cancelled ? 'opacity-60' : ''}`}
    >
      <div className="flex items-center gap-2">
        <span className="text-xs font-semibold text-text-secondary">{timeLabel}</span>
        <span className="flex-1" />
        <StatusPill label={MATCH_STATUS_LABELS[match.status]} tone={matchStatusTone(match.status)} />
      </div>

      <div className="flex items-center gap-2">
        <div className="min-w-0 flex-1">
          <TeamIndicator name={homeLabel} strikeThrough={cancelled} />
        </div>
        <span className="shrink-0 text-xs font-semibold text-text-muted">vs</span>
        <div className="min-w-0 flex-1">
          <TeamIndicator name={awayLabel} strikeThrough={cancelled} />
        </div>
      </div>

      {venue && (
        <div className="flex items-center gap-1.5 text-xs text-text-secondary">
          <span aria-hidden>📍</span>
          <span className="truncate">{venue}</span>
        </div>
      )}
    </Link>
  )
}
