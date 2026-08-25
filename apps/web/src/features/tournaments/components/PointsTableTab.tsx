import { usePointsTable } from '../hooks/usePointsTable'
import type { PointsTableRow } from '../../../types/tournament'

/** Restyled to match the same "panel" language as the mobile app's
 * PointsTableTab redesign (points_table_tab.dart) — zebra-striped rows,
 * bold Pts column, NRR colored positive/negative/neutral. Two things the
 * mobile version deliberately omits are omitted here too, for the same
 * documented reason (see that file's doc comment): no "..." export menu (no
 * such action exists on the backend), and no Group A/B filter chips
 * (TournamentsService.getPointsTable computes one flat table — no
 * group-scoped standings endpoint exists). Only the single real "All Teams"
 * state is shown. */
export function PointsTableTab({ tournamentId }: { tournamentId: string }) {
  const { data: rows, isLoading, isError } = usePointsTable(tournamentId)

  if (isLoading) {
    return <div className="text-sm text-text-secondary">Loading points table…</div>
  }

  if (isError) {
    return (
      <div className="rounded-2xl border border-negative/30 bg-negative/5 p-6 text-sm text-negative">
        Could not load the points table.
      </div>
    )
  }

  if (!rows || rows.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-border p-10 text-center text-sm text-text-muted">
        No standings yet — the points table fills in once teams are registered and matches are completed.
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <span className="rounded-full border border-primary bg-primary/10 px-3 py-1 text-xs font-semibold text-primary">
          All Teams
        </span>
      </div>

      <div className="overflow-x-auto rounded-2xl border border-border bg-card">
        <table className="w-full min-w-[640px] border-collapse text-sm">
          <thead>
            <tr className="bg-page text-xs font-semibold uppercase tracking-wide text-text-secondary">
              <th className="px-4 py-3 text-left">#</th>
              <th className="px-4 py-3 text-left">Team</th>
              <th className="px-4 py-3 text-right">P</th>
              <th className="px-4 py-3 text-right">W</th>
              <th className="px-4 py-3 text-right">L</th>
              <th className="px-4 py-3 text-right">NR</th>
              <th className="px-4 py-3 text-right">Pts</th>
              <th className="px-4 py-3 text-right">NRR</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, index) => (
              <PointsTableRowView key={row.tournamentTeamId} row={row} zebra={index % 2 === 1} />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

function PointsTableRowView({ row, zebra }: { row: PointsTableRow; zebra: boolean }) {
  const nrrClass = row.netRunRate > 0 ? 'text-positive' : row.netRunRate < 0 ? 'text-negative' : 'text-text-secondary'

  return (
    <tr className={zebra ? 'bg-page' : 'bg-card'}>
      <td className="px-4 py-3 font-semibold text-text-primary">{row.position}</td>
      <td className="max-w-[200px] truncate px-4 py-3 font-medium text-text-primary">{row.teamName}</td>
      <td className="px-4 py-3 text-right text-text-primary">{row.played}</td>
      <td className="px-4 py-3 text-right text-text-primary">{row.won}</td>
      <td className="px-4 py-3 text-right text-text-primary">{row.lost}</td>
      <td className="px-4 py-3 text-right text-text-primary">{row.noResult}</td>
      <td className="px-4 py-3 text-right font-bold text-primary">{row.points}</td>
      <td className={`px-4 py-3 text-right font-semibold ${nrrClass}`}>{row.netRunRate.toFixed(2)}</td>
    </tr>
  )
}
