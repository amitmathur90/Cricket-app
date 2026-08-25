import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../auth/application/session_controller.dart';
import '../application/venues_providers.dart';
import '../data/models/venue.dart';
import 'widgets/venue_form_dialog.dart';

/// Simple org-level venue CRUD — list + add/edit dialog, no wizard (venues
/// are a lightweight identity, not a multi-step registration like players).
/// Reachable from the admin drawer's "Venues" item and, as a shortcut, from
/// the match form's venue picker when no venues exist yet.
class VenuesListScreen extends ConsumerWidget {
  const VenuesListScreen({super.key});

  Future<void> _addOrEdit(
    BuildContext context,
    WidgetRef ref,
    String organizationId, {
    Venue? existing,
  }) async {
    final result = await showVenueFormDialog(context, organizationId, existing: existing);
    if (result == null) return;
    try {
      final repo = ref.read(venuesRepositoryProvider);
      if (existing != null) {
        await repo.update(
          organizationId,
          existing.id,
          name: result.name,
          location: result.location,
          capacity: result.capacity,
          pitchType: result.pitchType,
          facilities: result.facilities,
          photoUrl: result.photoUrl,
        );
      } else {
        await repo.create(
          organizationId,
          name: result.name,
          location: result.location,
          capacity: result.capacity,
          pitchType: result.pitchType,
          facilities: result.facilities,
          photoUrl: result.photoUrl,
        );
      }
      ref.invalidate(venuesListProvider);
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
    Venue venue,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete venue?'),
        content: Text(
          'This permanently deletes "${venue.name}". Matches that reference this venue keep '
          'their history but show no venue assigned.',
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
      await ref.read(venuesRepositoryProvider).delete(organizationId, venue.id);
      ref.invalidate(venuesListProvider);
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
    final venuesAsync = ref.watch(venuesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Venues')),
      body: organizationId == null
          ? const Center(child: Text('No active organization'))
          : venuesAsync.when(
              data: (venues) {
                if (venues.isEmpty) {
                  return const Center(child: Text('No venues yet. Tap + to add one.'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(venuesListProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: venues.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final venue = venues[index];
                      final subtitleParts = [
                        if (venue.location != null) venue.location!,
                        if (venue.capacity != null) '${venue.capacity} capacity',
                      ];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: venue.photoUrl != null
                              ? NetworkImage(Env.mediaUrl(venue.photoUrl!))
                              : null,
                          child: venue.photoUrl == null ? const Icon(Icons.stadium_outlined) : null,
                        ),
                        title: Row(
                          children: [
                            Flexible(child: Text(venue.name, overflow: TextOverflow.ellipsis)),
                            if (venue.pitchType != null) ...[
                              const SizedBox(width: 6),
                              _PitchTypeBadge(pitchType: venue.pitchType!),
                            ],
                            if (venue.status == VenueStatus.inactive) ...[
                              const SizedBox(width: 6),
                              const _InactiveBadge(),
                            ],
                          ],
                        ),
                        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Availability',
                              icon: const Icon(Icons.calendar_month_outlined),
                              onPressed: () => context.push(venueAvailabilityPath(venue.id), extra: venue),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (action) {
                                switch (action) {
                                  case 'edit':
                                    _addOrEdit(context, ref, organizationId, existing: venue);
                                  case 'delete':
                                    _delete(context, ref, organizationId, venue);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _addOrEdit(context, ref, organizationId, existing: venue),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(error is ApiException ? error.message : 'Failed to load venues'),
              ),
            ),
      floatingActionButton: organizationId == null
          ? null
          : FloatingActionButton(
              tooltip: 'Add venue',
              onPressed: () => _addOrEdit(context, ref, organizationId),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _PitchTypeBadge extends StatelessWidget {
  const _PitchTypeBadge({required this.pitchType});

  final String pitchType;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        pitchType,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: colorScheme.onSecondaryContainer),
        overflow: TextOverflow.ellipsis,
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
