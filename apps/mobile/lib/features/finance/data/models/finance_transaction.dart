/// Mirrors `FinanceTransactionCategory` in
/// apps/backend/src/database/entities/finance-transaction.entity.ts.
///
/// Every category has exactly one valid [FinanceTransactionType], enforced
/// server-side (`FinanceService.assertCategoryTypeMatch`) — see
/// [financeCategoryType] below, which mirrors the backend's
/// `FINANCE_CATEGORY_TYPE` map so the UI can lock the type field to the
/// right value per category and never send a combination the backend would
/// reject with a 400.
enum FinanceTransactionCategory { sponsorship, groundExpense, officialsPayment, otherExpense, otherIncome }

extension FinanceTransactionCategoryX on FinanceTransactionCategory {
  String get apiValue => switch (this) {
        FinanceTransactionCategory.sponsorship => 'sponsorship',
        FinanceTransactionCategory.groundExpense => 'ground_expense',
        FinanceTransactionCategory.officialsPayment => 'officials_payment',
        FinanceTransactionCategory.otherExpense => 'other_expense',
        FinanceTransactionCategory.otherIncome => 'other_income',
      };

  String get label => switch (this) {
        FinanceTransactionCategory.sponsorship => 'Sponsorship',
        FinanceTransactionCategory.groundExpense => 'Ground expense',
        FinanceTransactionCategory.officialsPayment => 'Officials payment',
        FinanceTransactionCategory.otherExpense => 'Other expense',
        FinanceTransactionCategory.otherIncome => 'Other income',
      };

  static FinanceTransactionCategory fromApi(String value) => FinanceTransactionCategory.values.firstWhere(
        (c) => c.apiValue == value,
        orElse: () => FinanceTransactionCategory.otherExpense,
      );
}

/// Mirrors `FinanceTransactionType` in the same entity file.
enum FinanceTransactionType { income, expense }

extension FinanceTransactionTypeX on FinanceTransactionType {
  String get apiValue => switch (this) {
        FinanceTransactionType.income => 'income',
        FinanceTransactionType.expense => 'expense',
      };

  String get label => switch (this) {
        FinanceTransactionType.income => 'Income',
        FinanceTransactionType.expense => 'Expense',
      };

  static FinanceTransactionType fromApi(String value) => switch (value) {
        'income' => FinanceTransactionType.income,
        _ => FinanceTransactionType.expense,
      };
}

/// Mirrors the backend's `FINANCE_CATEGORY_TYPE` const exactly — the single
/// source of truth this app's create/edit form uses to lock the `type`
/// field per selected category (see FinanceTransactionFormScreen), so a
/// user can never submit an invalid category/type pair and hit the
/// server's 400.
const Map<FinanceTransactionCategory, FinanceTransactionType> financeCategoryType = {
  FinanceTransactionCategory.sponsorship: FinanceTransactionType.income,
  FinanceTransactionCategory.otherIncome: FinanceTransactionType.income,
  FinanceTransactionCategory.groundExpense: FinanceTransactionType.expense,
  FinanceTransactionCategory.officialsPayment: FinanceTransactionType.expense,
  FinanceTransactionCategory.otherExpense: FinanceTransactionType.expense,
};

/// Mirrors `FinanceTransaction` in
/// apps/backend/src/database/entities/finance-transaction.entity.ts —
/// one manually-recorded income/expense entry (sponsorship cash, ground
/// rental, officials' payment, etc). Does NOT cover registration fees or
/// auction sale prices — those are derived read-only figures on the
/// dashboard (see FinanceDashboard), never rows here.
class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.organizationId,
    required this.tournamentId,
    required this.category,
    required this.type,
    required this.amount,
    required this.description,
    required this.referenceDate,
    required this.createdByUserId,
    required this.createdAt,
  });

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) => FinanceTransaction(
        id: json['id'] as String,
        organizationId: json['organizationId'] as String,
        tournamentId: json['tournamentId'] as String?,
        category: FinanceTransactionCategoryX.fromApi(json['category'] as String),
        type: FinanceTransactionTypeX.fromApi(json['type'] as String),
        amount: json['amount'] as String,
        description: json['description'] as String?,
        referenceDate: json['referenceDate'] as String,
        createdByUserId: json['createdByUserId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String organizationId;

  /// Null = org-wide entry, not attributable to a single tournament.
  final String? tournamentId;
  final FinanceTransactionCategory category;
  final FinanceTransactionType type;

  /// Decimal-as-string (Postgres `decimal` columns serialize as strings to
  /// avoid float precision loss) — same convention as
  /// `Tournament.playerRegistrationFee`/`teamRegistrationFee`.
  final String amount;
  final String? description;

  /// ISO date string (`YYYY-MM-DD`) — the date the transaction is
  /// attributed to, not [createdAt].
  final String referenceDate;
  final String createdByUserId;
  final DateTime createdAt;
}
