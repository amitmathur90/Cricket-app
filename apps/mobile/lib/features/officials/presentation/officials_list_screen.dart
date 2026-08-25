import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../application/officials_providers.dart';
import '../data/models/official.dart';
import 'widgets/official_form_dialog.dart';

/// One org-level list screen covering umpires, scorers, and match referees
/// — mirrors how the backend groups them under a single `officials` table
/// with a `role` column (see Official entity's doc comment) rather than
/// splitting into three near-identical screens. A segmented role filter
/// (All/Umpire/Scorer/Match Referee) narrows the list; the add/edit dialog
/// always has a role dropdown regardless of the active filter.
class OfficialsListScreen extends ConsumerStatefulWidget {
  const OfficialsListScreen({super.key});

  @override
  ConsumerState<OfficialsListScreen> createState() => _OfficialsListScreenState();
}

class _OfficialsListScreenState extends ConsumerState<OfficialsListScreen> {
  OfficialRole? _roleFilter;

  Future<void> _addOrEdit(
    BuildContext context,
    String organizationId, {
    Official? existing,
  }) async {
    final result = await showOfficialFormDialog(
      context,
      organizationId,
      existing: existing,
      initialRole: existing?.role ?? _roleFilter,
    );
    if (result == null) return;
    try {
      final repo = ref.read(officialsRepositoryProvider);
      if (existing != null) {
        await repo.update(
          organizationId,
          existing.id,
          fullName: result.fullName,
          role: result.role,
          phone: result.phone,
          email: result.email,
          photoUrl: result.photoUrl,
        );
      } else {
        await repo.create(
          organizationId,
          fullName: result.fullName,
          role: result.role,
          phone: result.phone,
          email: result.email,
          photoUrl: result.photoUrl,
        );
      }
      ref.invalidate(officialsListProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(BuildContext context, String organizationId, Official official) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete official?'),
        content: Text(
          'This permanently deletes "${official.fullName}". Matches that reference this official '
          'keep their history but show no ${official.role.label.toLowerCase()} assigned.',
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
      await ref.read(officialsRepositoryProvider).delete(organizationId, official.id);
      ref.invalidate(officialsListProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
    final officialsAsync = ref.watch(officialsListProvider(_roleFilter));

    return Scaffold(
      appBar: AppBar(title: const Text('Officials')),
      body: organizationId == null
          ? const Center(child: Text('No active organization'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<OfficialRole?>(
                      segments: const [
                        ButtonSegment(value: null, label: Text('All')),
                        ButtonSegment(value: OfficialRole.umpire, label: Text('Umpire')),
                        ButtonSegment(value: OfficialRole.scorer, label: Text('Scorer')),
                        ButtonSegment(
                          value: OfficialRole.matchReferee,
                          label: Text('Match Referee'),
                        ),
                      ],
                      selected: {_roleFilter},
                      onSelectionChanged: (selection) {
                        setState(() => _roleFilter = selection.first);
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: officialsAsync.when(
                    data: (officials) {
                      if (officials.isEmpty) {
                        return const Center(child: Text('No officials yet. Tap + to add one.'));
                      }
                      return RefreshIndicator(
                        onRefresh: () => ref.refresh(officialsListProvider(_roleFilter).future),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: officials.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final official = officials[index];
                            final subtitleParts = [
                              official.role.label,
                              if (official.phone != null) official.phone!,
                              if (official.email != null) official.email!,
                            ];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: official.photoUrl != null
                                    ? NetworkImage(Env.mediaUrl(official.photoUrl!))
                                    : null,
                                child: official.photoUrl == null
                                    ? const Icon(Icons.sports_outlined)
                                    : null,
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(official.fullName, overflow: TextOverflow.ellipsis),
                                  ),
                                  if (official.status == OfficialStatus.inactive) ...[
                                    const SizedBox(width: 6),
                                    const _InactiveBadge(),
                                  ],
                                ],
                              ),
                              subtitle: Text(subtitleParts.join(' · ')),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) {
                                  switch (action) {
                                    case 'edit':
                                      _addOrEdit(context, organizationId, existing: official);
                                    case 'delete':
                                      _delete(context, organizationId, official);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                              onTap: () => _addOrEdit(context, organizationId, existing: official),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => Center(
                      child: Text(error is ApiException ? error.message : 'Failed to load officials'),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: organizationId == null
          ? null
          : FloatingActionButton(
              tooltip: 'Add official',
              onPressed: () => _addOrEdit(context, organizationId),
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
