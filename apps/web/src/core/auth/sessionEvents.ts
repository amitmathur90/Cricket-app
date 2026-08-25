/**
 * Decouples core/api (which must detect an unrecoverable refresh failure)
 * from core/auth's Zustand store (which owns what happens next — clearing
 * state and routing to /login). core/api never imports the auth store
 * directly; it just emits this signal. Mirrors
 * apps/mobile/lib/core/network/network_providers.dart's
 * `sessionExpiredSignalProvider`.
 */
type Listener = () => void

const listeners = new Set<Listener>()

export function onSessionExpired(listener: Listener): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

export function emitSessionExpired(): void {
  for (const listener of listeners) listener()
}
