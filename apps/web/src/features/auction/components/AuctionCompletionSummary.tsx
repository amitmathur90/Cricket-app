import type { AuctionReport } from '../../../types/auction'

/** Parses a decimal-string purse/spend field (see AuctionReport's doc
 * comment — these come back as strings, same convention as every other
 * decimal column in this app) for the aggregate totals below. Missing
 * (`null`) purse fields — e.g. a team that somehow has no purse set — are
 * treated as 0 rather than dropped, so the aggregate always reflects every
 * team in `report.teams`. */
function toNumber(value: string | null): number {
  if (value == null) return 0
  const n = parseFloat(value)
  return Number.isNaN(n) ? 0 : n
}

/**
 * The single "AUCTION COMPLETED" rendering for a finished session's report —
 * used both inline on LiveAuctionRoomPage (once `session.status ===
 * 'completed'`) and on the dedicated AuctionSummaryPage, so there is exactly
 * one place that computes these aggregates rather than two divergent
 * renderings of the same completed-session state. Every figure is derived
 * from the real `AuctionReport` passed in — nothing here is fetched or
 * fabricated locally.
 */
export function AuctionCompletionSummary({ report }: { report: AuctionReport }) {
  const totalPlayers = report.players.length
  const soldPlayers = report.players.filter((p) => p.status === 'sold').length
  const unsoldPlayers = report.players.filter((p) => p.status === 'unsold').length
  const teamsCount = report.teams.length
  const totalPoints = report.teams.reduce((sum, t) => sum + toNumber(t.purseTotal), 0)
  const pointsSpent = report.teams.reduce((sum, t) => sum + toNumber(t.totalSpent), 0)
  const remainingPoints = report.teams.reduce((sum, t) => sum + toNumber(t.purseRemaining), 0)

  return (
    <div className="rounded-2xl border border-border bg-card p-5">
      <p className="text-xs font-bold uppercase tracking-wide text-positive">Auction Completed</p>

      <div className="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <SummaryStat label="Total Players" value={totalPlayers} />
        <SummaryStat label="Sold Players" value={soldPlayers} />
        <SummaryStat label="Unsold Players" value={unsoldPlayers} />
        <SummaryStat label="Teams" value={teamsCount} />
        <SummaryStat label="Total Points" value={totalPoints} />
        <SummaryStat label="Points Spent" value={pointsSpent} />
        <SummaryStat label="Remaining Points" value={remainingPoints} />
      </div>

      <div className="mt-5 flex flex-col gap-2">
        <h3 className="text-sm font-semibold text-text-primary">Team breakdown</h3>
        {report.teams.map((t) => (
          <div key={t.tournamentTeamId} className="flex flex-wrap items-center justify-between gap-x-3 gap-y-0.5 text-sm">
            <span className="text-text-primary">{t.teamName}</span>
            <span className="text-text-secondary">
              {t.playersBought} players · spent {t.totalSpent} · purse left {t.purseRemaining ?? '—'}
            </span>
          </div>
        ))}
      </div>
    </div>
  )
}

function SummaryStat({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-xl bg-page px-3 py-2.5">
      <p className="text-xs text-text-secondary">{label}</p>
      <p className="text-lg font-bold text-text-primary">{value}</p>
    </div>
  )
}
