/**
 * Mirrors FinanceService.DashboardResponse (apps/backend/src/modules/finance/finance.service.ts).
 * Decimal fields come back as strings (Postgres numeric columns), same
 * convention as Tournament's fee fields. `getDashboard` genuinely
 * aggregates org-wide when `tournamentId` is omitted — this is real data,
 * not a fabricated rollup. There is no period-over-period delta field
 * anywhere in this response; never invent one.
 */
export interface FinanceDashboard {
  scope: { organizationId: string; tournamentId: string | null }
  totalRevenue: string
  revenueBreakdown: {
    registrationRevenue: string
    auctionRevenue: string
    sponsorshipRevenue: string
    otherIncome: string
  }
  totalExpenses: string
  expenseBreakdown: {
    groundExpense: string
    officialsPayment: string
    otherExpense: string
  }
  netBalance: string
}
