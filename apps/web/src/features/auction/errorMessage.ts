import axios from 'axios'

/** Extracts a clean, server-provided error message from a failed auction API
 * call. Plain `err.message` on an AxiosError is a generic "Request failed
 * with status code 400" — Nest's real validation/business message (e.g.
 * "SQUAD FULL — this team has reached its maximum roster size", "Bid must
 * be at least 1050.00", "Mark the current lot SOLD or UNSOLD before
 * advancing") lives at `err.response.data.message`, which class-validator
 * can also return as a string array. Kept local to this feature (no shared
 * helper exists yet elsewhere — other features just do
 * `err instanceof Error ? err.message : ...`) because the auction UX
 * specifically depends on surfacing the real reason a bid/action was
 * rejected, not a generic status-code string. */
export function auctionErrorMessage(err: unknown): string {
  if (axios.isAxiosError(err)) {
    const data = err.response?.data as { message?: string | string[] } | undefined
    if (Array.isArray(data?.message)) return data.message.join(', ')
    if (typeof data?.message === 'string') return data.message
  }
  return err instanceof Error ? err.message : 'Something went wrong'
}
