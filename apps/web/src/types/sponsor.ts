/** Mirrors apps/backend/src/database/entities/sponsor.entity.ts's SponsorStatus enum. */
export type SponsorStatus = 'active' | 'inactive'

export const SPONSOR_STATUS_LABELS: Record<SponsorStatus, string> = {
  active: 'Active',
  inactive: 'Inactive',
}

/**
 * Mirrors apps/backend/src/database/entities/sponsor.entity.ts (every
 * column) — a lightweight org-level sponsor profile, same shape as
 * `Coach`/`Venue`/`Official`. The `visibleOn*` flags are honest
 * configuration metadata for display surfaces that don't render sponsors
 * yet (tournament website, social media, scoreboard overlay) — see the
 * entity's doc comment; `visibleOnApp` is the one flag with a real public
 * consumer today (PublicSponsorsController). `amount` is a Postgres
 * `decimal` column, kept as a string (not parsed to `number`) to avoid
 * float rounding on a monetary value the client never does arithmetic on —
 * same choice as apps/mobile's Sponsor model and this app's Tournament fee
 * fields.
 */
export interface Sponsor {
  id: string
  organizationId: string
  companyName: string
  logoUrl: string | null
  /** Free text, e.g. "Title Sponsor", "Gold", "Silver" — deliberately not an enum. */
  packageName: string | null
  /** Decimal amount as a string, e.g. "500000.00". */
  amount: string | null
  /** ISO date string (YYYY-MM-DD), or null. */
  contractStartDate: string | null
  /** ISO date string (YYYY-MM-DD), or null. */
  contractEndDate: string | null
  status: SponsorStatus

  // --- Display-surface visibility configuration (metadata only — see doc above) ---
  visibleOnWebsite: boolean
  visibleOnApp: boolean
  visibleOnMatchScreen: boolean
  visibleOnScoreboard: boolean
  visibleOnSocialMedia: boolean

  createdAt: string
}

/** Mirrors CreateSponsorDto exactly — request body for POST .../sponsors. */
export interface CreateSponsorPayload {
  companyName: string
  logoUrl?: string
  packageName?: string
  /** Numeric string, e.g. "500000.00" (backend validates with @IsNumberString). */
  amount?: string
  /** ISO date string (YYYY-MM-DD). */
  contractStartDate?: string
  /** ISO date string (YYYY-MM-DD). */
  contractEndDate?: string
  status?: SponsorStatus
  visibleOnWebsite?: boolean
  visibleOnApp?: boolean
  visibleOnMatchScreen?: boolean
  visibleOnScoreboard?: boolean
  visibleOnSocialMedia?: boolean
}

/** Mirrors UpdateSponsorDto — PartialType(CreateSponsorDto). */
export type UpdateSponsorPayload = Partial<CreateSponsorPayload>
