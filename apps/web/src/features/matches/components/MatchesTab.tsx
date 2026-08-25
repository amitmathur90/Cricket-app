import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuthStore } from '../../../core/auth/authStore'
import { roleAtOrAbove } from '../../../types/organization'
import { RoleGate } from '../../../core/router/RoleGate'
import { useMatches } from '../hooks/useMatches'
import { MatchCard } from './MatchCard'
import { WeekStrip } from './WeekStrip'
import { formatGroupDate, formatMonthLabel, isSameDay, startOfWeek } from '../dateUtils'
import type { Match } from '../../../types/match'

type FilterTab = 'upcoming' | 'past' | 'all'

const FILTER_TABS: { key: FilterTab; label: string }[] = [
  { key: 'upcoming', label: 'Upcoming' },
  { key: 'past', label: 'Past' },
  { key: 'all', label: 'All' },
]

interface MatchGroup {
  label: string
  matches: Match[]
}

function groupByDate(matches: Match[], descending: boolean): MatchGroup[] {
  const sorted = [...matches].sort((a, b) => {
    if (!a.scheduledAt && !b.scheduledAt) return 0
    if (!a.scheduledAt) return 1
    if (!b.scheduledAt) return -1
    const diff = new Date(a.scheduledAt).getTime() - new Date(b.scheduledAt).getTime()
    return descending ? -diff : diff
  })

  const groups: MatchGroup[] = []
  for (const match of sorted) {
    const label = match.scheduledAt ? formatGroupDate(new Date(match.scheduledAt)) : 'Date TBD'
    const last = groups[groups.length - 1]
    if (last && last.label === label) {
      last.matches.push(match)
    } else {
      groups.push({ label, matches: [match] })
    }
  }
  return groups
}

/**
 * The tournament-detail Matches tab — replaces TournamentDetailPage's
 * `<PlaceholderTab label="Matches" />` (wired in centrally elsewhere, not
 * by this component). Ports matches_tab.dart's just-redesigned "Schedule"
 * panel: a month navigator, a Sun-Sat week strip that really filters the
 * list to a tapped day, the existing Upcoming/Past/All filter (selecting a
 * date clears it and vice versa, same as mobile), and a chronological,
 * date-grouped list of MatchCards.
 */
export function MatchesTab({ tournamentId }: { tournamentId: string }) {
  const role = useAuthStore((s) => s.role)
  const isSuperAdmin = useAuthStore((s) => s.isSuperAdmin)
  const canManageMatches = roleAtOrAbove(role, 'tournament_admin', isSuperAdmin)

  const { data: matches, isLoading, isError } = useMatches(tournamentId)

  const [filter, setFilter] = useState<FilterTab>('upcoming')
  const [weekAnchor, setWeekAnchor] = useState(() => new Date())
  const [selectedDate, setSelectedDate] = useState<Date | null>(null)

  const weekStart = useMemo(() => startOfWeek(weekAnchor), [weekAnchor])

  function changeMonth(delta: number) {
    setWeekAnchor((prev) => new Date(prev.getFullYear(), prev.getMonth() + delta, 1))
  }

  function selectDate(date: Date) {
    setSelectedDate((prev) => (prev && isSameDay(prev, date) ? null : date))
  }

  function changeFilter(next: FilterTab) {
    setFilter(next)
    setSelectedDate(null)
  }

  const filtered = useMemo(() => {
    if (!matches) return []
    const now = new Date()
    if (selectedDate) {
      return matches.filter((m) => m.scheduledAt && isSameDay(new Date(m.scheduledAt), selectedDate))
    }
    if (filter === 'upcoming') return matches.filter((m) => !m.scheduledAt || new Date(m.scheduledAt) >= now)
    if (filter === 'past') return matches.filter((m) => m.scheduledAt && new Date(m.scheduledAt) < now)
    return matches
  }, [matches, filter, selectedDate])

  const groups = useMemo(
    () => groupByDate(filtered, selectedDate == null && filter === 'past'),
    [filtered, selectedDate, filter],
  )

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between gap-3">
        <h2 className="text-base font-semibold text-text-primary">Schedule</h2>
        <RoleGate minRole="tournament_admin">
          <Link
            to={`/tournaments/${tournamentId}/matches/create`}
            className="rounded-xl bg-primary px-4 py-2 text-sm font-semibold text-white transition hover:bg-primary-dark"
          >
            + Add match
          </Link>
        </RoleGate>
      </div>

      <div className="rounded-2xl border border-border bg-card p-3">
        <div className="flex items-center justify-between px-1">
          <button
            type="button"
            onClick={() => changeMonth(-1)}
            aria-label="Previous month"
            className="rounded-lg px-2 py-1 text-text-secondary transition hover:bg-page"
          >
            ‹
          </button>
          <span className="text-sm font-semibold text-text-primary">{formatMonthLabel(weekAnchor)}</span>
          <button
            type="button"
            onClick={() => changeMonth(1)}
            aria-label="Next month"
            className="rounded-lg px-2 py-1 text-text-secondary transition hover:bg-page"
          >
            ›
          </button>
        </div>
        <WeekStrip weekStart={weekStart} selectedDate={selectedDate} onSelect={selectDate} />
      </div>

      <div className="flex gap-1 rounded-xl border border-border bg-card p-1">
        {FILTER_TABS.map((tab) => (
          <button
            key={tab.key}
            type="button"
            onClick={() => changeFilter(tab.key)}
            className={`flex-1 rounded-lg py-1.5 text-sm font-semibold transition ${
              filter === tab.key && !selectedDate
                ? 'bg-primary text-white'
                : 'text-text-secondary hover:bg-page'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {isLoading && <div className="py-8 text-center text-sm text-text-secondary">Loading matches…</div>}

      {isError && (
        <div className="rounded-2xl border border-negative/30 bg-negative/5 p-6 text-sm text-negative">
          Could not load matches.
        </div>
      )}

      {!isLoading && !isError && groups.length === 0 && (
        <div className="rounded-2xl border border-dashed border-border p-10 text-center text-sm text-text-muted">
          {selectedDate
            ? `No matches on ${formatGroupDate(selectedDate)}.`
            : matches && matches.length === 0
              ? 'No matches scheduled yet.'
              : 'No matches in this view.'}
          {canManageMatches && matches && matches.length === 0 && (
            <>
              {' '}
              <Link to={`/tournaments/${tournamentId}/matches/create`} className="font-semibold text-primary hover:underline">
                Add the first match
              </Link>
              .
            </>
          )}
        </div>
      )}

      {groups.length > 0 && (
        <div className="flex flex-col gap-4">
          {groups.map((group) => (
            <div key={group.label} className="flex flex-col gap-2">
              <span className="text-xs font-bold uppercase tracking-wide text-primary">{group.label}</span>
              <div className="flex flex-col gap-2">
                {group.matches.map((match) => (
                  <MatchCard key={match.id} match={match} to={`/tournaments/${tournamentId}/matches/${match.id}`} />
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
