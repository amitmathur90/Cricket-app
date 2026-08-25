/** Mirrors apps/backend/src/database/entities/match.entity.ts's MatchStatus enum. */
export type MatchStatus = 'scheduled' | 'live' | 'completed' | 'cancelled'

export const MATCH_STATUS_LABELS: Record<MatchStatus, string> = {
  scheduled: 'Scheduled',
  live: 'Live',
  completed: 'Completed',
  cancelled: 'Cancelled',
}

/** Mirrors apps/backend/src/database/entities/official.entity.ts's OfficialRole enum. */
export type OfficialRole = 'umpire' | 'scorer' | 'match_referee'

/**
 * Minimal shape of the `venues` row nested on a match response (see
 * MatchesService.RESPONSE_RELATIONS — `venue` is eager-loaded whenever
 * `venueId` is set). Duplicated here rather than importing a full Venues
 * feature module, same pattern as `ApplicationPlayer` in types/tournament.ts
 * — the Venues admin screens haven't been built yet, only enough fields to
 * render/pick a venue from the matches feature.
 */
export interface MatchVenue {
  id: string
  organizationId: string
  name: string
  location: string | null
  capacity: number | null
  pitchType: string | null
  facilities: string | null
  photoUrl: string | null
  status: 'active' | 'inactive'
  createdAt: string
}

/**
 * Minimal shape of an `officials` row nested on a match response
 * (`umpireOfficial`/`scorerOfficial`/`matchRefereeOfficial` — see
 * MatchesService.RESPONSE_RELATIONS). Same "duplicate a few fields, don't
 * import the not-yet-built feature" pattern as `MatchVenue` above.
 */
export interface MatchOfficial {
  id: string
  organizationId: string
  fullName: string
  role: OfficialRole
  phone: string | null
  email: string | null
  photoUrl: string | null
  status: 'active' | 'inactive'
  createdAt: string
}

/**
 * Mirrors `MatchesService.MatchResponse` (apps/backend/src/modules/matches/matches.service.ts)
 * exactly — every `Match` entity column EXCEPT the `homeTournamentTeam`/
 * `awayTournamentTeam`/`winnerTournamentTeam`/`tournament`/`createdByUser`
 * relations (stripped server-side), plus the resolved `homeTeamName`/
 * `awayTeamName`/`winnerTeamName` strings and the resolved
 * `venue`/`umpireOfficial`/`scorerOfficial`/`matchRefereeOfficial` nested
 * objects.
 *
 * Dual-field approach (see match.entity.ts's doc comment, ported verbatim):
 * `venueName`/`umpireName`/`scorerName` are legacy free-text columns that
 * are NEVER cleared by setting the corresponding FK, and vice versa — a
 * match may have either, both, or neither populated for a given
 * venue/official. Any surface rendering a match should prefer the resolved
 * nested object's name when present and fall back to the legacy string,
 * rather than assuming only one is ever set.
 */
export interface Match {
  id: string
  tournamentId: string

  homeTournamentTeamId: string | null
  awayTournamentTeamId: string | null

  /** ISO datetime string, or null (TBD). */
  scheduledAt: string | null

  venueName: string | null
  umpireName: string | null
  scorerName: string | null

  venueId: string | null
  venue: MatchVenue | null
  umpireOfficialId: string | null
  umpireOfficial: MatchOfficial | null
  scorerOfficialId: string | null
  scorerOfficial: MatchOfficial | null
  matchRefereeOfficialId: string | null
  matchRefereeOfficial: MatchOfficial | null

  status: MatchStatus

  /** Reserved for the live-scoring feature (Phase 2) — the matches module
   * never populates these itself, but a match may carry them once scoring
   * has run. Rendered when present, never fabricated when absent. */
  resultSummary: string | null
  winnerTournamentTeamId: string | null
  oversLimit: number | null

  createdByUserId: string
  createdAt: string

  homeTeamName: string | null
  awayTeamName: string | null
  winnerTeamName: string | null
}

/** Mirrors CreateMatchDto exactly — every field optional, per the backend's
 * "Create match" vs. "Assign teams"/"Assign venue"/etc. distinction (a bare
 * POST {} is a valid TBD-vs-TBD fixture). */
export interface CreateMatchPayload {
  homeTournamentTeamId?: string
  awayTournamentTeamId?: string
  /** ISO datetime string. */
  scheduledAt?: string
  venueName?: string
  umpireName?: string
  scorerName?: string
  venueId?: string
  umpireOfficialId?: string
  scorerOfficialId?: string
  matchRefereeOfficialId?: string
}

/** Mirrors UpdateMatchDto — PartialType(CreateMatchDto) plus an optional
 * status transition (`{ status: 'cancelled' }` is the soft "Cancel match" action). */
export type UpdateMatchPayload = CreateMatchPayload & {
  status?: MatchStatus
}

/** Query params MatchesController.findAll accepts. */
export interface MatchListFilters {
  status?: MatchStatus
  /** ISO date/time, inclusive lower bound on scheduledAt. */
  from?: string
  /** ISO date/time, inclusive upper bound on scheduledAt. */
  to?: string
}

/**
 * A tournament's registered team, as returned by the public
 * `GET /public/organizations/:organizationId/tournaments/:tournamentId/teams`
 * endpoint (see public-tournaments.controller.ts) — name/logo only, no
 * purse/financial data, withdrawn teams excluded. There is no authenticated
 * equivalent endpoint for listing a tournament's registered teams, so the
 * match form's home/away team pickers read from this public one instead
 * (org-scoped by the URL either way; safe to call with an admin's bearer
 * token attached even though the endpoint itself doesn't require one).
 */
export interface TournamentTeamOption {
  tournamentTeamId: string
  teamId: string
  name: string
  shortCode: string | null
  logoUrl: string | null
}
