import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/coaches_repository.dart';
import '../data/models/coach.dart';

final coachesRepositoryProvider = Provider<CoachesRepository>((ref) {
  return CoachesRepository(ref.watch(apiClientProvider));
});

/// Org-level coaches for the caller's active org — backs the Coaches list
/// screen and the practice session form's coach picker.
final coachesListProvider = FutureProvider.autoDispose<List<Coach>>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(coachesRepositoryProvider).list(organizationId);
});
