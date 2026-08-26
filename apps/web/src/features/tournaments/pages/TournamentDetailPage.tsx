import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { RoleGate } from '../../../core/router/RoleGate'
import { useAuthStore } from '../../../core/auth/authStore'
import { roleAtOrAbove } from '../../../types/organization'
import { StatusPill } from '../../../shared/components/StatusPill'
import { useTournament } from '../hooks/useTournaments'
import { tournamentStatusTone, TOURNAMENT_STATUS_LABELS } from '../statusTones'
import { OverviewTab } from '../components/OverviewTab'
import { ApplicationsTab } from '../components/ApplicationsTab'
import { PointsTableTab } from '../components/PointsTableTab'
import { TOURNAMENT_FORMATS, type Tournament } from '../../../types/tournament'
import { TeamsTab } from '../../teams/components/TeamsTab'
import { PlayersTab } from '../../players/components/PlayersTab'
import { MatchesTab } from '../../matches/components/MatchesTab'

type TabKey = 'overview' | 'teams' | 'players' | 'applications' | 'matches' | 'points-table'

function formatLabel(format: Tournament['format']): string {
  return TOURNAMENT_FORMATS.find((f) => f.value === format)?.label ?? format
}

/** 6-tab detail shell (Overview/Teams/Players/Applications/Matches/Points
 * Table), all wired to real data. Plain useState tab switching, no nested
 * routes. Auction isn't one of these tabs (sessions are tournament-scoped
 * but conceptually a bigger flow than a tab) — it's reached via the header
 * button instead, shown only when the tournament has auctionEnabled. */
export function TournamentDetailPage() {
  const { tournamentId } = useParams<{ tournamentId: string }>()
  const { data: tournament, isLoading, isError } = useTournament(tournamentId)
  const role = useAuthStore((s) => s.role)
  const isSuperAdmin = useAuthStore((s) => s.isSuperAdmin)
  // Applications review is org_admin/tournament_admin only server-side (see
  // TournamentApplicationsController.findAllForTournament/review) — hide the
  // tab entirely for anyone below that, rather than showing it and letting
  // it 403.
  const canReviewApplications = roleAtOrAbove(role, 'tournament_admin', isSuperAdmin)

  const [activeTab, setActiveTab] = useState<TabKey>('overview')

  if (isLoading) {
    return <div className="text-sm text-text-secondary">Loading tournament…</div>
  }

  if (isError || !tournament) {
    return (
      <div className="rounded-2xl border border-negative/30 bg-negative/5 p-6 text-sm text-negative">
        Could not load this tournament.
      </div>
    )
  }

  const tabs: { key: TabKey; label: string }[] = [
    { key: 'overview', label: 'Overview' },
    { key: 'teams', label: 'Teams' },
    { key: 'players', label: 'Players' },
    ...(canReviewApplications ? ([{ key: 'applications', label: 'Applications' }] as const) : []),
    { key: 'matches', label: 'Matches' },
    { key: 'points-table', label: 'Points Table' },
  ]

  return (
    <div className="flex flex-col gap-4">
      <div>
        <Link to="/tournaments" className="text-xs font-medium text-text-secondary hover:text-primary">
          ← Tournaments
        </Link>
        <div className="mt-1 flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap items-center gap-3">
            <h1 className="text-2xl font-bold text-text-primary">{tournament.name}</h1>
            <StatusPill label={TOURNAMENT_STATUS_LABELS[tournament.status]} tone={tournamentStatusTone(tournament.status)} />
          </div>
          {tournament.auctionEnabled && (
            <RoleGate minRole="tournament_admin">
              <Link
                to={`/tournaments/${tournament.id}/auction`}
                className="rounded-xl bg-primary px-4 py-2 text-sm font-semibold text-white transition hover:bg-primary-dark"
              >
                🔨 Auction
              </Link>
            </RoleGate>
          )}
        </div>
        <p className="mt-1 text-sm text-text-secondary">
          {formatLabel(tournament.format)} · {tournament.startDate} to {tournament.endDate}
          {tournament.auctionEnabled ? ' · Auction enabled' : ''}
        </p>
      </div>

      <div className="flex gap-1 overflow-x-auto border-b border-border">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            type="button"
            onClick={() => setActiveTab(tab.key)}
            className={`shrink-0 border-b-2 px-4 py-2.5 text-sm font-medium transition ${
              activeTab === tab.key
                ? 'border-primary text-primary'
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      <div>
        {activeTab === 'overview' && <OverviewTab tournament={tournament} />}
        {activeTab === 'teams' && <TeamsTab tournamentId={tournament.id} />}
        {activeTab === 'players' && <PlayersTab tournamentId={tournament.id} />}
        {activeTab === 'applications' && canReviewApplications && <ApplicationsTab tournamentId={tournament.id} />}
        {activeTab === 'matches' && <MatchesTab tournamentId={tournament.id} />}
        {activeTab === 'points-table' && <PointsTableTab tournamentId={tournament.id} />}
      </div>
    </div>
  )
}
