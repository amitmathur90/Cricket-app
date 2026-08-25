import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../players/data/models/player.dart' show PlayerRoleX;
import '../../application/tournament_applications_providers.dart';
import '../../data/models/tournament_application.dart';

/// Admin-only tab (org_admin/tournament_admin) on TournamentDetailScreen —
/// lists applications for this tournament with a status filter, and
/// Approve/Reject actions. Same interaction pattern as
/// features/players/presentation/widgets/player_list_tab.dart's
/// verify/reject popup-menu-with-optional-reason-dialog.
class ApplicationsReviewTab extends ConsumerStatefulWidget {
  const ApplicationsReviewTab({super.key, required this.organizationId, required this.tournamentId});

  final String organizationId;
  final String tournamentId;

  @override
  ConsumerState<ApplicationsReviewTab> createState() => _ApplicationsReviewTabState();
}

class _ApplicationsReviewTabState extends ConsumerState<ApplicationsReviewTab> {
  TournamentApplicationStatus? _filter = TournamentApplicationStatus.pending;

  Future<void> _showError(BuildContext context, Object error) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(error is ApiException ? error.message : 'Something went wrong'),
      ));
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    TournamentApplication application,
    TournamentApplicationStatus status,
  ) async {
    String? note;
    if (status == TournamentApplicationStatus.rejected) {
      note = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Reject application'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Reject'),
              ),
            ],
          );
        },
      );
      if (note == null) return; // dialog cancelled
    }
    try {
      await ref.read(tournamentApplicationsRepositoryProvider).review(
            widget.organizationId,
            widget.tournamentId,
            application.id,
            status: status,
            note: note,
          );
      // Invalidate every filter variant of this family — whichever one is
      // currently being watched will refetch; the rest are cheap to drop
      // (autoDispose) since nothing else is holding them.
      ref.invalidate(tournamentApplicationsProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      await _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicationsAsync = ref.watch(
      tournamentApplicationsProvider((tournamentId: widget.tournamentId, status: _filter)),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            spacing: 8,
            children: [
              _FilterChip(label: 'Pending', selected: _filter == TournamentApplicationStatus.pending,
                  onSelected: () => setState(() => _filter = TournamentApplicationStatus.pending)),
              _FilterChip(label: 'Approved', selected: _filter == TournamentApplicationStatus.approved,
                  onSelected: () => setState(() => _filter = TournamentApplicationStatus.approved)),
              _FilterChip(label: 'Rejected', selected: _filter == TournamentApplicationStatus.rejected,
                  onSelected: () => setState(() => _filter = TournamentApplicationStatus.rejected)),
              _FilterChip(label: 'All', selected: _filter == null,
                  onSelected: () => setState(() => _filter = null)),
            ],
          ),
        ),
        Expanded(
          child: applicationsAsync.when(
            data: (applications) {
              if (applications.isEmpty) {
                return const Center(child: Text('No applications here.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: applications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final application = applications[index];
                  final player = application.player;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: player?.photoUrl != null
                          ? NetworkImage(Env.mediaUrl(player!.photoUrl!))
                          : null,
                      child: player?.photoUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            player?.fullName ?? 'Unknown player',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(status: application.status),
                      ],
                    ),
                    subtitle: Text([
                      if (player != null) player.role.label,
                      if (player?.ageCategory != null) player!.ageCategory!,
                      if (application.reviewNote != null) 'Note: ${application.reviewNote}',
                    ].join(' · ')),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        switch (action) {
                          case 'approve':
                            _review(context, ref, application, TournamentApplicationStatus.approved);
                          case 'reject':
                            _review(context, ref, application, TournamentApplicationStatus.rejected);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'approve', child: Text('Approve')),
                        const PopupMenuItem(value: 'reject', child: Text('Reject')),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text(error is ApiException ? error.message : 'Failed to load applications'),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final TournamentApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      TournamentApplicationStatus.approved => (Colors.green, Icons.check_circle),
      TournamentApplicationStatus.rejected => (Colors.red, Icons.cancel),
      TournamentApplicationStatus.pending => (Colors.orange, Icons.hourglass_top),
    };
    return Tooltip(
      message: status.label,
      child: Icon(icon, size: 16, color: color),
    );
  }
}
