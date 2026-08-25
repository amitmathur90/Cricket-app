import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../auth/application/session_controller.dart';
import '../application/finance_providers.dart';
import '../data/models/finance_transaction.dart';
import 'widgets/finance_format.dart';

/// One transaction's detail view — doubles as its "receipt"/printable
/// record per the spec (no PDF generation, matching the backend's own
/// minimal-scope decision — `FinanceController.findOne`'s doc comment
/// literally calls this endpoint out as "also serves as its printable
/// record"). Edit/Delete are always shown; like every other admin action in
/// this app (see AuctionRepository's `undoLastBid` doc comment), role
/// enforcement is server-side only — a non-admin tapping either simply sees
/// the backend's 403 surfaced as a snackbar, nothing is hidden client-side.
class FinanceTransactionDetailScreen extends ConsumerWidget {
  const FinanceTransactionDetailScreen({
    super.key,
    required this.tournamentId,
    required this.transactionId,
    this.initialTransaction,
  });

  final String tournamentId;
  final String transactionId;

  /// Passed by FinanceTransactionsScreen, which already has the full
  /// transaction loaded — avoids a redundant fetch. Null on a cold
  /// deep-link; falls back to [financeTransactionDetailProvider].
  final FinanceTransaction? initialTransaction;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return;
    try {
      await ref.read(financeRepositoryProvider).remove(organizationId, transactionId);
      ref.invalidate(financeDashboardProvider(tournamentId));
      if (!context.mounted) return;
      context.pop(true);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, FinanceTransaction transaction) async {
    final saved = await context.push<bool>(
      financeTransactionFormPath(tournamentId),
      extra: transaction,
    );
    if (saved == true) {
      ref.invalidate(financeTransactionDetailProvider(transactionId));
      if (context.mounted) context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionAsync = initialTransaction != null
        ? AsyncValue.data(initialTransaction!)
        : ref.watch(financeTransactionDetailProvider(transactionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: transactionAsync.maybeWhen(
          data: (transaction) => [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(context, ref, transaction),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref),
            ),
          ],
          orElse: () => const [],
        ),
      ),
      body: transactionAsync.when(
        data: (transaction) => _ReceiptView(transaction: transaction),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load transaction'),
        ),
      ),
    );
  }
}

class _ReceiptView extends StatelessWidget {
  const _ReceiptView({required this.transaction});

  final FinanceTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == FinanceTransactionType.income;
    final color = isIncome ? Colors.green : Colors.red;
    final date = DateTime.tryParse(transaction.referenceDate);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 32),
                const SizedBox(height: 8),
                Text(
                  '${isIncome ? '+' : '-'}${formatInr(transaction.amount)}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                Text(transaction.type.label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _DetailRow(label: 'Category', value: transaction.category.label),
              const Divider(height: 1),
              _DetailRow(
                label: 'Description',
                value: (transaction.description == null || transaction.description!.isEmpty)
                    ? '—'
                    : transaction.description!,
              ),
              const Divider(height: 1),
              _DetailRow(
                label: 'Reference date',
                value: date != null ? DateFormat.yMMMd().format(date) : transaction.referenceDate,
              ),
              const Divider(height: 1),
              _DetailRow(
                label: 'Recorded on',
                value: DateFormat.yMMMd().add_jm().format(transaction.createdAt.toLocal()),
              ),
              const Divider(height: 1),
              _DetailRow(
                label: 'Scope',
                value: transaction.tournamentId != null ? 'This tournament' : 'Org-wide',
              ),
              const Divider(height: 1),
              _DetailRow(label: 'Transaction ID', value: transaction.id),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
