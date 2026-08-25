/**
 * Lets core/api/client.ts read/write the current access token without
 * importing core/auth/authStore.ts directly (authStore transitively
 * imports client.ts via features/auth/api, so a direct import would be
 * circular). authStore registers itself here once, at module init.
 */
interface AuthBridge {
  getAccessToken: () => string | null
  setAccessToken: (token: string) => void
}

let bridge: AuthBridge = {
  getAccessToken: () => null,
  setAccessToken: () => {},
}

export function registerAuthBridge(next: AuthBridge): void {
  bridge = next
}

export function getAccessToken(): string | null {
  return bridge.getAccessToken()
}

export function setAccessToken(token: string): void {
  bridge.setAccessToken(token)
}
