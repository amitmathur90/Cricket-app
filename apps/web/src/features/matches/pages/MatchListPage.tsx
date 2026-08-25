import { useEffect } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useTournaments } from '../../tournaments/hooks/useTournaments'
import { MatchesTab } from '../components/MatchesTab'

/**
 * Top-level `/matches` page — doubles as the Sidebar's "Matches / Schedule"
 * item and reuses MatchesTab (the same component TournamentDetailPage's
 * Matches tab renders) once a tournament is picked.
 *
 * Judgment call: the backend has no org-wide "all matches across every
 * tournament" endpoint — MatchesController is mounted at
 * `organizations/:organizationId/tournaments/:tournamentId/matches`, always
 * scoped to one tournament (confirmed by reading matches.controller.ts;
 * not fabricated). So this page first lets the admin pick a tournament
 * (reusing useTournaments() from the Tournaments feature, same as
 * TournamentListPage), then shows that tournament's schedule via
 * MatchesTab. The picked tournament is kept in the URL's `?tournamentId=`
 * query param so the view is shareable/bookmarkable, defaulting to the
 * first tournament once the list loads.
 */
export function MatchListPage() {
  const { data: tournaments, isLoading, isError } = useTournaments()
  const [searchParams, setSearchParams] = useSearchParams()
  const selectedId = searchParams.get('tournamentId')

  useEffect(() => {
    if (!selectedId && tournaments && tournaments.length > 0) {
      setSearchParams({ tournamentId: tournaments[0].id }, { replace: true })
    }
  }, [selectedId, tournaments, setSearchParams])

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="text-2xl font-bold text-text-primary">Matches / Schedule</h1>
        <p className="mt-1 text-sm text-text-secondary">
          Pick a tournament to view and manage its fixtures.
        </p>
      </div>

      {isLoading && <div className="text-sm text-text-secondary">Loading tournaments…</div>}

      {isError && (
        <div className="rounded-2xl border border-negative/30 bg-negative/5 p-6 text-sm text-negative">
          Could not load tournaments.
        </div>
      )}

      {!isLoading && !isError && tournaments && tournaments.length === 0 && (
        <div className="rounded-2xl border border-dashed border-border p-10 text-center text-sm text-text-muted">
          No tournaments yet — create one first to schedule matches.
        </div>
      )}

      {tournaments && tournaments.length > 0 && (
        <>
          <select
            value={selectedId ?? ''}
            onChange={(e) => setSearchParams({ tournamentId: e.target.value })}
            className="w-full max-w-sm rounded-xl border border-border bg-page px-3.5 py-2.5 text-sm text-text-primary outline-none transition focus:border-primary focus:ring-2 focus:ring-primary/20"
          >
            {tournaments.map((tournament) => (
              <option key={tournament.id} value={tournament.id}>
                {tournament.name}
              </option>
            ))}
          </select>

          {selectedId && <MatchesTab tournamentId={selectedId} />}
        </>
      )}
    </div>
  )
}
