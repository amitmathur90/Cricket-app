import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/models/sponsor.dart';
import '../data/sponsors_repository.dart';

final sponsorsRepositoryProvider = Provider<SponsorsRepository>((ref) {
  return SponsorsRepository(ref.watch(apiClientProvider));
});

/// Org-level sponsors for the caller's active org — backs the Sponsors list
/// screen.
final sponsorsListProvider = FutureProvider.autoDispose<List<Sponsor>>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(sponsorsRepositoryProvider).list(organizationId);
});
