import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../application/finance_providers.dart';
import '../data/models/finance_transaction.dart';

/// Create/Edit a finance transaction — one form for `CreateFinanceTransactionDto`
/// and `UpdateFinanceTransactionDto` (same "one route, `extra` decides
/// create-vs-edit" pattern as MatchFormScreen/PracticeSessionFormScreen).
///
/// Always scoped to [tournamentId] (this screen is only reached from within
/// one tournament's Finance tab) — new transactions are created with that
/// `tournamentId`, never org-wide, matching the tournament-scoped shape of
/// every other tab here.
///
/// Category/type enforcement: the backend rejects any category/type pair
/// that doesn't match `FINANCE_CATEGORY_TYPE` with a 400
/// (`FinanceService.assertCategoryTypeMatch`). Rather than let a user pick
/// an invalid combination and hit that error, this form derives the
/// allowed type from the selected category (`financeCategoryType`) and
/// auto-selects it whenever the category changes; the "Income"/"Expense"
/// choice chips below only allow selecting the one value that's valid for
/// the current category — the other is rendered disabled (greyed out, its
/// `onSelected` is null) so the invalid pair is never reachable through
/// this UI at all.
class FinanceTransactionFormScreen extends ConsumerStatefulWidget {
  const FinanceTransactionFormScreen({super.key, required this.tournamentId, this.existing});

  final String tournamentId;

  /// When non-null, the form opens pre-filled with this transaction's data
  /// and submits via PATCH instead of POST.
  final FinanceTransaction? existing;

  @override
  ConsumerState<FinanceTransactionFormScreen> createState() => _FinanceTransactionFormScreenState();
}

class _FinanceTransactionFormScreenState extends ConsumerState<FinanceTransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late FinanceTransactionCategory _category;
  late FinanceTransactionType _type;
  late DateTime _referenceDate;
  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _category = existing.category;
      _type = existing.type;
      _referenceDate = DateTime.tryParse(existing.referenceDate) ?? DateTime.now();
      _amountController.text = existing.amount;
      _descriptionController.text = existing.description ?? '';
    } else {
      _category = FinanceTransactionCategory.sponsorship;
      _type = financeCategoryType[_category]!;
      _referenceDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(FinanceTransactionCategory? category) {
    if (category == null) return;
    setState(() {
      _category = category;
      // Auto-lock the type to whatever's valid for this category — see
      // this screen's class doc comment.
      _type = financeCategoryType[_category]!;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _referenceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (date == null) return;
    setState(() => _referenceDate = date);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return;

    final amount = num.parse(_amountController.text.trim());
    final description = _descriptionController.text.trim();
    final referenceDate = DateFormat('yyyy-MM-dd').format(_referenceDate);

    setState(() => _submitting = true);
    try {
      final repo = ref.read(financeRepositoryProvider);
      if (_isEditing) {
        await repo.update(
          organizationId,
          widget.existing!.id,
          tournamentId: widget.tournamentId,
          category: _category,
          type: _type,
          amount: amount,
          description: description.isEmpty ? null : description,
          referenceDate: referenceDate,
        );
        ref.invalidate(financeTransactionDetailProvider(widget.existing!.id));
      } else {
        await repo.create(
          organizationId,
          tournamentId: widget.tournamentId,
          category: _category,
          type: _type,
          amount: amount,
          description: description.isEmpty ? null : description,
          referenceDate: referenceDate,
        );
      }
      // Every list/dashboard view scoped to this tournament may now be
      // stale — invalidate broadly rather than trying to enumerate every
      // filter combination's provider instance.
      ref.invalidate(financeDashboardProvider(widget.tournamentId));
      if (!mounted) return;
      context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowedType = financeCategoryType[_category]!;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit transaction' : 'Add transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<FinanceTransactionCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in FinanceTransactionCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: _onCategoryChanged,
              ),
              const SizedBox(height: 16),
              Text('Type', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Income'),
                      selected: _type == FinanceTransactionType.income,
                      onSelected: allowedType == FinanceTransactionType.income
                          ? (_) => setState(() => _type = FinanceTransactionType.income)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Expense'),
                      selected: _type == FinanceTransactionType.expense,
                      onSelected: allowedType == FinanceTransactionType.expense
                          ? (_) => setState(() => _type = FinanceTransactionType.expense)
                          : null,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '"${_category.label}" is always ${allowedType.label.toLowerCase()} — set automatically.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ '),
                validator: (v) {
                  final parsed = num.tryParse((v ?? '').trim());
                  if (parsed == null) return 'Enter a valid amount';
                  if (parsed < 0) return 'Amount cannot be negative';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reference date'),
                subtitle: Text(DateFormat.yMMMd().format(_referenceDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Add transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
