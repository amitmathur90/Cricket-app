/** Mirrors PlayerRole in apps/backend/src/database/entities/player.entity.ts. */
export type PlayerRole = 'batsman' | 'bowler' | 'all_rounder' | 'wicketkeeper'

export const PLAYER_ROLES: { value: PlayerRole; label: string }[] = [
  { value: 'batsman', label: 'Batsman' },
  { value: 'bowler', label: 'Bowler' },
  { value: 'all_rounder', label: 'All-rounder' },
  { value: 'wicketkeeper', label: 'Wicketkeeper' },
]

/** Mirrors PlayerStatus in player.entity.ts. */
export type PlayerStatus = 'active' | 'inactive'

/**
 * 4-stage verification flow. Mirrors PlayerVerificationStatus in
 * player.entity.ts. Legal transitions (enforced server-side in
 * PlayersService.ALLOWED_VERIFICATION_TRANSITIONS — see that file's exact
 * doc comment, mirrored here):
 *   pending  -> verified or rejected
 *   verified -> approved or rejected
 *   approved -> (terminal)
 *   rejected -> (terminal)
 * pending is never a valid transition *target*, only the initial default.
 */
export type PlayerVerificationStatus = 'pending' | 'verified' | 'approved' | 'rejected'

export const PLAYER_VERIFICATION_STATUS_LABELS: Record<PlayerVerificationStatus, string> = {
  pending: 'Pending',
  verified: 'Verified',
  approved: 'Approved',
  rejected: 'Rejected',
}

/** The only legal next verification statuses from a given current status —
 * mirrors PlayersService.ALLOWED_VERIFICATION_TRANSITIONS exactly, so the
 * review UI never offers (and the server would reject anyway) an illegal
 * transition. */
export const ALLOWED_VERIFICATION_TRANSITIONS: Record<PlayerVerificationStatus, PlayerVerificationStatus[]> = {
  pending: ['verified', 'rejected'],
  verified: ['approved', 'rejected'],
  approved: [],
  rejected: [],
}

/**
 * Mirrors apps/backend/src/database/entities/player.entity.ts (every
 * column) — an org-level player profile. `userId` is nullable because many
 * players (esp. amateur/local tournaments) won't have their own login
 * account. Decimal columns (`rating`/`basePrice`) come back as strings, same
 * as the Dart model — Postgres `decimal` columns serialize as strings to
 * avoid float precision loss.
 */
export interface Player {
  id: string
  organizationId: string
  userId: string | null
  fullName: string
  /** ISO date string (YYYY-MM-DD), or null — often unpopulated (optional at registration). */
  dob: string | null

  // --- Personal information (free-text, deliberately not enums — see entity doc) ---
  gender: string | null
  phone: string | null
  email: string | null
  address: string | null

  role: PlayerRole
  battingStyle: string | null
  bowlingStyle: string | null
  /** Free-text experience description (e.g. "5 years club cricket"). */
  experience: string | null
  /** Preferred batting order slot or fielding position — free text. */
  preferredPosition: string | null

  photoUrl: string | null
  idDocumentUrl: string | null
  addressProofUrl: string | null
  otherDocumentUrls: string[] | null

  ageCategory: string | null
  /** Free-text prior teams/tournaments/statistics summary. */
  previousStatsNotes: string | null

  /** @deprecated Superseded by isAvailableFor{Tournaments,Matches,Practice} below — kept because it's still a real, live column some UI reads/writes. */
  isAvailable: boolean
  /** @deprecated See isAvailable. */
  unavailabilityReason: string | null

  isAvailableForTournaments: boolean
  isAvailableForMatches: boolean
  isAvailableForPractice: boolean

  verificationStatus: PlayerVerificationStatus
  verificationNote: string | null

  /** Decimal-as-string (0.00-5.00), or null if never rated. */
  rating: string | null
  /** Decimal-as-string, or null. */
  basePrice: string | null

  status: PlayerStatus
  createdAt: string
}

/** Mirrors CreatePlayerDto exactly — request body for POST .../players. */
export interface CreatePlayerPayload {
  fullName: string
  role: PlayerRole
  /** URL of an uploaded photo (see POST .../uploads) — required by the DTO. */
  photoUrl: string
  /** URL of an uploaded ID document — required by the DTO. */
  idDocumentUrl: string
  ageCategory: string
  previousStatsNotes: string
  userId?: string
  dob?: string
  gender?: string
  phone?: string
  email?: string
  address?: string
  battingStyle?: string
  bowlingStyle?: string
  experience?: string
  preferredPosition?: string
  addressProofUrl?: string
  otherDocumentUrls?: string[]
  basePrice?: number
}

/** Mirrors UpdatePlayerDto — PartialType(CreatePlayerDto) plus the legacy
 * isAvailable pair and the granular isAvailableFor* flags (update-only, not
 * part of CreatePlayerDto). */
export type UpdatePlayerPayload = Partial<CreatePlayerPayload> & {
  isAvailable?: boolean
  unavailabilityReason?: string
  isAvailableForTournaments?: boolean
  isAvailableForMatches?: boolean
  isAvailableForPractice?: boolean
}

/** Mirrors VerifyPlayerDto — status must be verified/approved/rejected, never 'pending'. */
export interface VerifyPlayerPayload {
  status: 'verified' | 'approved' | 'rejected'
  note?: string
}

/** Mirrors RatePlayerDto. */
export interface RatePlayerPayload {
  /** 0-5. */
  rating: number
}

/** Mirrors team-player.entity.ts's AcquisitionType enum. */
export type AcquisitionType = 'auction' | 'direct_signing' | 'retained'

/** Mirrors AddToRosterDto — request body for POST .../players/:playerId/tournament-teams/:tournamentTeamId/roster. */
export interface AddToRosterPayload {
  jerseyNumber?: number
  isCaptain?: boolean
  isWicketkeeper?: boolean
  acquisitionType?: AcquisitionType
  acquiredPrice?: number
}

// ---------------------------------------------------------------------
// Statistics — mirrors PlayersService's response interfaces
// (apps/backend/src/modules/players/players.service.ts) exactly. Computed
// on read from the ball-by-ball log, never persisted — see that file's
// getStatistics doc comment for the full aggregation methodology.
// ---------------------------------------------------------------------

/** Mirrors ball.entity.ts's DismissalType enum. */
export type DismissalType = 'bowled' | 'caught' | 'lbw' | 'run_out' | 'stumped' | 'hit_wicket' | 'retired_hurt'

export interface PlayerStatisticsSummary {
  matchesPlayed: number
  totalRuns: number
  timesOut: number
  /** runs / timesOut. Null (not Infinity/NaN) when timesOut is 0. */
  battingAverage: number | null
  strikeRate: number
  totalWickets: number
  /** Null when the player has never bowled a legal ball. */
  bowlingEconomy: number | null
}

export interface PlayerBattingStats {
  innings: number
  runs: number
  ballsFaced: number
  highestScore: number
  highestScoreNotOut: boolean
  fifties: number
  hundreds: number
  fours: number
  sixes: number
  timesOut: number
  average: number | null
  strikeRate: number
}

export interface PlayerBowlingStats {
  innings: number
  /** "overs.balls" display notation (e.g. "4.3"), not a true decimal. */
  overs: string
  runsConceded: number
  wickets: number
  bestBowling: { wickets: number; runsConceded: number } | null
  average: number | null
  economy: number | null
  maidens: number
}

export interface PlayerFieldingStats {
  catches: number
  runOuts: number
  stumpings: number
}

/** One completed match the player appeared in, with their personal figures for it. */
export interface PlayerMatchHistoryEntry {
  matchId: string
  tournamentId: string
  scheduledAt: string | null
  playerTournamentTeamId: string | null
  opponentTournamentTeamId: string | null
  playerTeamName: string
  opponentTeamName: string
  resultSummary: string | null
  won: boolean | null
  batting: {
    runs: number
    ballsFaced: number
    fours: number
    sixes: number
    isOut: boolean
    dismissalType: DismissalType | null
    strikeRate: number
  } | null
  bowling: {
    overs: string
    runsConceded: number
    wickets: number
    maidens: number
    economy: number
  } | null
  fielding: PlayerFieldingStats
}

/** GET .../players/:playerId/statistics response — mirrors PlayersService.PlayerStatisticsResponse. */
export interface PlayerStatistics {
  playerId: string
  summary: PlayerStatisticsSummary
  batting: PlayerBattingStats
  bowling: PlayerBowlingStats
  fielding: PlayerFieldingStats
  /** Chronological ascending. */
  matchHistory: PlayerMatchHistoryEntry[]
}
