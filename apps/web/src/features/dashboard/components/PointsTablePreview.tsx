import type { PointsTableRow } from '../../../types/tournament'

export function PointsTablePreview({ rows }: { rows: PointsTableRow[] }) {
  const top5 = rows.slice(0, 5)

  if (top5.length === 0) {
    return <p className="text-sm text-text-muted">No standings yet.</p>
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="text-left text-xs text-text-muted">
            <th className="py-1.5 pr-2 font-medium">#</th>
            <th className="py-1.5 pr-2 font-medium">Team</th>
            <th className="py-1.5 pr-2 text-center font-medium">P</th>
            <th className="py-1.5 pr-2 text-center font-medium">W</th>
            <th className="py-1.5 pr-2 text-center font-medium">L</th>
            <th className="py-1.5 pr-2 text-center font-medium">Pts</th>
            <th className="py-1.5 text-center font-medium">NRR</th>
          </tr>
        </thead>
        <tbody>
          {top5.map((row) => (
            <tr key={row.tournamentTeamId} className="border-t border-border">
              <td className="py-2 pr-2 text-text-secondary">{row.position}</td>
              <td className="py-2 pr-2 font-medium text-text-primary">{row.teamName}</td>
              <td className="py-2 pr-2 text-center text-text-secondary">{row.played}</td>
              <td className="py-2 pr-2 text-center text-text-secondary">{row.won}</td>
              <td className="py-2 pr-2 text-center text-text-secondary">{row.lost}</td>
              <td className="py-2 pr-2 text-center font-semibold text-primary">{row.points}</td>
              <td
                className={`py-2 text-center font-medium ${
                  row.netRunRate > 0 ? 'text-positive' : row.netRunRate < 0 ? 'text-negative' : 'text-text-secondary'
                }`}
              >
                {row.netRunRate > 0 ? '+' : ''}
                {row.netRunRate.toFixed(2)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
