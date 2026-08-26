import { Link } from 'react-router-dom'
import { RoleGate } from '../../../core/router/RoleGate'
import { StatusPill } from '../../../shared/components/StatusPill'
import { resolveMediaUrl } from '../../../core/api/client'
import { useSponsors } from '../hooks/useSponsors'
import { useDeleteSponsor } from '../hooks/useDeleteSponsor'
import type { Sponsor } from '../../../types/sponsor'

/** Same "₹" + conditional-decimals formatting as
 * apps/mobile/.../sponsors_list_screen.dart's `_formatAmount` (NumberFormat.
 * currency(symbol: '₹', decimalDigits: ...)) — whole amounts show no
 * decimals, fractional amounts show 2. */
function formatAmount(amount: string): string {
  const value = Number(amount)
  if (Number.isNaN(value)) return amount
  const isWhole = value === Math.round(value)
  return `₹${value.toLocaleString('en-US', { minimumFractionDigits: isWhole ? 0 : 2, maximumFractionDigits: isWhole ? 0 : 2 })}`
}

function formatDate(date: string): string {
  const parsed = new Date(date)
  if (Number.isNaN(parsed.getTime())) return date
  return parsed.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })
}

function SponsorRow({ sponsor }: { sponsor: Sponsor }) {
  const deleteMutation = useDeleteSponsor()

  const contractRange = [
    sponsor.contractStartDate ? formatDate(sponsor.contractStartDate) : null,
    sponsor.contractEndDate ? formatDate(sponsor.contractEndDate) : null,
  ].filter(Boolean)

  const subtitleParts = [
    sponsor.packageName,
    sponsor.amount ? formatAmount(sponsor.amount) : null,
    contractRange.length > 0 ? contractRange.join(' – ') : null,
  ].filter(Boolean)

  function handleDelete() {
    if (!window.confirm(`This permanently deletes "${sponsor.companyName}".`)) return
    deleteMutation.mutate(sponsor.id)
  }

  return (
    <div className="flex items-center justify-between gap-3 border-b border-border px-4 py-3 last:border-b-0 hover:bg-page">
      <div className="flex min-w-0 items-center gap-3">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-lg">
          {sponsor.logoUrl ? (
            <img src={resolveMediaUrl(sponsor.logoUrl)} alt="" className="h-full w-full object-cover" />
          ) : (
            '🤝'
          )}
        </div>
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <span className="truncate text-sm font-semibold text-text-primary">{sponsor.companyName}</span>
            {sponsor.status === 'inactive' && <StatusPill label="Inactive" tone="neutral" />}
          </div>
          {subtitleParts.length > 0 && (
            <p className="truncate text-xs text-text-secondary">{subtitleParts.join(' · ')}</p>
          )}
        </div>
      </div>

      <div className="flex shrink-0 items-center gap-3">
        <RoleGate minRole="tournament_admin">
          <Link to={`/sponsors/${sponsor.id}/edit`} className="text-sm font-semibold text-primary hover:underline">
            Edit
          </Link>
          <button
            type="button"
            onClick={handleDelete}
            disabled={deleteMutation.isPending}
            className="text-sm font-semibold text-negative hover:underline disabled:cursor-not-allowed disabled:opacity-60"
          >
            Delete
          </button>
        </RoleGate>
      </div>
    </div>
  )
}

/**
 * Org-level sponsor list — `GET .../sponsors`. Simple CRUD, no wizard
 * (sponsors are a lightweight identity + visibility-flag record, not a
 * multi-step registration) — mirrors SponsorsListScreen's doc comment on
 * mobile, adapted from a modal dialog to a dedicated form page/route per
 * this app's established pattern (see MatchFormPage).
 */
export function SponsorListPage() {
  const { data: sponsors, isLoading, isError } = useSponsors()

  return (
    <div>
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-text-primary">Sponsors</h1>
          <p className="mt-1 text-sm text-text-secondary">Manage sponsor profiles for your organization.</p>
        </div>
        <RoleGate minRole="tournament_admin">
          <Link
            to="/sponsors/create"
            className="rounded-xl bg-primary px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-primary-dark"
          >
            + Add Sponsor
          </Link>
        </RoleGate>
      </div>

      <div className="mt-6 rounded-2xl border border-border bg-card">
        {isLoading && <div className="p-6 text-sm text-text-secondary">Loading sponsors…</div>}

        {isError && <div className="p-6 text-sm text-negative">Could not load sponsors. Try refreshing the page.</div>}

        {!isLoading && !isError && sponsors && sponsors.length === 0 && (
          <div className="p-10 text-center text-sm text-text-muted">
            No sponsors yet.{' '}
            <RoleGate minRole="tournament_admin">
              <>
                Get started by{' '}
                <Link to="/sponsors/create" className="font-semibold text-primary hover:underline">
                  adding one
                </Link>
                .
              </>
            </RoleGate>
          </div>
        )}

        {sponsors && sponsors.length > 0 && (
          <div>
            {sponsors.map((sponsor) => (
              <SponsorRow key={sponsor.id} sponsor={sponsor} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
