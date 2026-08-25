import { Link, useParams } from 'react-router-dom'
import { useAuthStore } from '../../../core/auth/authStore'
import { roleAtOrAbove } from '../../../types/organization'
import { resolveMediaUrl } from '../../../core/api/client'
import { usePlayer } from '../hooks/usePlayers'
import { usePlayerStatistics } from '../hooks/usePlayerStatistics'
import { RegistrationReviewPanel } from '../components/RegistrationReviewPanel'
import { PLAYER_ROLES, type Player, type PlayerMatchHistoryEntry, type PlayerStatisticsSummary } from '../../../types/player'

function initials(fullName: string): string {
  const parts = fullName.trim().split(/\s+/).filter(Boolean)
  if (parts.length === 0) return '?'
  if (parts.length === 1) return parts[0]!.slice(0, 1).toUpperCase()
  return (parts[0]!.slice(0, 1) + parts[parts.length - 1]!.slice(0, 1)).toUpperCase()
}

function formatRating(raw: string): string {
  const n = Number(raw)
  return Number.isNaN(n) ? raw : n.toFixed(1)
}

function formatDob(dob: string): string {
  const d = new Date(dob)
  if (Number.isNaN(d.getTime())) return dob
  return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
}

function roleLabel(role: Player['role']): string {
  return PLAYER_ROLES.find((r) => r.value === role)?.label ?? role
}

function QuickStat({ value, label }: { value: string; label: string }) {
  return (
    <div className="flex flex-col items-center gap-0.5">
      <span className="text-xl font-bold text-white">{value}</span>
      <span className="text-[11px] text-white/75">{label}</span>
    </div>
  )
}

/** Teal-gradient profile header — avatar, name (+ verified badge when
 * approved), role, a rating badge top-right, and a Matches/Runs/Wickets/
 * Rating quick-stat row. Translated from apps/mobile's just-redesigned
 * PlayerStatisticsScreen._ProfileHeader onto Tailwind. */
function ProfileHeader({ player, summary }: { player: Player; summary: PlayerStatisticsSummary | undefined }) {
  return (
    <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-teal to-teal-dark p-5">
      {player.rating && (
        <div className="absolute right-4 top-4 flex items-center gap-1 rounded-full bg-white/20 px-2.5 py-1 text-xs font-bold text-white">
          <span className="text-amber">★</span>
          {formatRating(player.rating)}
        </div>
      )}

      <div className="flex items-start gap-4">
        <div className="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-full bg-white/20 text-lg font-bold text-white">
          {player.photoUrl ? (
            <img src={resolveMediaUrl(player.photoUrl)} alt="" className="h-full w-full object-cover" />
          ) : (
            initials(player.fullName)
          )}
        </div>
        <div className={`min-w-0 flex-1 ${player.rating ? 'pr-14' : ''}`}>
          <div className="flex items-center gap-1.5">
            <h1 className="truncate text-lg font-bold text-white">{player.fullName}</h1>
            {player.verificationStatus === 'approved' && <span title="Approved">✓</span>}
          </div>
          <p className="mt-0.5 truncate text-sm text-white/85">{roleLabel(player.role)}</p>
        </div>
      </div>

      <div className="mt-5 grid grid-cols-4 gap-2">
        <QuickStat value={summary ? `${summary.matchesPlayed}` : '-'} label="Matches" />
        <QuickStat value={summary ? `${summary.totalRuns}` : '-'} label="Runs" />
        <QuickStat value={summary ? `${summary.totalWickets}` : '-'} label="Wickets" />
        <QuickStat value={player.rating ? formatRating(player.rating) : '-'} label="Rating" />
      </div>
    </div>
  )
}

function DetailRow({ label, value }: { label: string; value: string | null | undefined }) {
  if (!value) return null
  return (
    <div className="flex items-center justify-between gap-4 py-2.5">
      <span className="text-sm text-text-secondary">{label}</span>
      <span className="max-w-[60%] truncate text-right text-sm font-semibold text-text-primary">{value}</span>
    </div>
  )
}

function DetailCard({ player }: { player: Player }) {
  const rows: { label: string; value: string | null }[] = [
    { label: 'Batting Style', value: player.battingStyle },
    { label: 'Bowling Style', value: player.bowlingStyle },
    { label: 'Date of Birth', value: player.dob ? formatDob(player.dob) : null },
    { label: 'Gender', value: player.gender },
    { label: 'Playing Role', value: roleLabel(player.role) },
    { label: 'Age Category', value: player.ageCategory },
    { label: 'Preferred Position', value: player.preferredPosition },
    { label: 'Experience', value: player.experience },
    { label: 'Phone', value: player.phone },
    { label: 'Email', value: player.email },
    { label: 'Address', value: player.address },
    { label: 'Base Price', value: player.basePrice ? `₹${player.basePrice}` : null },
  ]
  const visibleRows = rows.filter((r) => r.value)

  const documentLinks: { label: string; url: string }[] = [
    ...(player.photoUrl ? [{ label: 'Photo', url: player.photoUrl }] : []),
    ...(player.idDocumentUrl ? [{ label: 'ID document', url: player.idDocumentUrl }] : []),
    ...(player.addressProofUrl ? [{ label: 'Address proof', url: player.addressProofUrl }] : []),
    ...(player.otherDocumentUrls ?? []).map((url, i) => ({ label: `Other document ${i + 1}`, url })),
  ]

  return (
    <div className="rounded-2xl border border-border bg-card p-5">
      <h3 className="mb-1 text-sm font-semibold text-text-primary">Profile</h3>
      <div className="divide-y divide-border">
        {visibleRows.map((row) => (
          <DetailRow key={row.label} label={row.label} value={row.value} />
        ))}
      </div>

      {player.previousStatsNotes && (
        <div className="mt-2 border-t border-border pt-3">
          <span className="text-sm text-text-secondary">Previous teams / stats notes</span>
          <p className="mt-1 whitespace-pre-wrap text-sm text-text-primary">{player.previousStatsNotes}</p>
        </div>
      )}

      {documentLinks.length > 0 && (
        <div className="mt-3 flex flex-wrap gap-2 border-t border-border pt-3">
          {documentLinks.map((doc) => (
            <a
              key={doc.label}
              href={resolveMediaUrl(doc.url)}
              target="_blank"
              rel="noreferrer"
              className="rounded-full border border-border bg-page px-3 py-1 text-xs font-medium text-primary hover:underline"
            >
              {doc.label} ↗
            </a>
          ))}
        </div>
      )}
    </div>
  )
}

function StatBlock({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="flex flex-col gap-0.5 rounded-xl bg-page px-3 py-2.5">
      <span className="text-xs text-text-muted">{label}</span>
      <span className="text-base font-bold text-text-primary">{value}</span>
    </div>
  )
}

/** Batting/Bowling/Fielding career summary — real numbers from
 * `GET .../statistics`, computed on read from the ball-by-ball log (see
 * PlayerStatistics doc in types/player.ts). Only rendered once statistics
 * have loaded and the player has at least one figure to show, per the
 * "don't show empty placeholders" discipline. */
function StatsSummary({ player }: { player: Player }) {
  const { data: stats, isLoading, isError } = usePlayerStatistics(player.id)

  if (isLoading) return <div className="text-sm text-text-secondary">Loading statistics…</div>
  if (isError || !stats) return <div className="text-sm text-negative">Could not load statistics.</div>

  if (stats.summary.matchesPlayed === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-border p-8 text-center text-sm text-text-muted">
        No completed-match statistics yet — this player hasn't appeared in a completed match.
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="rounded-2xl border border-border bg-card p-5">
        <h3 className="mb-3 text-sm font-semibold text-text-primary">Batting</h3>
        <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
          <StatBlock label="Innings" value={stats.batting.innings} />
          <StatBlock label="Runs" value={stats.batting.runs} />
          <StatBlock
            label="Highest"
            value={`${stats.batting.highestScore}${stats.batting.highestScoreNotOut ? '*' : ''}`}
          />
          <StatBlock label="Average" value={stats.batting.average ?? '—'} />
          <StatBlock label="Strike Rate" value={stats.batting.strikeRate} />
          <StatBlock label="4s / 6s" value={`${stats.batting.fours} / ${stats.batting.sixes}`} />
          <StatBlock label="50s / 100s" value={`${stats.batting.fifties} / ${stats.batting.hundreds}`} />
        </div>
      </div>

      <div className="rounded-2xl border border-border bg-card p-5">
        <h3 className="mb-3 text-sm font-semibold text-text-primary">Bowling</h3>
        <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
          <StatBlock label="Innings" value={stats.bowling.innings} />
          <StatBlock label="Overs" value={stats.bowling.overs} />
          <StatBlock label="Wickets" value={stats.bowling.wickets} />
          <StatBlock label="Economy" value={stats.bowling.economy ?? '—'} />
          <StatBlock label="Average" value={stats.bowling.average ?? '—'} />
          <StatBlock label="Maidens" value={stats.bowling.maidens} />
          <StatBlock
            label="Best"
            value={stats.bowling.bestBowling ? `${stats.bowling.bestBowling.wickets}/${stats.bowling.bestBowling.runsConceded}` : '—'}
          />
        </div>
      </div>

      <div className="rounded-2xl border border-border bg-card p-5">
        <h3 className="mb-3 text-sm font-semibold text-text-primary">Fielding</h3>
        <div className="grid grid-cols-3 gap-2.5">
          <StatBlock label="Catches" value={stats.fielding.catches} />
          <StatBlock label="Run-outs" value={stats.fielding.runOuts} />
          <StatBlock label="Stumpings" value={stats.fielding.stumpings} />
        </div>
      </div>

      {stats.matchHistory.length > 0 && <MatchHistoryTable matches={stats.matchHistory} />}
    </div>
  )
}

function MatchHistoryTable({ matches }: { matches: PlayerMatchHistoryEntry[] }) {
  // Most recent first for display, even though the API returns ascending (for trend graphs).
  const rows = [...matches].reverse()

  return (
    <div className="overflow-x-auto rounded-2xl border border-border bg-card">
      <table className="w-full min-w-[560px] border-collapse text-sm">
        <thead>
          <tr className="bg-page text-xs font-semibold uppercase tracking-wide text-text-secondary">
            <th className="px-4 py-3 text-left">Date</th>
            <th className="px-4 py-3 text-left">Opponent</th>
            <th className="px-4 py-3 text-left">Result</th>
            <th className="px-4 py-3 text-left">Batting</th>
            <th className="px-4 py-3 text-left">Bowling</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((m, index) => (
            <tr key={m.matchId} className={index % 2 === 1 ? 'bg-page' : 'bg-card'}>
              <td className="px-4 py-3 text-text-secondary">{m.scheduledAt ? formatDob(m.scheduledAt) : '—'}</td>
              <td className="px-4 py-3 font-medium text-text-primary">{m.opponentTeamName}</td>
              <td className="px-4 py-3 text-text-secondary">
                {m.won === null ? (m.resultSummary ?? '—') : m.won ? 'Won' : 'Lost'}
              </td>
              <td className="px-4 py-3 text-text-primary">
                {m.batting ? `${m.batting.runs}${m.batting.isOut ? '' : '*'} (${m.batting.ballsFaced})` : '—'}
              </td>
              <td className="px-4 py-3 text-text-primary">
                {m.bowling ? `${m.bowling.wickets}/${m.bowling.runsConceded} (${m.bowling.overs})` : '—'}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

/**
 * Player detail page — full profile matching the teal-gradient visual
 * language apps/mobile's PlayerStatisticsScreen was just redesigned with
 * (header card, embedded quick stats, detail card, stat sections), rebuilt
 * here with Tailwind rather than a literal Flutter widget port. Route shape
 * this expects to be wired: `/players/:playerId`.
 */
export function PlayerDetailPage() {
  const { playerId } = useParams<{ playerId: string }>()
  const { data: player, isLoading, isError } = usePlayer(playerId)
  const { data: stats } = usePlayerStatistics(playerId)
  const role = useAuthStore((s) => s.role)
  const isSuperAdmin = useAuthStore((s) => s.isSuperAdmin)
  const canReview = roleAtOrAbove(role, 'tournament_admin', isSuperAdmin)

  if (isLoading) {
    return <div className="text-sm text-text-secondary">Loading player…</div>
  }

  if (isError || !player) {
    return (
      <div className="rounded-2xl border border-negative/30 bg-negative/5 p-6 text-sm text-negative">
        Could not load this player.
      </div>
    )
  }

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-4">
      <Link to="/players" className="text-xs font-medium text-text-secondary hover:text-primary">
        ← Players
      </Link>

      <ProfileHeader player={player} summary={stats?.summary} />

      <DetailCard player={player} />

      {canReview && <RegistrationReviewPanel player={player} />}

      <StatsSummary player={player} />
    </div>
  )
}
