/** A small set of semantic color tones, each backed by an existing theme
 * token (see src/core/theme/colors.ts / src/index.css) — callers pick a
 * tone, not a raw color, so every status pill in the app stays visually
 * consistent. Add a tone here (not an arbitrary Tailwind class at the call
 * site) if a new status needs a color this set doesn't cover. */
export type PillTone = 'neutral' | 'info' | 'positive' | 'negative' | 'warning' | 'live' | 'navy'

const TONE_CLASSES: Record<PillTone, string> = {
  neutral: 'bg-text-muted/10 text-text-secondary',
  info: 'bg-info/10 text-info',
  positive: 'bg-positive/10 text-positive',
  negative: 'bg-negative/10 text-negative',
  warning: 'bg-amber/10 text-amber',
  live: 'bg-live/10 text-live',
  navy: 'bg-navy/10 text-navy',
}

/** Generic label+color pill — status/state badges anywhere in the app
 * (tournament status, registration window, application review status,
 * etc.) should render through this rather than a one-off <span>. */
export function StatusPill({ label, tone = 'neutral' }: { label: string; tone?: PillTone }) {
  return (
    <span
      className={`inline-flex items-center whitespace-nowrap rounded-full px-2.5 py-1 text-xs font-semibold ${TONE_CLASSES[tone]}`}
    >
      {label}
    </span>
  )
}
