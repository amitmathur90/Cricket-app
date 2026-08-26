import { io, type Socket } from 'socket.io-client'

/** Same base URL convention as core/api/client.ts: relative in dev (the
 * Vite proxy forwards `/socket.io` to localhost:3000 with `ws: true` — see
 * vite.config.ts), overridable for a deployed backend via
 * VITE_API_BASE_URL. */
const baseURL = import.meta.env.VITE_API_BASE_URL ?? ''

/**
 * Opens a Socket.IO connection to one namespace (e.g. '/auction'),
 * authenticated the way this backend's gateways expect: the JWT access
 * token on `socket.handshake.auth.token` (see
 * AuctionGateway.handleConnection, which verifies it manually since Nest
 * guards don't run on the WS handshake the same way REST does).
 *
 * This is a plain factory, not a shared/singleton connection — the caller
 * (a feature hook such as features/auction/hooks/useAuctionSocket.ts) owns
 * the connection's lifecycle and must call `.disconnect()` on cleanup (an
 * effect's cleanup function). A fresh call is required whenever the access
 * token rotates (e.g. after a 401 refresh triggers apiClient's silent
 * token swap) since the token is only read once, at connect time — the
 * caller's effect should depend on the token and reconnect if it changes.
 */
export function createNamespaceSocket(namespace: string, accessToken: string): Socket {
  return io(`${baseURL}${namespace}`, {
    auth: { token: accessToken },
    transports: ['websocket', 'polling'],
  })
}
