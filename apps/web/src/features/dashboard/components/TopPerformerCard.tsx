import type { AwardResult } from '../../../types/tournament'

/** Renders an honest "Not awarded yet" state when `award.winner` is null
 * (e.g. no completed matches) rather than fabricating a name — mirrors the
 * mobile dashboard's award-card precedent. */
export function TopPerformerCard({ label, award }: { label: string; award: AwardResult | undefined }) {
  const winner = award?.winner

  return (
    <div className="rounded-2xl border border-border bg-card p-4 text-center">
      <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-primary/10 text-lg font-bold text-primary">
        {winner ? winner.playerName.slice(0, 1).toUpperCase() : '—'}
      </div>
      {winner ? (
        <>
          <p className="mt-2 text-sm font-semibold text-text-primary">{winner.playerName}</p>
          <p className="text-xs text-text-secondary">{winner.teamName}</p>
          <p className="mt-1 text-xs font-medium text-primary">{winner.value}</p>
        </>
      ) : (
        <p className="mt-2 text-xs text-text-muted">Not awarded yet</p>
      )}
      <p className="mt-2 text-[11px] font-medium uppercase tracking-wide text-text-muted">{label}</p>
    </div>
  )
}
