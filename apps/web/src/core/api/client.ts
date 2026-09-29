import axios, { AxiosError, type InternalAxiosRequestConfig } from 'axios'
import { getAccessToken, setAccessToken } from './authBridge'
import { tokenStorage } from '../auth/tokenStorage'
import { emitSessionExpired } from '../auth/sessionEvents'

/** Same base URL for real requests and the Vite dev proxy — relative in dev
 * (proxied to localhost:3000 per vite.config.ts), overridable for a
 * deployed backend via VITE_API_BASE_URL. */
const baseURL = import.meta.env.VITE_API_BASE_URL ?? ''

/** Paths that must NOT get an Authorization header and must NOT trigger the
 * 401-refresh-and-retry flow — doing either would recurse into
 * /auth/refresh itself. Mirrors apps/mobile/lib/core/network/api_client.dart.
 * Note `/auth/select-org` is deliberately excluded: it requires a bearer
 * token (see auth.controller.ts), so it goes through the normal path. */
const UNAUTHENTICATED_PATHS = ['/auth/login', '/auth/register', '/auth/refresh']

function isUnauthenticatedPath(path: string | undefined): boolean {
  if (!path) return false
  return UNAUTHENTICATED_PATHS.some((p) => path.startsWith(p))
}

export const apiClient = axios.create({
  baseURL,
  timeout: 15_000,
  headers: { 'Content-Type': 'application/json' },
})

apiClient.interceptors.request.use((config) => {
  if (!isUnauthenticatedPath(config.url)) {
    const token = getAccessToken()
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
  }
  return config
})

interface RetriableConfig extends InternalAxiosRequestConfig {
  _ammctRetried?: boolean
  _ammctTimeoutRetried?: boolean
}

/** Render's free tier sleeps the backend after inactivity; the first
 * request after that can take 50-90s to wake it, well past the normal
 * 15s timeout — that showed up as a hard "timeout of 15000ms exceeded"
 * error on login with no way to recover except manually retrying. Instead,
 * a request that times out gets ONE automatic retry with a much longer
 * timeout, so a cold start resolves itself instead of surfacing as a
 * failure. A second timeout (genuinely unreachable backend) still fails
 * normally rather than hanging forever. */
const COLD_START_RETRY_TIMEOUT_MS = 90_000

let refreshInFlight: Promise<string | null> | null = null

/** POSTs /auth/refresh on a bare axios instance (must not go through the
 * interceptors above, which would try to attach an access token or
 * re-trigger this same refresh) and de-duplicates concurrent callers
 * (several requests failing with 401 at once) behind one in-flight promise. */
function refreshAccessToken(): Promise<string | null> {
  if (refreshInFlight) return refreshInFlight

  refreshInFlight = (async () => {
    try {
      const refreshToken = tokenStorage.readRefreshToken()
      if (!refreshToken) return null

      const plain = axios.create({ baseURL })
      const response = await plain.post<{ accessToken: string; refreshToken: string }>(
        '/auth/refresh',
        { refreshToken },
      )
      const { accessToken, refreshToken: newRefreshToken } = response.data
      tokenStorage.saveRefreshToken(newRefreshToken)
      setAccessToken(accessToken)
      return accessToken
    } catch {
      tokenStorage.clear()
      return null
    } finally {
      refreshInFlight = null
    }
  })()

  return refreshInFlight
}

apiClient.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const config = error.config as RetriableConfig | undefined

    const isTimeout = error.code === 'ECONNABORTED' && /timeout/i.test(error.message)
    if (isTimeout && config != null && !config._ammctTimeoutRetried) {
      config._ammctTimeoutRetried = true
      config.timeout = COLD_START_RETRY_TIMEOUT_MS
      return apiClient.request(config)
    }

    const shouldAttemptRefresh =
      error.response?.status === 401 &&
      config != null &&
      !isUnauthenticatedPath(config.url) &&
      !config._ammctRetried

    if (!shouldAttemptRefresh) {
      return Promise.reject(error)
    }

    const newAccessToken = await refreshAccessToken()
    if (!newAccessToken) {
      emitSessionExpired()
      return Promise.reject(error)
    }

    config._ammctRetried = true
    config.headers.Authorization = `Bearer ${newAccessToken}`
    return apiClient.request(config)
  },
)

export { refreshAccessToken }

/** Fires a lightweight, unauthenticated request the moment the app loads —
 * purely to start waking up a sleeping Render backend as early as possible
 * (see COLD_START_RETRY_TIMEOUT_MS's doc comment), so by the time someone
 * finishes typing their email/password the backend is often already awake
 * and the real login request lands fast instead of needing the timeout
 * retry at all. Errors are deliberately ignored — this is a best-effort
 * head start, not a request anything waits on. */
export function warmUpBackend(): void {
  const plain = axios.create({ baseURL, timeout: COLD_START_RETRY_TIMEOUT_MS })
  plain.get('/').catch(() => undefined)
}

/** Multipart upload helper — axios sets its own multipart boundary from
 * FormData automatically, but the shared instance's default JSON
 * Content-Type header must be cleared for this one request. */
export function uploadFile(path: string, formData: FormData) {
  return apiClient.post(path, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
}

/** The uploads endpoint returns a relative URL (e.g.
 * "/uploads/{orgId}/{filename}"), served by the same backend origin. In dev
 * this resolves against the Vite proxy; in a production build with a
 * separately-hosted API, VITE_API_BASE_URL supplies the origin to prefix. */
export function resolveMediaUrl(relativeUrl: string): string {
  if (/^https?:\/\//.test(relativeUrl)) return relativeUrl
  return `${baseURL}${relativeUrl}`
}
