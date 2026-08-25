/**
 * Design tokens mirrored 1:1 from apps/mobile/lib/core/theme/app_colors.dart
 * so the web dashboard and mobile app share one brand identity. Keep these
 * two files in sync if either changes.
 */
export const colors = {
  primary: '#16A34A',
  primaryLight: '#22C55E',
  primaryDark: '#15803D',

  navy: '#111827',
  navySurface: '#1E293B',

  pageBackground: '#F8FAFC',
  cardBackground: '#FFFFFF',
  border: '#E2E8F0',

  textPrimary: '#1E293B',
  textSecondary: '#64748B',
  textMuted: '#94A3B8',

  live: '#EF4444',
  info: '#3B82F6',
  purple: '#8B5CF6',
  orange: '#F97316',
  amber: '#F59E0B',
  teal: '#0F766E',
  tealDark: '#134E4A',

  positive: '#16A34A',
  negative: '#DC2626',
} as const

/** Rotating accent set for stat-card icon badges / chart legends. */
export const accentColors = [
  colors.purple,
  colors.info,
  colors.primary,
  colors.orange,
  colors.teal,
  colors.amber,
] as const
