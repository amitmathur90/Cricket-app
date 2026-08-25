import { useState } from 'react'
import { StatusPill } from '../../../shared/components/StatusPill'
import { PrimaryButton, SecondaryButton, Textarea } from '../../../shared/components/FormPrimitives'
import { resolveMediaUrl } from '../../../core/api/client'
import { useApplications, useReviewApplication } from '../hooks/useApplications'
import { applicationStatusTone } from '../statusTones'
import { APPLICATION_STATUS_LABELS, type TournamentApplication, type TournamentApplicationStatus } from '../../../types/tournament'

const FILTERS: { label: string; value: TournamentApplicationStatus | undefined }[] = [
  { label: 'Pending', value: 'pending' },
  { label: 'Approved', value: 'approved' },
  { label: 'Rejected', value: 'rejected' },
  { label: 'All', value: undefined },
]

function FilterChip({ label, selected, onClick }: { label: string; selected: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`rounded-full border px-3 py-1 text-xs font-semibold transition ${
        selected
          ? 'border-primary bg-primary/10 text-primary'
          : 'border-border bg-card text-text-secondary hover:bg-page'
      }`}
    >
      {label}
    </button>
  )
}

function ApplicationRow({
  application,
  onApprove,
  onReject,
  isBusy,
}: {
  application: TournamentApplication
  onApprove: () => void
  onReject: (note: string | undefined) => void
  isBusy: boolean
}) {
  const [rejecting, setRejecting] = useState(false)
  const [note, setNote] = useState('')
  const player = application.player

  return (
    <div className="flex flex-col gap-3 border-b border-border px-4 py-4 last:border-b-0">
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-lg">
            {player?.photoUrl ? (
              <img src={resolveMediaUrl(player.photoUrl)} alt="" className="h-full w-full object-cover" />
            ) : (
              '🧑'
            )}
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-sm font-semibold text-text-primary">{player?.fullName ?? 'Unknown player'}</span>
              <StatusPill
                label={APPLICATION_STATUS_LABELS[application.status]}
                tone={applicationStatusTone(application.status)}
              />
            </div>
            <p className="text-xs text-text-secondary">
              {[player?.role, player?.ageCategory, application.reviewNote ? `Note: ${application.reviewNote}` : null]
                .filter(Boolean)
                .join(' · ')}
            </p>
          </div>
        </div>

        {application.status === 'pending' && !rejecting && (
          <div className="flex shrink-0 gap-2">
            <SecondaryButton type="button" onClick={() => setRejecting(true)} disabled={isBusy}>
              Reject
            </SecondaryButton>
            <PrimaryButton type="button" className="w-auto" onClick={onApprove} disabled={isBusy}>
              Approve
            </PrimaryButton>
          </div>
        )}
      </div>

      {rejecting && (
        <div className="flex flex-col gap-2 rounded-xl border border-border bg-page p-3">
          <Textarea
            placeholder="Reason (optional)"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            rows={2}
          />
          <div className="flex justify-end gap-2">
            <SecondaryButton
              type="button"
              onClick={() => {
                setRejecting(false)
                setNote('')
              }}
              disabled={isBusy}
            >
              Cancel
            </SecondaryButton>
            <PrimaryButton
              type="button"
              className="w-auto bg-negative hover:bg-negative/90"
              onClick={() => {
                onReject(note.trim() || undefined)
                setRejecting(false)
                setNote('')
              }}
              disabled={isBusy}
            >
              Confirm reject
            </PrimaryButton>
          </div>
        </div>
      )}
    </div>
  )
}

export function ApplicationsTab({ tournamentId }: { tournamentId: string }) {
  const [filter, setFilter] = useState<TournamentApplicationStatus | undefined>('pending')
  const { data: applications, isLoading, isError } = useApplications(tournamentId, filter)
  const reviewMutation = useReviewApplication(tournamentId)

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap gap-2">
        {FILTERS.map((f) => (
          <FilterChip key={f.label} label={f.label} selected={filter === f.value} onClick={() => setFilter(f.value)} />
        ))}
      </div>

      <div className="rounded-2xl border border-border bg-card">
        {isLoading && <div className="p-6 text-sm text-text-secondary">Loading applications…</div>}

        {isError && (
          <div className="p-6 text-sm text-negative">Could not load applications.</div>
        )}

        {!isLoading && !isError && applications && applications.length === 0 && (
          <div className="p-10 text-center text-sm text-text-muted">No applications here.</div>
        )}

        {applications && applications.length > 0 && (
          <div>
            {applications.map((application) => (
              <ApplicationRow
                key={application.id}
                application={application}
                isBusy={reviewMutation.isPending}
                onApprove={() =>
                  reviewMutation.mutate({ applicationId: application.id, payload: { status: 'approved' } })
                }
                onReject={(note) =>
                  reviewMutation.mutate({ applicationId: application.id, payload: { status: 'rejected', note } })
                }
              />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
