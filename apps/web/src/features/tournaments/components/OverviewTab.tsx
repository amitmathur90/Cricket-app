import type { Tournament } from '../../../types/tournament'
import { TOURNAMENT_FORMATS } from '../../../types/tournament'

function formatLabel(format: Tournament['format']): string {
  return TOURNAMENT_FORMATS.find((f) => f.value === format)?.label ?? format
}

function InfoRow({ label, value }: { label: string; value: string | number | null | undefined }) {
  if (value === null || value === undefined || value === '') return null
  return (
    <div className="flex flex-col gap-0.5 py-2">
      <span className="text-xs font-medium text-text-muted">{label}</span>
      <span className="text-sm text-text-primary">{value}</span>
    </div>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-2xl border border-border bg-card p-5">
      <h3 className="mb-2 text-sm font-semibold text-text-primary">{title}</h3>
      <div className="grid grid-cols-1 gap-x-6 divide-y divide-border sm:grid-cols-2 sm:divide-y-0">
        {children}
      </div>
    </div>
  )
}

export function OverviewTab({ tournament }: { tournament: Tournament }) {
  const hasRules =
    tournament.tournamentRules || tournament.matchRules || tournament.pointsSystem || tournament.tieBreakerRules

  return (
    <div className="flex flex-col gap-4">
      {tournament.description && (
        <div className="rounded-2xl border border-border bg-card p-5">
          <h3 className="mb-1 text-sm font-semibold text-text-primary">Description</h3>
          <p className="whitespace-pre-wrap text-sm text-text-secondary">{tournament.description}</p>
        </div>
      )}

      <Section title="Basic info">
        <InfoRow label="Format" value={formatLabel(tournament.format)} />
        <InfoRow label="Dates" value={`${tournament.startDate} to ${tournament.endDate}`} />
        <InfoRow label="Location" value={tournament.location} />
        <InfoRow label="Organizer" value={tournament.organizerName} />
        <InfoRow label="Contact email" value={tournament.contactEmail} />
        <InfoRow label="Contact phone" value={tournament.contactPhone} />
        <InfoRow
          label="Teams"
          value={tournament.numberOfTeams ? `${tournament.teamsCount}/${tournament.numberOfTeams}` : tournament.teamsCount}
        />
        <InfoRow label="Max players per team" value={tournament.maxPlayersPerTeam} />
        <InfoRow label="Auction enabled" value={tournament.auctionEnabled ? 'Yes' : 'No'} />
      </Section>

      {hasRules && (
        <Section title="Rules">
          <InfoRow label="Tournament rules" value={tournament.tournamentRules} />
          <InfoRow label="Match rules" value={tournament.matchRules} />
          <InfoRow label="Points system" value={tournament.pointsSystem} />
          <InfoRow label="Tie-breaker rules" value={tournament.tieBreakerRules} />
        </Section>
      )}

      <Section title="Registration">
        <InfoRow label="Opens" value={tournament.registrationOpensAt} />
        <InfoRow label="Closes" value={tournament.registrationClosesAt} />
        <InfoRow
          label="Player fee"
          value={tournament.playerRegistrationFee !== null ? `₹${tournament.playerRegistrationFee}` : null}
        />
        <InfoRow
          label="Team fee"
          value={tournament.teamRegistrationFee !== null ? `₹${tournament.teamRegistrationFee}` : null}
        />
      </Section>
    </div>
  )
}
