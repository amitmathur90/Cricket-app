import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../application/finance_providers.dart';
import '../data/models/finance_transaction.dart';
import 'widgets/finance_format.dart';

/// Filters currently applied to the transaction list — kept local to this
/// screen (not shared app state), reset every time the screen is opened
/// fresh, same lifetime as the list itself.
final _categoryFilterProvider = StateProvider.autoDispose<FinanceTransactionCategory?>((ref) => null);
final _typeFilterProvider = StateProvider.autoDispose<FinanceTransactionType?>((ref) => null);

/// `GET .../finance/transactions?tournamentId=...` filtered by
/// category/type, with an add-transaction FAB. Unifies the spec's "Auction
/// transactions / Sponsorship / Ground expenses / Officials payment / Other
/// expenses" modules into one filterable list, per the category filter —
/// that's what `FinanceTransaction`'s data model actually supports; auction
/// purse movements themselves stay out of this list entirely (they're
/// derived onto the dashboard's `auctionRevenue` figure from
/// `auction_player_pool`, not stored as `finance_transactions` rows — see
/// FinanceDashboard's doc comment).
class FinanceTransactionsScreen extends ConsumerWidget {
  const FinanceTransactionsScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(_categoryFilterProvider);
    final type = ref.watch(_typeFilterProvider);
    final query = (tournamentId: tournamentId, category: category, type: type);
    final transactionsAsync = ref.watch(financeTransactionsListProvider(query));

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<FinanceTransactionCategory?>(
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category', isDense: true),
                    items: [
                      const DropdownMenuItem<FinanceTransactionCategory?>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      for (final c in FinanceTransactionCategory.values)
                        DropdownMenuItem<FinanceTransactionCategory?>(value: c, child: Text(c.label)),
                    ],
                    onChanged: (v) => ref.read(_categoryFilterProvider.notifier).state = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<FinanceTransactionType?>(
                    initialValue: type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type', isDense: true),
                    items: const [
                      DropdownMenuItem<FinanceTransactionType?>(value: null, child: Text('All types')),
                      DropdownMenuItem<FinanceTransactionType?>(
                        value: FinanceTransactionType.income,
                        child: Text('Income'),
                      ),
                      DropdownMenuItem<FinanceTransactionType?>(
                        value: FinanceTransactionType.expense,
                        child: Text('Expense'),
                      ),
                    ],
                    onChanged: (v) => ref.read(_typeFilterProvider.notifier).state = v,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Center(child: Text('No transactions recorded yet.'));
                }
                final sorted = [...transactions]
                  ..sort((a, b) => b.referenceDate.compareTo(a.referenceDate));
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(financeTransactionsListProvider(query).future),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) => _TransactionTile(
                      tournamentId: tournamentId,
                      transaction: sorted[index],
                      onChanged: () => ref.invalidate(financeTransactionsListProvider(query)),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(error is ApiException ? error.message : 'Failed to load transactions'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await context.push<bool>(financeTransactionFormPath(tournamentId));
          if (saved == true) ref.invalidate(financeTransactionsListProvider(query));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add transaction'),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.tournamentId,
    required this.transaction,
    required this.onChanged,
  });

  final String tournamentId;
  final FinanceTransaction transaction;

  /// Invoked when returning from the detail screen after an edit or
  /// delete, so this list re-fetches rather than showing stale rows.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == FinanceTransactionType.income;
    final color = isIncome ? Colors.green : Colors.red;
    final date = DateTime.tryParse(transaction.referenceDate);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: color),
        ),
        title: Text(transaction.category.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          [
            if (transaction.description != null && transaction.description!.isNotEmpty)
              transaction.description!,
            date != null ? DateFormat.yMMMd().format(date) : transaction.referenceDate,
          ].join(' · '),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}${formatInr(transaction.amount)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        onTap: () async {
          final changed = await context.push<bool>(
            financeTransactionDetailPath(tournamentId, transaction.id),
            extra: transaction,
          );
          if (changed == true) onChanged();
        },
      ),
    );
  }
}
