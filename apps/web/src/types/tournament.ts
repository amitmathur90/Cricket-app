/** Mirrors apps/backend/src/database/entities/tournament.entity.ts's TournamentFormat enum. */
export type TournamentFormat = 't20' | 'odi' | 't10' | 'custom'

export const TOURNAMENT_FORMATS: { value: TournamentFormat; label: string }[] = [
  { value: 't20', label: 'T20' },
  { value: 'odi', label: 'ODI' },
  { value: 't10', label: 'T10' },
  { value: 'custom', label: 'Custom' },
]

/** Mirrors apps/backend/src/database/entities/tournament.entity.ts's TournamentStatus enum. */
export type TournamentStatus = 'draft' | 'upcoming' | 'live' | 'completed'

/** Computed at response time by TournamentsService.computeRegistrationStatus — never persisted. */
export type RegistrationStatus = 'not_open' | 'open' | 'closed'

export const REGISTRATION_STATUS_LABELS: Record<RegistrationStatus, string> = {
  not_open: 'Not open',
  open: 'Open',
  closed: 'Closed',
}

/**
 * Mirrors apps/backend/src/database/entities/tournament.entity.ts (every
 * column) plus the `teamsCount`/`registrationStatus` fields computed at
 * response time by TournamentsService.toResponse (see TournamentResponse
 * there) — present on every API response, never persisted. Decimal columns
 * (`playerRegistrationFee`/`teamRegistrationFee`) come back as strings, same
 * as the Dart model — Postgres `decimal` columns serialize as strings to
 * avoid float precision loss.
 */
export interface Tournament {
  id: string
  organizationId: string
  name: string
  format: TournamentFormat
  /** ISO date string (YYYY-MM-DD). */
  startDate: string
  /** ISO date string (YYYY-MM-DD). */
  endDate: string
  status: TournamentStatus
  auctionEnabled: boolean

  /** Computed — number of TournamentTeam rows registered, not a DB column. */
  teamsCount: number
  /** Computed from registrationOpensAt/registrationClosesAt vs. now, not a DB column. */
  registrationStatus: RegistrationStatus

  // --- Basic info ---
  logoUrl: string | null
  description: string | null
  organizerName: string | null
  contactEmail: string | null
  contactPhone: string | null

  // --- Tournament details ---
  location: string | null
  numberOfTeams: number | null
  maxPlayersPerTeam: number | null

  // --- Rules ---
  tournamentRules: string | null
  matchRules: string | null
  /** Free-text points system description, e.g. "2 pts win, 1 pt tie". */
  pointsSystem: string | null
  tieBreakerRules: string | null

  // --- Registration ---
  /** ISO date string (YYYY-MM-DD), or null. */
  registrationOpensAt: string | null
  /** ISO date string (YYYY-MM-DD), or null. */
  registrationClosesAt: string | null
  playerRegistrationFee: string | null
  teamRegistrationFee: string | null

  createdByUserId: string
  createdAt: string
}

/** Mirrors CreateTournamentDto exactly — request body for POST .../tournaments. */
export interface CreateTournamentPayload {
  name: string
  format: TournamentFormat
  startDate: string
  endDate: string
  auctionEnabled?: boolean
  logoUrl?: string
  description?: string
  organizerName?: string
  contactEmail?: string
  contactPhone?: string
  location?: string
  numberOfTeams?: number
  maxPlayersPerTeam?: number
  tournamentRules?: string
  matchRules?: string
  pointsSystem?: string
  tieBreakerRules?: string
  registrationOpensAt?: string
  registrationClosesAt?: string
  playerRegistrationFee?: number
  teamRegistrationFee?: number
}

/** Mirrors UpdateTournamentDto — PartialType(CreateTournamentDto) plus an optional status transition. */
export type UpdateTournamentPayload = Partial<CreateTournamentPayload> & {
  status?: TournamentStatus
}

/** Mirrors TournamentsService.PointsTableRow — one row of the computed (never persisted) standings table. */
export interface PointsTableRow {
  tournamentTeamId: string
  teamName: string
  position: number
  played: number
  won: number
  lost: number
  tied: number
  noResult: number
  points: number
  netRunRate: number
}

/** Mirrors apps/backend/src/database/entities/tournament-application.entity.ts's TournamentApplicationStatus enum. */
export type TournamentApplicationStatus = 'pending' | 'approved' | 'rejected'

export const APPLICATION_STATUS_LABELS: Record<TournamentApplicationStatus, string> = {
  pending: 'Pending',
  approved: 'Approved',
  rejected: 'Rejected',
}

/**
 * Minimal shape of the `player` relation embedded on a TournamentApplication
 * (see PlayersService/player.entity.ts) — only the fields this tab actually
 * displays. The full Player type lands with the Players feature; duplicating
 * a handful of fields here rather than importing a not-yet-built module.
 */
export interface ApplicationPlayer {
  id: string
  fullName: string
  role: 'batsman' | 'bowler' | 'all_rounder' | 'wicketkeeper'
  photoUrl: string | null
  ageCategory: string | null
}

/**
 * Mirrors apps/backend/src/database/entities/tournament-application.entity.ts.
 * `player` is populated on GET .../tournaments/:id/applications (the admin
 * list this tab uses — see TournamentApplicationsService.findAllForTournament,
 * which loads the `player` relation).
 */
export interface TournamentApplication {
  id: string
  tournamentId: string
  userId: string
  playerId: string | null
  status: TournamentApplicationStatus
  reviewNote: string | null
  reviewedByUserId: string | null
  createdAt: string
  reviewedAt: string | null
  player: ApplicationPlayer | null
}

/** Mirrors ReviewTournamentApplicationDto — status must be 'approved' or 'rejected'. */
export interface ReviewApplicationPayload {
  status: 'approved' | 'rejected'
  note?: string
}

/** Mirrors TournamentsService.AwardResult — `winner` is null (with a
 * `reasoning` string explaining why) when the award genuinely can't be
 * determined yet, e.g. no completed matches. Never fabricate a winner when
 * this is null. */
export interface AwardResult {
  winner: {
    playerId: string
    playerName: string
    teamName: string
    /** Human-readable stat line backing this award, e.g. "312 runs, 9 wkts (composite 492)". */
    value: string
  } | null
  reasoning: string
}

/** Mirrors TournamentsService.TournamentAwardsResponse. */
export interface TournamentAwardsResponse {
  playerOfTheTournament: AwardResult
  manOfTheMatch: { reasoning: string; matches: unknown[] }
  bestBatsman: AwardResult
  bestBowler: AwardResult
  bestFielder: AwardResult
  bestAllRounder: AwardResult
  emergingPlayer: AwardResult
  bestCaptain: AwardResult
}
