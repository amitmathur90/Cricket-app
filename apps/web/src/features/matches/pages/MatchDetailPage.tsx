import { Link, useParams } from 'react-router-dom'
import { useAuthStore } from '../../../core/auth/authStore'
import { roleAtOrAbove } from '../../../types/organization'
import { RoleGate } from '../../../core/router/RoleGate'
import { StatusPill } from '../../../shared/components/StatusPill'
import { SecondaryButton } from '../../../shared/components/FormPrimitives'
import { useMatch } from '../hooks/useMatches'
import { useUpdateMatch } from '../hooks/useUpdateMatch'
import { matchStatusTone } from '../statusTones'
import { formatGroupDate, formatTime } from '../dateUtils'
import { MATCH_STATUS_LABELS } from '../../../types/match'

function InfoRow({ label, value }: { label: string; value: string | null }) {
  if (!value) return null
  return (
    <div className="flex items-start justify-between gap-4 py-2.5">
      <span className="text-sm text-text-secondary">{label}</span>
      <span className="text-right text-sm font-semibold text-text-primary">{value}</span>
    </div>
  )
}

/**
 * Read-only Overview-tab-equivalent of match_center_screen.dart's tab set
 * (Overview/Scorecard/Commentary/Fall of Wickets/Partnerships/Playing XI/
 * Officials) — Phase 1 scope per the plan builds only this single tab.
 * Ball-by-ball live scoring, the scorecard, commentary, and Playing XI are
 * a WebSocket-driven feature explicitly deferred to Phase 2, so no tab
 * strip is rendered here at all — just the match's static info (teams,
 * schedule, venue, officials, status, result) in one panel, folding in what
 * match_overview_tab.dart and match_officials_tab.dart each show.
 */
export function MatchDetailPage() {
  const { tournamentId, matchId } = useParams<{ tournamentId: string; matchId: string }>()
  const { data: match, isLoading, isError } = useMatch(tournamentId, matchId)
  const role = useAuthStore((s) => s.role)
  const isSuperAdmin = useAuthStore((s) => s.isSuperAdmin)
  const canManage = roleAtOrAbove(role, 'tournament_admin', isSuperAdmin)
  const updateMutation = useUpdateMatch(tournamentId)

  if (isLoading) {
    return <div className="text-sm text-text-secondary">Loading match…</div>
  }

  if (isError || !match) {
    return (
      <div className="rounded-2xl border border-negative/30 bg-negative/5 p-6 text-sm text-negative">
        Could not load this match.
      </div>
    )
  }

  const scheduledAt = match.scheduledAt ? new Date(match.scheduledAt) : null
  // Dual-field approach (see types/match.ts): prefer the resolved
  // venue/official object's name, fall back to the legacy free-text field.
  const venue = match.venue?.name ?? match.venueName
  const umpire = match.umpireOfficial?.fullName ?? match.umpireName
  const scorer = match.scorerOfficial?.fullName ?? match.scorerName
  const matchReferee = match.matchRefereeOfficial?.fullName

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-4">
      <div>
        <Link to={`/tournaments/${tournamentId}`} className="text-xs font-medium text-text-secondary hover:text-primary">
          ← Back to tournament
        </Link>
        <div className="mt-2 flex flex-wrap items-center gap-3">
          <h1 className="text-xl font-bold text-text-primary">
            {match.homeTeamName ?? 'TBD'} vs {match.awayTeamName ?? 'TBD'}
          </h1>
          <StatusPill label={MATCH_STATUS_LABELS[match.status]} tone={matchStatusTone(match.status)} />
        </div>
      </div>

      {match.resultSummary && (
        <div className="flex items-center gap-2 rounded-xl bg-primary/10 px-4 py-3 text-sm font-semibold text-primary">
          <span aria-hidden>🏆</span>
          {match.resultSummary}
        </div>
      )}

      <div className="rounded-2xl border border-border bg-card px-5 py-1 divide-y divide-border">
        <InfoRow label="Date" value={scheduledAt ? formatGroupDate(scheduledAt) : 'Date TBD'} />
        <InfoRow label="Time" value={scheduledAt ? formatTime(scheduledAt) : 'Time TBD'} />
        <InfoRow label="Venue" value={venue ?? 'TBD'} />
        <InfoRow label="Overs limit" value={match.oversLimit != null ? `${match.oversLimit} overs` : null} />
        <InfoRow label="Winner" value={match.winnerTeamName} />
      </div>

      <div className="rounded-2xl border border-border bg-card px-5 py-1 divide-y divide-border">
        <InfoRow label="Umpire" value={umpire ?? 'TBD'} />
        <InfoRow label="Scorer" value={scorer ?? 'TBD'} />
        <InfoRow label="Match referee" value={matchReferee ?? null} />
      </div>

      <RoleGate minRole="tournament_admin">
        <div className="flex gap-2">
          <Link
            to={`/tournaments/${tournamentId}/matches/${matchId}/edit`}
            className="rounded-xl bg-primary px-4 py-2 text-sm font-semibold text-white transition hover:bg-primary-dark"
          >
            Edit match
          </Link>
          {match.status !== 'cancelled' && match.status !== 'completed' && (
            <SecondaryButton
              type="button"
              disabled={!canManage || updateMutation.isPending}
              onClick={() => matchId && updateMutation.mutate({ matchId, payload: { status: 'cancelled' } })}
            >
              {updateMutation.isPending ? 'Cancelling…' : 'Cancel match'}
            </SecondaryButton>
          )}
        </div>
      </RoleGate>
    </div>
  )
}
