import { useState } from 'react'
import { Field, TextInput, PrimaryButton, ErrorText } from '../../../shared/components/FormPrimitives'
import { useCreateAuctionSession } from '../hooks/useCreateAuctionSession'
import { auctionErrorMessage } from '../errorMessage'
import type { AuctionSession, BidIncrementRule, CreateAuctionSessionPayload } from '../../../types/auction'

interface RuleRow {
  key: number
  /** Empty string means "no ceiling" (the catch-all `upTo: null` tier). */
  upTo: string
  increment: string
}

let ruleKeySeq = 0
function newRuleRow(): RuleRow {
  ruleKeySeq += 1
  return { key: ruleKeySeq, upTo: '', increment: '' }
}

/**
 * Settings form for POST .../auction-sessions (CreateAuctionSessionDto):
 * name, an optional tiered bid-increment schedule, an informational
 * duration budget, the default team purse, and a max squad size. Bidding is
 * always manual in this app — AuctionRealtimeService has no timer anywhere;
 * the admin marks each lot SOLD/UNSOLD and advances by hand (see that
 * class's doc comment) — so rather than a "timer mode" picker (there is
 * only one mode), this just labels that fact next to the duration field.
 */
export function CreateAuctionSessionForm({
  tournamentId,
  onCreated,
}: {
  tournamentId: string
  onCreated: (session: AuctionSession) => void
}) {
  const [name, setName] = useState('')
  const [durationMinutes, setDurationMinutes] = useState('')
  const [defaultTeamPoints, setDefaultTeamPoints] = useState('')
  const [maxSquadSize, setMaxSquadSize] = useState('')
  const [rules, setRules] = useState<RuleRow[]>([])
  const [error, setError] = useState<string | null>(null)

  const createMutation = useCreateAuctionSession(tournamentId)

  function addRule() {
    setRules((prev) => [...prev, newRuleRow()])
  }
  function updateRule(key: number, patch: Partial<RuleRow>) {
    setRules((prev) => prev.map((r) => (r.key === key ? { ...r, ...patch } : r)))
  }
  function removeRule(key: number) {
    setRules((prev) => prev.filter((r) => r.key !== key))
  }

  async function handleSubmit() {
    if (!name.trim()) {
      setError('Session name is required')
      return
    }

    const bidIncrementRules: BidIncrementRule[] = []
    for (const row of rules) {
      const increment = Number(row.increment)
      if (!row.increment.trim() || Number.isNaN(increment) || increment <= 0) {
        setError('Every bid-increment tier needs a positive increment amount')
        return
      }
      bidIncrementRules.push({ upTo: row.upTo.trim() === '' ? null : Number(row.upTo), increment })
    }
    setError(null)

    const payload: CreateAuctionSessionPayload = {
      name: name.trim(),
      bidIncrementRules: bidIncrementRules.length > 0 ? bidIncrementRules : undefined,
      durationMinutes: durationMinutes.trim() ? Number(durationMinutes) : undefined,
      defaultTeamPoints: defaultTeamPoints.trim() ? Number(defaultTeamPoints) : undefined,
      maxSquadSize: maxSquadSize.trim() ? Number(maxSquadSize) : undefined,
    }

    try {
      const created = await createMutation.mutateAsync(payload)
      onCreated(created)
    } catch (err) {
      setError(auctionErrorMessage(err))
    }
  }

  return (
    <div className="flex flex-col gap-4 rounded-2xl border border-border bg-card p-6">
      <Field label="Session name">
        <TextInput value={name} onChange={(e) => setName(e.target.value)} placeholder="Main Auction — Day 1" />
      </Field>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Duration budget, minutes (optional, informational only — never enforced)">
          <TextInput
            type="number"
            min={1}
            value={durationMinutes}
            onChange={(e) => setDurationMinutes(e.target.value)}
            placeholder="180"
          />
        </Field>
        <Field label="Bid timer">
          <div className="flex h-full min-h-[42px] items-center rounded-xl border border-border bg-page px-3.5 py-2.5 text-sm text-text-secondary">
            Manual (No Auto Timer)
          </div>
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Default team points (optional)">
          <TextInput
            type="number"
            min={0}
            value={defaultTeamPoints}
            onChange={(e) => setDefaultTeamPoints(e.target.value)}
            placeholder="Applied to every team's purse when this session starts"
          />
        </Field>
        <Field label="Max squad size (optional)">
          <TextInput
            type="number"
            min={1}
            value={maxSquadSize}
            onChange={(e) => setMaxSquadSize(e.target.value)}
            placeholder="No cap"
          />
        </Field>
      </div>

      <div>
        <div className="mb-1.5 flex items-center justify-between">
          <span className="text-sm font-medium text-text-secondary">
            Bid increment schedule (optional — default: 5% of the current bid, rounded)
          </span>
          <button type="button" onClick={addRule} className="text-xs font-semibold text-primary hover:underline">
            + Add tier
          </button>
        </div>

        {rules.length === 0 && (
          <p className="rounded-lg bg-page px-3 py-2 text-xs text-text-secondary">
            No tiers set — the default increment applies at every bid level.
          </p>
        )}

        <div className="flex flex-col gap-2">
          {rules.map((row) => (
            <div key={row.key} className="flex items-center gap-2">
              <TextInput
                type="number"
                min={0}
                placeholder="Up to (blank = no ceiling)"
                value={row.upTo}
                onChange={(e) => updateRule(row.key, { upTo: e.target.value })}
              />
              <TextInput
                type="number"
                min={1}
                placeholder="Increment"
                value={row.increment}
                onChange={(e) => updateRule(row.key, { increment: e.target.value })}
              />
              <button
                type="button"
                onClick={() => removeRule(row.key)}
                className="shrink-0 rounded-lg px-2 py-1 text-xs text-negative hover:bg-negative/10"
              >
                Remove
              </button>
            </div>
          ))}
        </div>
      </div>

      <ErrorText>{error}</ErrorText>

      <div className="flex justify-end">
        <PrimaryButton type="button" className="w-auto" onClick={handleSubmit} disabled={createMutation.isPending}>
          {createMutation.isPending ? 'Creating…' : 'Create session'}
        </PrimaryButton>
      </div>
    </div>
  )
}
