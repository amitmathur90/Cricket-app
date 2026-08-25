import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../application/venues_providers.dart';
import '../data/models/venue.dart';

/// A lightweight day-by-day availability view for one venue — a `ListView`
/// of the next 14 days with each day's available/booked/maintenance status,
/// plus an action to mark a day unavailable ("Maintenance"). Deliberately a
/// grouped list rather than a real calendar grid, same pragmatic choice the
/// Matches feature made for its own schedule view.
class VenueAvailabilityScreen extends ConsumerStatefulWidget {
  const VenueAvailabilityScreen({super.key, required this.venueId, this.initialVenue});

  final String venueId;

  /// Passed by VenuesListScreen, which already has the full Venue loaded —
  /// avoids a redundant fetch just to show the venue name in the app bar.
  final Venue? initialVenue;

  @override
  ConsumerState<VenueAvailabilityScreen> createState() => _VenueAvailabilityScreenState();
}

class _VenueAvailabilityScreenState extends ConsumerState<VenueAvailabilityScreen> {
  static const _rangeDays = 14;

  late final DateTime _from;
  late final DateTime _to;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _from = DateTime(today.year, today.month, today.day);
    _to = _from.add(const Duration(days: _rangeDays - 1));
  }

  Future<void> _addMaintenanceDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: _from,
      lastDate: _from.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark unavailable'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. Maintenance, Ground re-turfing',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark unavailable'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return;

    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(picked);
      final reason = reasonController.text.trim();
      await ref.read(venuesRepositoryProvider).addUnavailability(
            organizationId,
            widget.venueId,
            date: dateKey,
            reason: reason.isEmpty ? null : reason,
          );
      ref.invalidate(
        venueAvailabilityProvider((venueId: widget.venueId, from: _from, to: _to)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final availabilityAsync = ref.watch(
      venueAvailabilityProvider((venueId: widget.venueId, from: _from, to: _to)),
    );
    final dayFormat = DateFormat('EEE, MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialVenue != null ? '${widget.initialVenue!.name} · Availability' : 'Availability'),
      ),
      body: availabilityAsync.when(
        data: (days) {
          if (days.isEmpty) {
            return const Center(child: Text('No availability data.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: days.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final day = days[index];
              final date = DateTime.tryParse(day.date);
              return ListTile(
                title: Text(date != null ? dayFormat.format(date) : day.date),
                trailing: _StatusChip(status: day.status),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load availability'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMaintenanceDay,
        icon: const Icon(Icons.event_busy_outlined),
        label: const Text('Mark unavailable'),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final VenueDayStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color color;
    switch (status) {
      case VenueDayStatus.available:
        color = Colors.green;
      case VenueDayStatus.booked:
        color = colorScheme.error;
      case VenueDayStatus.maintenance:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
