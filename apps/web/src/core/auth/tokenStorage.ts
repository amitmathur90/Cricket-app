/**
 * Refresh-token persistence only. The access token is never persisted here
 * — it lives in the Zustand auth store (in-memory) and is recovered on
 * bootstrap by exchanging the stored refresh token. See the auth flow
 * section of the plan for the documented XSS tradeoff of localStorage vs.
 * the httpOnly cookie the backend doesn't yet support.
 */
const REFRESH_TOKEN_KEY = 'ammct_refresh_token'

export const tokenStorage = {
  readRefreshToken(): string | null {
    try {
      return localStorage.getItem(REFRESH_TOKEN_KEY)
    } catch {
      return null
    }
  },
  saveRefreshToken(token: string): void {
    try {
      localStorage.setItem(REFRESH_TOKEN_KEY, token)
    } catch {
      // localStorage unavailable (private mode, disabled) — session simply
      // won't survive a hard refresh; not fatal.
    }
  },
  clear(): void {
    try {
      localStorage.removeItem(REFRESH_TOKEN_KEY)
    } catch {
      // ignore
    }
  },
}
