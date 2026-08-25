import { Link } from 'react-router-dom'
import { useAuthStore } from '../../core/auth/authStore'
import { useDashboardData } from './hooks/useDashboardData'
import { useOrgFinanceDashboard } from '../finance/hooks/useFinanceDashboard'
import { StatCard, FeaturedStatCard } from './components/StatCard'
import { LiveMatchCard } from './components/LiveMatchCard'
import { UpcomingMatchRow } from './components/UpcomingMatchRow'
import { PointsTablePreview } from './components/PointsTablePreview'
import { TopPerformerCard } from './components/TopPerformerCard'

function formatInr(amount: string): string {
  const n = Number(amount)
  return `₹${n.toLocaleString('en-IN', { maximumFractionDigits: 0 })}`
}

/**
 * Org-wide composition over tournaments/matches/players/points-table/awards
 * — mirrors apps/mobile's dashboard_overview.dart, with one deliberate
 * improvement: the Revenue card IS shown here (mobile's version omitted it
 * because it assumed no org-wide finance endpoint existed — that turned
 * out to be wrong; FinanceController.getDashboard genuinely aggregates
 * org-wide when tournamentId is omitted). There's still no period-over-
 * period delta field anywhere in that response, so only the real absolute
 * total is shown — never a fabricated "+X% from last month".
 */
export function DashboardPage() {
  const user = useAuthStore((s) => s.user)
  const {
    isLoading,
    tournaments,
    teamsCount,
    playersCount,
    matchesCount,
    liveMatches,
    upcomingMatches,
    primaryTournament,
    pointsTable,
    pointsTableLoading,
    awards,
    awardsLoading,
  } = useDashboardData()
  const { data: finance } = useOrgFinanceDashboard()

  if (isLoading) {
    return <div className="text-sm text-text-secondary">Loading dashboard…</div>
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-bold text-text-primary">Dashboard 🏆</h1>
        <p className="mt-1 text-sm text-text-secondary">Welcome back, {user?.fullName}</p>
      </div>

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5">
        <StatCard icon="🏆" value={tournaments.length} label="Tournaments" accentColorClass="bg-purple/12 text-purple" />
        <StatCard icon="👥" value={teamsCount} label="Teams" accentColorClass="bg-info/12 text-info" />
        <StatCard icon="🧑‍🤝‍🧑" value={playersCount} label="Players" accentColorClass="bg-primary/12 text-primary" />
        <StatCard icon="🏏" value={matchesCount} label="Matches" accentColorClass="bg-orange/12 text-orange" />
        {finance && <FeaturedStatCard icon="💰" value={formatInr(finance.totalRevenue)} label="Total Revenue" />}
      </div>

      {liveMatches.length > 0 && (
        <section>
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-text-primary">Live Matches</h2>
            <span className="text-xs text-text-secondary">{liveMatches.length} live now</span>
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {liveMatches.map((m) => (
              <LiveMatchCard key={m.id} match={m} />
            ))}
          </div>
        </section>
      )}

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <section className="rounded-2xl border border-border bg-card p-4">
          <div className="mb-2 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-text-primary">Upcoming Matches</h2>
            <Link to="/matches" className="text-xs font-medium text-primary hover:underline">
              View All
            </Link>
          </div>
          {upcomingMatches.length === 0 ? (
            <p className="py-4 text-sm text-text-muted">No upcoming matches scheduled.</p>
          ) : (
            <div className="flex flex-col">
              {upcomingMatches.map((m) => (
                <UpcomingMatchRow key={m.id} match={m} />
              ))}
            </div>
          )}
        </section>

        <section className="rounded-2xl border border-border bg-card p-4">
          <div className="mb-2 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-text-primary">Points Table</h2>
            {primaryTournament && (
              <Link
                to={`/tournaments/${primaryTournament.id}`}
                className="text-xs font-medium text-primary hover:underline"
              >
                View Full
              </Link>
            )}
          </div>
          {!primaryTournament ? (
            <p className="py-4 text-sm text-text-muted">No tournaments yet.</p>
          ) : pointsTableLoading ? (
            <p className="py-4 text-sm text-text-muted">Loading…</p>
          ) : (
            <PointsTablePreview rows={pointsTable} />
          )}
        </section>
      </div>

      {primaryTournament && !awardsLoading && awards && (
        <section>
          <h2 className="mb-3 text-sm font-semibold text-text-primary">Top Performers — {primaryTournament.name}</h2>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <TopPerformerCard label="Top Run Scorer" award={awards.bestBatsman} />
            <TopPerformerCard label="Top Wicket Taker" award={awards.bestBowler} />
            <TopPerformerCard label="Best All-Rounder" award={awards.bestAllRounder} />
            <TopPerformerCard label="Best Fielder" award={awards.bestFielder} />
          </div>
        </section>
      )}
    </div>
  )
}
