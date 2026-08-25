import type { Player } from './player'

/**
 * Mirrors apps/backend/src/database/entities/team.entity.ts — an org-level
 * team "brand" (e.g. "Thunder Strikers"), reused across multiple
 * tournaments via `tournament_teams`.
 */
export interface Team {
  id: string
  organizationId: string
  name: string
  shortCode: string | null
  logoUrl: string | null
  ownerUserId: string | null
  createdAt: string
}

/** Mirrors CreateTeamDto — request body for POST .../teams. */
export interface CreateTeamPayload {
  name: string
  shortCode?: string
  logoUrl?: string
  /** User id of the team owner, if any. */
  ownerUserId?: string
}

/** Mirrors tournament-team.entity.ts's TournamentTeamStatus enum. */
export type TournamentTeamStatus = 'registered' | 'withdrawn'

/** Mirrors RegisterTeamToTournamentDto — request body for POST .../teams/:teamId/tournaments/:tournamentId/register. */
export interface RegisterTeamToTournamentPayload {
  /** Optional tournament group to place this team in. */
  groupId?: string
  /** Starting auction purse for this team in this tournament. */
  purseTotal?: number
}

/**
 * Mirrors apps/backend/src/database/entities/tournament-team.entity.ts — a
 * team's participation in one specific tournament (including its auction
 * purse for that tournament). Returned by TeamsService.registerToTournament.
 */
export interface TournamentTeam {
  id: string
  tournamentId: string
  teamId: string
  groupId: string | null
  status: TournamentTeamStatus
  purseTotal: string | null
  purseRemaining: string | null
}

/** Mirrors team-player.entity.ts's AcquisitionType enum. */
export type AcquisitionType = 'auction' | 'direct_signing' | 'retained'
/** Mirrors team-player.entity.ts's TeamPlayerStatus enum. */
export type TeamPlayerStatus = 'active' | 'released'

/**
 * Mirrors apps/backend/src/database/entities/team-player.entity.ts's
 * `TeamPlayer`, as returned by `TeamsService.getRoster`
 * (`GET .../teams/:teamId/tournaments/:tournamentId/roster`) with the
 * `player` relation eager-loaded — one row per tournament-team roster
 * membership, ordered captain-first.
 */
export interface RosterEntry {
  id: string
  tournamentTeamId: string
  playerId: string
  player: Player
  jerseyNumber: number | null
  isCaptain: boolean
  isViceCaptain: boolean
  isWicketkeeper: boolean
  acquisitionType: AcquisitionType
  acquiredPrice: string | null
  status: TeamPlayerStatus
}

/** Mirrors UpdateRosterEntryDto — request body for PATCH .../roster/:teamPlayerId.
 * Captain/vice-captain exclusivity (at most one of each per tournament-team,
 * and a player can't hold both) is enforced server-side, not here. */
export interface UpdateRosterEntryPayload {
  isCaptain?: boolean
  isViceCaptain?: boolean
  jerseyNumber?: number
  isWicketkeeper?: boolean
}
