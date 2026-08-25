import { useState } from 'react'
import { StatusPill } from '../../../shared/components/StatusPill'
import { PrimaryButton, SecondaryButton, Textarea, ErrorText } from '../../../shared/components/FormPrimitives'
import { useSetVerification } from '../hooks/usePlayerVerification'
import { playerVerificationStatusTone } from '../statusTones'
import {
  ALLOWED_VERIFICATION_TRANSITIONS,
  PLAYER_VERIFICATION_STATUS_LABELS,
  type Player,
  type PlayerVerificationStatus,
} from '../../../types/player'

const ACTION_LABELS: Record<PlayerVerificationStatus, string> = {
  pending: 'Reset to pending', // unreachable target — never actually offered, see ALLOWED_VERIFICATION_TRANSITIONS
  verified: 'Verify',
  approved: 'Approve',
  rejected: 'Reject',
}

/**
 * Approve/reject workflow for a player's 4-stage verification status.
 * Offers ONLY the legal next transitions for the player's CURRENT status —
 * mirrors apps/mobile's PlayerListTab popup-menu logic and
 * PlayersService.ALLOWED_VERIFICATION_TRANSITIONS server-side exactly:
 *   pending  -> verified | rejected
 *   verified -> approved | rejected
 *   approved -> (terminal, no actions offered)
 *   rejected -> (terminal, no actions offered)
 * The server is the real enforcer of these rules (PlayersService.
 * setVerification rejects anything else with a 400) — this is UX only, same
 * disclaimer as RoleGate. Callers are expected to wrap this in
 * `<RoleGate minRole="tournament_admin">`, matching
 * `@Roles(ORG_ADMIN, TOURNAMENT_ADMIN)` on `PlayersController.setVerification`.
 */
export function RegistrationReviewPanel({ player }: { player: Player }) {
  const [pendingTarget, setPendingTarget] = useState<PlayerVerificationStatus | null>(null)
  const [note, setNote] = useState('')
  const mutation = useSetVerification(player.id)

  const nextStatuses = ALLOWED_VERIFICATION_TRANSITIONS[player.verificationStatus]

  async function confirm(status: PlayerVerificationStatus) {
    try {
      await mutation.mutateAsync({
        status: status as 'verified' | 'approved' | 'rejected',
        note: note.trim() || undefined,
      })
      setPendingTarget(null)
      setNote('')
    } catch {
      // stays open, error surfaced below
    }
  }

  return (
    <div className="rounded-2xl border border-border bg-card p-5">
      <div className="flex items-center justify-between gap-3">
        <h3 className="text-sm font-semibold text-text-primary">Registration review</h3>
        <StatusPill
          label={PLAYER_VERIFICATION_STATUS_LABELS[player.verificationStatus]}
          tone={playerVerificationStatusTone(player.verificationStatus)}
        />
      </div>

      {player.verificationNote && <p className="mt-2 text-sm text-text-secondary">Note: {player.verificationNote}</p>}

      {nextStatuses.length === 0 ? (
        <p className="mt-3 text-sm text-text-muted">
          {player.verificationStatus === 'approved'
            ? 'This player is fully approved — no further review action applies.'
            : 'This player was rejected — rejection is terminal, no further review action applies.'}
        </p>
      ) : (
        <div className="mt-3 flex flex-col gap-3">
          {!pendingTarget && (
            <div className="flex flex-wrap gap-2">
              {nextStatuses.map((status) => (
                <SecondaryButton
                  key={status}
                  type="button"
                  className={`w-auto ${status === 'rejected' ? 'text-negative' : ''}`}
                  onClick={() => setPendingTarget(status)}
                >
                  {ACTION_LABELS[status]}
                </SecondaryButton>
              ))}
            </div>
          )}

          {pendingTarget && (
            <div className="flex flex-col gap-2 rounded-xl border border-border bg-page p-3">
              <Textarea placeholder="Note (optional)" value={note} onChange={(e) => setNote(e.target.value)} rows={2} />
              <ErrorText>{mutation.isError ? 'Could not update verification status.' : null}</ErrorText>
              <div className="flex justify-end gap-2">
                <SecondaryButton
                  type="button"
                  onClick={() => {
                    setPendingTarget(null)
                    setNote('')
                  }}
                  disabled={mutation.isPending}
                >
                  Cancel
                </SecondaryButton>
                <PrimaryButton
                  type="button"
                  className={`w-auto ${pendingTarget === 'rejected' ? 'bg-negative hover:bg-negative/90' : ''}`}
                  onClick={() => confirm(pendingTarget)}
                  disabled={mutation.isPending}
                >
                  {mutation.isPending ? 'Saving…' : `Confirm ${ACTION_LABELS[pendingTarget].toLowerCase()}`}
                </PrimaryButton>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
