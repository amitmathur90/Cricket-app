import type { Player } from './player'
import type { Team, TournamentTeam } from './team'

/** Mirrors AuctionSessionStatus in auction-session.entity.ts. */
export type AuctionSessionStatus = 'scheduled' | 'live' | 'paused' | 'completed'

export const AUCTION_SESSION_STATUS_LABELS: Record<AuctionSessionStatus, string> = {
  scheduled: 'Scheduled',
  live: 'Live',
  paused: 'Paused',
  completed: 'Completed',
}

/**
 * One tier of a tiered bid-increment schedule — mirrors `BidIncrementRule`
 * in auction-session.entity.ts. While the current bid is below `upTo`,
 * `increment` is the minimum step for the next bid; `upTo: null` marks the
 * catch-all top tier (should be the last entry in the array).
 */
export interface BidIncrementRule {
  upTo: number | null
  increment: number
}

/**
 * Mirrors apps/backend/src/database/entities/auction-session.entity.ts
 * (every column) — the shape returned by every plain REST auction-session
 * endpoint (create/list/get). Decimal columns (`defaultTeamPoints`,
 * `currentBidAmount`) come back as strings, same convention as
 * TournamentTeam's purse fields. There is deliberately no auto-timer
 * anywhere server-side — `currentLotEndsAt` is a legacy column, always null
 * going forward; nothing in this app reads it as a deadline.
 */
export interface AuctionSession {
  id: string
  tournamentId: string
  name: string
  status: AuctionSessionStatus
  currentPlayerId: string | null
  currentBidAmount: string | null
  currentBidTeamId: string | null
  bidIncrementRules: BidIncrementRule[] | null
  currentLotEndsAt: string | null
  /** Informational total time budget for the whole session, in minutes —
   * never enforced server-side. */
  durationMinutes: number | null
  defaultTeamPoints: string | null
  maxSquadSize: number | null
  startedAt: string | null
  endedAt: string | null
  createdAt: string
}

/** Mirrors CreateAuctionSessionDto exactly — request body for POST .../auction-sessions. */
export interface CreateAuctionSessionPayload {
  name: string
  bidIncrementRules?: BidIncrementRule[]
  durationMinutes?: number
  /** Starting purse applied to every registered team when the session starts. */
  defaultTeamPoints?: number
  maxSquadSize?: number
}

/** Mirrors AuctionPoolStatus in auction-player-pool.entity.ts. */
export type AuctionPoolStatus = 'pending' | 'in_progress' | 'sold' | 'unsold'

export const AUCTION_POOL_STATUS_LABELS: Record<AuctionPoolStatus, string> = {
  pending: 'Pending',
  in_progress: 'In progress',
  sold: 'Sold',
  unsold: 'Unsold',
}

/** Minimal player shape embedded on a live-state `currentLot`/`playerUp`
 * payload — AuctionRealtimeService selects exactly these four fields off
 * the full Player record for those (see buildStateSyncPayload/
 * advanceToNextLot in auction-realtime.service.ts), rather than the whole
 * entity. */
export interface AuctionLotPlayer {
  id: string
  fullName: string
  role: string
  photoUrl: string | null
}

/** A tournament-team as embedded on a pool entry's `soldToTeam` / a bid's
 * `team` relation — TournamentTeam with its `team` (org-level brand)
 * relation eager-loaded, mirroring AuctionService's `relations: [...,
 * 'soldToTeam.team']` / `['team', 'team.team']` loads. */
export type AuctionRelatedTeam = TournamentTeam & { team: Team }

/**
 * Mirrors apps/backend/src/database/entities/auction-player-pool.entity.ts,
 * as returned by GET .../auction-sessions/:sessionId/pool (`player`,
 * `soldToTeam`, `soldToTeam.team` relations eager-loaded — the full Player
 * record, not the minimal AuctionLotPlayer shape used elsewhere).
 */
export interface AuctionPlayerPoolEntry {
  id: string
  auctionSessionId: string
  playerId: string
  player: Player
  basePrice: string
  status: AuctionPoolStatus
  finalPrice: string | null
  soldToTeamId: string | null
  soldToTeam: AuctionRelatedTeam | null
  lotOrder: number
}

/** Mirrors AddPoolEntryDto — one row of a bulk pool-add request. */
export interface AddToPoolEntry {
  playerId: string
  basePrice: number
  lotOrder: number
}

/** Mirrors AddToPoolDto — request body for POST .../auction-sessions/:sessionId/pool. */
export interface AddToPoolPayload {
  entries: AddToPoolEntry[]
}

/**
 * Mirrors apps/backend/src/database/entities/auction-bid.entity.ts, as
 * returned by GET .../auction-sessions/:sessionId/bids (`team`, `team.team`
 * relations eager-loaded). A voided (undone) bid is kept, not deleted — see
 * the entity's doc comment — so `voided`/`voidedAt` must be checked by any
 * UI rendering bid history.
 */
export interface AuctionBid {
  id: string
  auctionSessionId: string
  auctionPlayerPoolId: string
  teamId: string
  team: AuctionRelatedTeam
  bidAmount: string
  bidSequence: number
  voided: boolean
  voidedAt: string | null
  createdAt: string
}

// ---------------------------------------------------------------------
// Real-time state — mirrors AuctionRealtimeService.buildStateSyncPayload
// exactly. This is NOT the same shape as `AuctionSession` above: it's the
// richer, room-broadcast/join snapshot (current lot with resolved player
// info, per-team purse/squad status), pushed over the `/auction` socket
// namespace's `auction.stateSync` event (on join, pause, resume, and
// session completion) and kept fresh between those full pushes by patching
// from the other broadcast event types — see
// features/auction/hooks/useAuctionSocket.ts for exactly how.
// ---------------------------------------------------------------------

export interface AuctionCurrentLot {
  poolEntryId: string
  player: AuctionLotPlayer
  basePrice: string
  currentBidAmount: string | null
  currentBidTeamId: string | null
  /** True once the admin has marked this lot SOLD/UNSOLD — the UI should
   * show the resolved/"Next Player" state rather than bidding controls. */
  resolved: boolean
}

export interface AuctionStateTeam {
  tournamentTeamId: string
  teamName: string
  purseTotal: string | null
  purseRemaining: string | null
  squadFull: boolean
}

export interface AuctionStateSync {
  session: {
    id: string
    name: string
    status: AuctionSessionStatus
    tournamentId: string
    durationMinutes: number | null
    maxSquadSize: number | null
    /** Combined with durationMinutes, lets a client compute an overall
     * "auction time remaining" countdown (startedAt + durationMinutes) —
     * see useAuctionTimeRemaining. Purely informational; nothing
     * server-side enforces it. Null until the session is started. */
    startedAt: string | null
  }
  currentLot: AuctionCurrentLot | null
  remainingPoolCount: number
  teams: AuctionStateTeam[]
}

// ---------------------------------------------------------------------
// Socket broadcast payloads — mirror the inline `broadcastPayload`/
// `event.payload` object literals built in auction-realtime.service.ts for
// each event type (there are no DTO classes for these server-side; shapes
// are inferred directly from that file, not guessed).
// ---------------------------------------------------------------------

/** auction.playerUp — sent on session start and on next-lot when a next lot exists. */
export interface AuctionPlayerUpEvent {
  poolEntryId: string
  player: AuctionLotPlayer
  basePrice: string
}

/** auction.bidPlaced */
export interface AuctionBidPlacedEvent {
  auctionSessionId: string
  poolEntryId: string
  teamId: string
  teamName: string
  amount: string
  bidSequence: number
}

/** auction.bidUndone */
export interface AuctionBidUndoneEvent {
  auctionSessionId: string
  poolEntryId: string
  undoneBid: { teamId: string; amount: string; bidSequence: number }
  currentBidAmount: string | null
  currentBidTeamId: string | null
  currentBidTeamName: string | null
  currentLotEndsAt: string | null
}

/** auction.playerSold */
export interface AuctionPlayerSoldEvent {
  playerId: string
  poolEntryId: string
  finalPrice: string
  soldToTeamId: string
  soldToTeamName: string | null
  purseRemaining: string
}

/** auction.playerUnsold */
export interface AuctionPlayerUnsoldEvent {
  playerId: string
  poolEntryId: string
}

/** Payload the gateway sends back to just the requesting socket on any
 * failed `auction.join`/`auction.placeBid` — never broadcast to the room. */
export interface AuctionErrorEvent {
  message: string
}

// ---------------------------------------------------------------------
// Report — mirrors AuctionService.getReport's return shape exactly (an
// inline object, no DTO class server-side either).
// ---------------------------------------------------------------------

export interface AuctionReportTeamSummary {
  tournamentTeamId: string
  teamName: string
  purseTotal: string | null
  purseRemaining: string | null
  playersBought: number
  totalSpent: string
}

export interface AuctionReportPlayerOutcome {
  playerId: string
  playerName: string
  status: AuctionPoolStatus
  basePrice: string
  finalPrice: string | null
  soldToTeamId: string | null
  soldToTeamName: string | null
}

export interface AuctionReport {
  session: {
    id: string
    name: string
    status: AuctionSessionStatus
    startedAt: string | null
    endedAt: string | null
  }
  teams: AuctionReportTeamSummary[]
  players: AuctionReportPlayerOutcome[]
}
