/// Mirrors `DashboardResponse.revenueBreakdown` in
/// apps/backend/src/modules/finance/finance.service.ts.
class FinanceRevenueBreakdown {
  const FinanceRevenueBreakdown({
    required this.registrationRevenue,
    required this.auctionRevenue,
    required this.sponsorshipRevenue,
    required this.otherIncome,
  });

  factory FinanceRevenueBreakdown.fromJson(Map<String, dynamic> json) => FinanceRevenueBreakdown(
        registrationRevenue: json['registrationRevenue'] as String,
        auctionRevenue: json['auctionRevenue'] as String,
        sponsorshipRevenue: json['sponsorshipRevenue'] as String,
        otherIncome: json['otherIncome'] as String,
      );

  final String registrationRevenue;
  final String auctionRevenue;
  final String sponsorshipRevenue;
  final String otherIncome;
}

/// Mirrors `DashboardResponse.expenseBreakdown`.
class FinanceExpenseBreakdown {
  const FinanceExpenseBreakdown({
    required this.groundExpense,
    required this.officialsPayment,
    required this.otherExpense,
  });

  factory FinanceExpenseBreakdown.fromJson(Map<String, dynamic> json) => FinanceExpenseBreakdown(
        groundExpense: json['groundExpense'] as String,
        officialsPayment: json['officialsPayment'] as String,
        otherExpense: json['otherExpense'] as String,
      );

  final String groundExpense;
  final String officialsPayment;
  final String otherExpense;
}

/// Mirrors `FinanceService.getDashboard`'s full response shape
/// (`DashboardResponse` in finance.service.ts). All amounts are
/// decimal-as-string, already `.toFixed(2)`-formatted server-side.
///
/// `registrationRevenue` and `auctionRevenue` are derived read-only figures
/// (registration fee × registered counts; sum of sold auction lots) — see
/// FinanceService's class doc comment. Neither has a corresponding
/// `FinanceTransaction` row, so they can't be edited/deleted from this app;
/// they only ever change as teams/players register or auction lots sell.
class FinanceDashboard {
  const FinanceDashboard({
    required this.tournamentId,
    required this.totalRevenue,
    required this.revenueBreakdown,
    required this.totalExpenses,
    required this.expenseBreakdown,
    required this.netBalance,
  });

  factory FinanceDashboard.fromJson(Map<String, dynamic> json) => FinanceDashboard(
        tournamentId: (json['scope'] as Map<String, dynamic>)['tournamentId'] as String?,
        totalRevenue: json['totalRevenue'] as String,
        revenueBreakdown:
            FinanceRevenueBreakdown.fromJson(json['revenueBreakdown'] as Map<String, dynamic>),
        totalExpenses: json['totalExpenses'] as String,
        expenseBreakdown:
            FinanceExpenseBreakdown.fromJson(json['expenseBreakdown'] as Map<String, dynamic>),
        netBalance: json['netBalance'] as String,
      );

  final String? tournamentId;
  final String totalRevenue;
  final FinanceRevenueBreakdown revenueBreakdown;
  final String totalExpenses;
  final FinanceExpenseBreakdown expenseBreakdown;

  /// `totalRevenue - totalExpenses` — may be negative (a leading `-` on the
  /// decimal string), rendered red in the UI when so.
  final String netBalance;
}
