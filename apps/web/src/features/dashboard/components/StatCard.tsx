export function StatCard({ icon, value, label, accentColorClass }: {
  icon: string
  value: string | number
  label: string
  /** e.g. "text-purple bg-purple/12" — pass both text and bg utility classes. */
  accentColorClass: string
}) {
  return (
    <div className="rounded-2xl border border-border bg-card p-4">
      <div className={`flex h-10 w-10 items-center justify-center rounded-[10px] text-lg ${accentColorClass}`}>
        {icon}
      </div>
      <p className="mt-3 text-xl font-bold text-text-primary">{value}</p>
      <p className="text-sm text-text-secondary">{label}</p>
    </div>
  )
}

/** Solid-fill "featured" variant — the Revenue card in the dashboard
 * mockup, visually distinct from the other (white, icon-badge) stat cards.
 * Only ever rendered with a real figure from FinanceController.getDashboard
 * — never a fabricated one. */
export function FeaturedStatCard({ icon, value, label }: { icon: string; value: string; label: string }) {
  return (
    <div className="rounded-2xl bg-primary p-4 text-white">
      <div className="flex h-10 w-10 items-center justify-center rounded-[10px] bg-white/15 text-lg">{icon}</div>
      <p className="mt-3 text-xl font-bold">{value}</p>
      <p className="text-sm text-white/80">{label}</p>
    </div>
  )
}
