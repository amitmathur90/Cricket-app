import { apiClient } from '../../../core/api/client'
import type {
  AddToPoolPayload,
  AuctionBid,
  AuctionPlayerPoolEntry,
  AuctionReport,
  AuctionSession,
  CreateAuctionSessionPayload,
} from '../../../types/auction'

function base(organizationId: string, tournamentId: string): string {
  return `/organizations/${organizationId}/tournaments/${tournamentId}/auction-sessions`
}

/** Wraps every endpoint on apps/backend/src/modules/auction/auction.controller.ts
 * under the `organizations/:organizationId/tournaments/:tournamentId/auction-sessions`
 * prefix. Note several of these (findOne/pool/start/pause/.../report) don't
 * actually use `tournamentId` server-side — it's still required in the URL
 * because it's part of the controller's route prefix, not because the
 * handler reads it. */
export const auctionApi = {
  async create(organizationId: string, tournamentId: string, payload: CreateAuctionSessionPayload): Promise<AuctionSession> {
    const { data } = await apiClient.post<AuctionSession>(base(organizationId, tournamentId), payload)
    return data
  },

  async list(organizationId: string, tournamentId: string): Promise<AuctionSession[]> {
    const { data } = await apiClient.get<AuctionSession[]>(base(organizationId, tournamentId))
    return data
  },

  async get(organizationId: string, tournamentId: string, sessionId: string): Promise<AuctionSession> {
    const { data } = await apiClient.get<AuctionSession>(`${base(organizationId, tournamentId)}/${sessionId}`)
    return data
  },

  async addToPool(
    organizationId: string,
    tournamentId: string,
    sessionId: string,
    payload: AddToPoolPayload,
  ): Promise<AuctionPlayerPoolEntry[]> {
    const { data } = await apiClient.post<AuctionPlayerPoolEntry[]>(
      `${base(organizationId, tournamentId)}/${sessionId}/pool`,
      payload,
    )
    return data
  },

  async listPool(organizationId: string, tournamentId: string, sessionId: string): Promise<AuctionPlayerPoolEntry[]> {
    const { data } = await apiClient.get<AuctionPlayerPoolEntry[]>(`${base(organizationId, tournamentId)}/${sessionId}/pool`)
    return data
  },

  async start(organizationId: string, tournamentId: string, sessionId: string): Promise<AuctionSession> {
    const { data } = await apiClient.post<AuctionSession>(`${base(organizationId, tournamentId)}/${sessionId}/start`)
    return data
  },

  async pause(organizationId: string, tournamentId: string, sessionId: string): Promise<AuctionSession> {
    const { data } = await apiClient.post<AuctionSession>(`${base(organizationId, tournamentId)}/${sessionId}/pause`)
    return data
  },

  async resume(organizationId: string, tournamentId: string, sessionId: string): Promise<AuctionSession> {
    const { data } = await apiClient.post<AuctionSession>(`${base(organizationId, tournamentId)}/${sessionId}/resume`)
    return data
  },

  async markSold(organizationId: string, tournamentId: string, sessionId: string): Promise<AuctionSession> {
    const { data } = await apiClient.post<AuctionSession>(`${base(organizationId, tournamentId)}/${sessionId}/mark-sold`)
    return data
  },

  async markUnsold(organizationId: string, tournamentId: string, sessionId: string): Promise<AuctionSession> {
    const { data } = await apiClient.post<AuctionSession>(`${base(organizationId, tournamentId)}/${sessionId}/mark-unsold`)
    return data
  },

  async nextLot(organizationId: string, tournamentId: string, sessionId: string): Promise<AuctionSession> {
    const { data } = await apiClient.post<AuctionSession>(`${base(organizationId, tournamentId)}/${sessionId}/next-lot`)
    return data
  },

  async undoLastBid(organizationId: string, tournamentId: string, sessionId: string): Promise<AuctionSession> {
    const { data } = await apiClient.post<AuctionSession>(`${base(organizationId, tournamentId)}/${sessionId}/undo-last-bid`)
    return data
  },

  async listBids(organizationId: string, tournamentId: string, sessionId: string, playerId?: string): Promise<AuctionBid[]> {
    const query = playerId ? `?playerId=${encodeURIComponent(playerId)}` : ''
    const { data } = await apiClient.get<AuctionBid[]>(`${base(organizationId, tournamentId)}/${sessionId}/bids${query}`)
    return data
  },

  async getReport(organizationId: string, tournamentId: string, sessionId: string): Promise<AuctionReport> {
    const { data } = await apiClient.get<AuctionReport>(`${base(organizationId, tournamentId)}/${sessionId}/report`)
    return data
  },
}

/** Shared shape of the seven session-id-only lifecycle actions
 * (start/pause/resume/mark-sold/mark-unsold/next-lot/undo-last-bid) — lets
 * hooks/useAuctionLifecycle.ts write one generic mutation-hook factory
 * instead of seven near-identical ones. */
export type AuctionLifecycleAction = (
  organizationId: string,
  tournamentId: string,
  sessionId: string,
) => Promise<AuctionSession>
