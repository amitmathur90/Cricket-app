import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/models/venue.dart';
import '../data/venues_repository.dart';

final venuesRepositoryProvider = Provider<VenuesRepository>((ref) {
  return VenuesRepository(ref.watch(apiClientProvider));
});

/// Org-level venues for the caller's active org — backs the Venues list
/// screen and the match form's venue picker.
final venuesListProvider = FutureProvider.autoDispose<List<Venue>>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(venuesRepositoryProvider).list(organizationId);
});

typedef VenueAvailabilityKey = ({String venueId, DateTime from, DateTime to});

/// Day-by-day availability calendar for one venue over a date range — backs
/// [VenueAvailabilityScreen].
final venueAvailabilityProvider =
    FutureProvider.autoDispose.family<List<VenueAvailabilityDay>, VenueAvailabilityKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(venuesRepositoryProvider).getAvailability(
        organizationId,
        key.venueId,
        from: key.from,
        to: key.to,
      );
});
