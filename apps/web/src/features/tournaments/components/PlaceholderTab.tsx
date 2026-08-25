/** Clean seam for a tab that isn't built yet — Teams/Players/Matches are
 * being built in a separate task right after this one, plugging into the
 * same TournamentDetailPage tab shell. Deliberately not a fake table/list —
 * see the task's honesty constraint on not fabricating data. */
export function PlaceholderTab({ label }: { label: string }) {
  return (
    <div className="rounded-2xl border border-dashed border-border p-10 text-center text-sm text-text-muted">
      {label} tab — built in the next pass.
    </div>
  )
}
