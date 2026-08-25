import { Link } from 'react-router-dom'
import { RoleGate } from '../../../core/router/RoleGate'
import { StatusPill } from '../../../shared/components/StatusPill'
import { useTournaments } from '../hooks/useTournaments'
import { registrationStatusTone, tournamentStatusTone, TOURNAMENT_STATUS_LABELS } from '../statusTones'
import { REGISTRATION_STATUS_LABELS, TOURNAMENT_FORMATS, type Tournament } from '../../../types/tournament'
import { resolveMediaUrl } from '../../../core/api/client'

function formatLabel(format: Tournament['format']): string {
  return TOURNAMENT_FORMATS.find((f) => f.value === format)?.label ?? format
}

function formatDateRange(startDate: string, endDate: string): string {
  const start = new Date(startDate)
  const end = new Date(endDate)
  const fmt = (d: Date) => d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return `${startDate} to ${endDate}`
  return `${fmt(start)} – ${fmt(end)}`
}

function TournamentCard({ tournament }: { tournament: Tournament }) {
  const teamsLabel = tournament.numberOfTeams
    ? `${tournament.teamsCount}/${tournament.numberOfTeams} teams`
    : `${tournament.teamsCount} teams`

  return (
    <Link
      to={`/tournaments/${tournament.id}`}
      className="flex flex-col gap-3 rounded-2xl border border-border bg-card p-5 transition hover:border-primary/40 hover:shadow-sm"
    >
      <div className="flex items-start gap-3">
        <div className="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-xl">
          {tournament.logoUrl ? (
            <img src={resolveMediaUrl(tournament.logoUrl)} alt="" className="h-full w-full object-cover" />
          ) : (
            '🏆'
          )}
        </div>
        <div className="min-w-0 flex-1">
          <h3 className="truncate text-base font-semibold text-text-primary">{tournament.name}</h3>
          <p className="truncate text-sm text-text-secondary">
            {formatLabel(tournament.format)} · {formatDateRange(tournament.startDate, tournament.endDate)}
          </p>
          {tournament.location && <p className="truncate text-xs text-text-muted">📍 {tournament.location}</p>}
        </div>
      </div>

      <div className="flex flex-wrap gap-1.5">
        <StatusPill label={teamsLabel} tone="neutral" />
        <StatusPill label={TOURNAMENT_STATUS_LABELS[tournament.status]} tone={tournamentStatusTone(tournament.status)} />
        <StatusPill
          label={REGISTRATION_STATUS_LABELS[tournament.registrationStatus]}
          tone={registrationStatusTone(tournament.registrationStatus)}
        />
      </div>
    </Link>
  )
}

export function TournamentListPage() {
  const { data: tournaments, isLoading, isError } = useTournaments()

  return (
    <div>
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-text-primary">Tournaments</h1>
          <p className="mt-1 text-sm text-text-secondary">Manage every tournament in your organization.</p>
        </div>
        <RoleGate minRole="tournament_admin">
          <Link
            to="/tournaments/create"
            className="rounded-xl bg-primary px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-primary-dark"
          >
            + Create Tournament
          </Link>
        </RoleGate>
      </div>

      {isLoading && <div className="mt-8 text-sm text-text-secondary">Loading tournaments…</div>}

      {isError && (
        <div className="mt-8 rounded-2xl border border-negative/30 bg-negative/5 p-6 text-sm text-negative">
          Could not load tournaments. Try refreshing the page.
        </div>
      )}

      {!isLoading && !isError && tournaments && tournaments.length === 0 && (
        <div className="mt-8 rounded-2xl border border-dashed border-border p-10 text-center text-sm text-text-muted">
          No tournaments yet.{' '}
          <RoleGate minRole="tournament_admin">
            <>
              Get started by{' '}
              <Link to="/tournaments/create" className="font-semibold text-primary hover:underline">
                creating one
              </Link>
              .
            </>
          </RoleGate>
        </div>
      )}

      {tournaments && tournaments.length > 0 && (
        <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {tournaments.map((tournament) => (
            <TournamentCard key={tournament.id} tournament={tournament} />
          ))}
        </div>
      )}
    </div>
  )
}
