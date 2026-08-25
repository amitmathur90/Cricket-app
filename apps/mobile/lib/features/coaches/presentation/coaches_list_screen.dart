import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../application/coaches_providers.dart';
import '../data/models/coach.dart';
import 'widgets/coach_form_dialog.dart';

/// Simple org-level coach CRUD — list + add/edit dialog, no wizard (coaches
/// are a lightweight identity, not a multi-step registration like players).
/// Reachable from the admin drawer's "Coaches" item and, as a shortcut, from
/// the practice session form's coach picker when no coaches exist yet.
class CoachesListScreen extends ConsumerWidget {
  const CoachesListScreen({super.key});

  Future<void> _addOrEdit(
    BuildContext context,
    WidgetRef ref,
    String organizationId, {
    Coach? existing,
  }) async {
    final result = await showCoachFormDialog(context, organizationId, existing: existing);
    if (result == null) return;
    try {
      final repo = ref.read(coachesRepositoryProvider);
      if (existing != null) {
        await repo.update(
          organizationId,
          existing.id,
          fullName: result.fullName,
          phone: result.phone,
          email: result.email,
          specialization: result.specialization,
          photoUrl: result.photoUrl,
        );
      } else {
        await repo.create(
          organizationId,
          fullName: result.fullName,
          phone: result.phone,
          email: result.email,
          specialization: result.specialization,
          photoUrl: result.photoUrl,
        );
      }
      ref.invalidate(coachesListProvider);
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
    Coach coach,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete coach?'),
        content: Text(
          'This permanently deletes "${coach.fullName}". Practice sessions that reference this '
          'coach keep their history but show no coach assigned.',
        ),
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
      await ref.read(coachesRepositoryProvider).delete(organizationId, coach.id);
      ref.invalidate(coachesListProvider);
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
    final coachesAsync = ref.watch(coachesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Coaches')),
      body: organizationId == null
          ? const Center(child: Text('No active organization'))
          : coachesAsync.when(
              data: (coaches) {
                if (coaches.isEmpty) {
                  return const Center(child: Text('No coaches yet. Tap + to add one.'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(coachesListProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: coaches.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final coach = coaches[index];
                      final subtitleParts = [
                        if (coach.specialization != null) coach.specialization!,
                        if (coach.phone != null) coach.phone!,
                        if (coach.email != null) coach.email!,
                      ];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: coach.photoUrl != null
                              ? NetworkImage(Env.mediaUrl(coach.photoUrl!))
                              : null,
                          child: coach.photoUrl == null ? const Icon(Icons.sports_outlined) : null,
                        ),
                        title: Row(
                          children: [
                            Flexible(child: Text(coach.fullName, overflow: TextOverflow.ellipsis)),
                            if (coach.status == CoachStatus.inactive) ...[
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
                                _addOrEdit(context, ref, organizationId, existing: coach);
                              case 'delete':
                                _delete(context, ref, organizationId, coach);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                        onTap: () => _addOrEdit(context, ref, organizationId, existing: coach),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(error is ApiException ? error.message : 'Failed to load coaches'),
              ),
            ),
      floatingActionButton: organizationId == null
          ? null
          : FloatingActionButton(
              tooltip: 'Add coach',
              onPressed: () => _addOrEdit(context, ref, organizationId),
              child: const Icon(Icons.add),
            ),
    );
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
