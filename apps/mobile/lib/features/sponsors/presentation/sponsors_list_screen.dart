import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../application/sponsors_providers.dart';
import '../data/models/sponsor.dart';
import 'widgets/sponsor_form_dialog.dart';

/// Simple org-level sponsor CRUD — list + add/edit dialog, no wizard
/// (sponsors are a lightweight identity + visibility-flag record, not a
/// multi-step registration like players). Reachable from the admin drawer's
/// "Sponsors" item.
class SponsorsListScreen extends ConsumerWidget {
  const SponsorsListScreen({super.key});

  Future<void> _addOrEdit(
    BuildContext context,
    WidgetRef ref,
    String organizationId, {
    Sponsor? existing,
  }) async {
    final result = await showSponsorFormDialog(context, organizationId, existing: existing);
    if (result == null) return;
    try {
      final repo = ref.read(sponsorsRepositoryProvider);
      if (existing != null) {
        await repo.update(
          organizationId,
          existing.id,
          companyName: result.companyName,
          logoUrl: result.logoUrl,
          packageName: result.packageName,
          amount: result.amount,
          contractStartDate: result.contractStartDate,
          contractEndDate: result.contractEndDate,
          visibleOnWebsite: result.visibleOnWebsite,
          visibleOnApp: result.visibleOnApp,
          visibleOnMatchScreen: result.visibleOnMatchScreen,
          visibleOnScoreboard: result.visibleOnScoreboard,
          visibleOnSocialMedia: result.visibleOnSocialMedia,
        );
      } else {
        await repo.create(
          organizationId,
          companyName: result.companyName,
          logoUrl: result.logoUrl,
          packageName: result.packageName,
          amount: result.amount,
          contractStartDate: result.contractStartDate,
          contractEndDate: result.contractEndDate,
          visibleOnWebsite: result.visibleOnWebsite,
          visibleOnApp: result.visibleOnApp,
          visibleOnMatchScreen: result.visibleOnMatchScreen,
          visibleOnScoreboard: result.visibleOnScoreboard,
          visibleOnSocialMedia: result.visibleOnSocialMedia,
        );
      }
      ref.invalidate(sponsorsListProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String organizationId,
    Sponsor sponsor,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sponsor?'),
        content: Text('This permanently deletes "${sponsor.companyName}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(sponsorsRepositoryProvider).delete(organizationId, sponsor.id);
      ref.invalidate(sponsorsListProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
    final sponsorsAsync = ref.watch(sponsorsListProvider);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Sponsors')),
      body: organizationId == null
          ? const Center(child: Text('No active organization'))
          : sponsorsAsync.when(
              data: (sponsors) {
                if (sponsors.isEmpty) {
                  return const Center(child: Text('No sponsors yet. Tap + to add one.'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(sponsorsListProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: sponsors.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final sponsor = sponsors[index];
                      final contractParts = [
                        if (sponsor.contractStartDate != null)
                          DateTime.tryParse(sponsor.contractStartDate!) != null
                              ? dateFormat.format(DateTime.parse(sponsor.contractStartDate!))
                              : sponsor.contractStartDate!,
                        if (sponsor.contractEndDate != null)
                          DateTime.tryParse(sponsor.contractEndDate!) != null
                              ? dateFormat.format(DateTime.parse(sponsor.contractEndDate!))
                              : sponsor.contractEndDate!,
                      ];
                      final subtitleParts = [
                        if (sponsor.packageName != null) sponsor.packageName!,
                        if (sponsor.amount != null) _formatAmount(sponsor.amount!),
                        if (contractParts.isNotEmpty) contractParts.join(' – '),
                      ];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          backgroundImage: sponsor.logoUrl != null
                              ? NetworkImage(Env.mediaUrl(sponsor.logoUrl!))
                              : null,
                          child: sponsor.logoUrl == null
                              ? const Icon(Icons.handshake_outlined)
                              : null,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(sponsor.companyName, overflow: TextOverflow.ellipsis),
                            ),
                            if (sponsor.status == SponsorStatus.inactive) ...[
                              const SizedBox(width: 6),
                              const _InactiveBadge(),
                            ],
                          ],
                        ),
                        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            switch (action) {
                              case 'edit':
                                _addOrEdit(context, ref, organizationId, existing: sponsor);
                              case 'delete':
                                _delete(context, ref, organizationId, sponsor);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                        onTap: () => _addOrEdit(context, ref, organizationId, existing: sponsor),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(error is ApiException ? error.message : 'Failed to load sponsors'),
              ),
            ),
      floatingActionButton: organizationId == null
          ? null
          : FloatingActionButton(
              tooltip: 'Add sponsor',
              onPressed: () => _addOrEdit(context, ref, organizationId),
              child: const Icon(Icons.add),
            ),
    );
  }

  String _formatAmount(String amount) {
    final value = num.tryParse(amount);
    if (value == null) return amount;
    return NumberFormat.currency(symbol: '₹', decimalDigits: value == value.roundToDouble() ? 0 : 2)
        .format(value);
  }
}

class _InactiveBadge extends StatelessWidget {
  const _InactiveBadge();

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).disabledColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: mutedColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Inactive',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: mutedColor),
      ),
    );
  }
}
