/** Decodes a JWT's payload segment without verifying the signature — the
 * server is the only party that needs to verify; the client just reads the
 * claims it was handed back (`activeOrgId`, `role`). Mirrors
 * apps/mobile/lib/core/utils/jwt.dart. */
export function decodeJwtPayload(token: string): Record<string, unknown> {
  const parts = token.split('.')
  if (parts.length !== 3) {
    throw new Error('Malformed JWT')
  }
  const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/')
  const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), '=')
  const json = atob(padded)
  return JSON.parse(json) as Record<string, unknown>
}
