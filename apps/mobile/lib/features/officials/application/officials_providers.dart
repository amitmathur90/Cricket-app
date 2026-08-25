import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/models/official.dart';
import '../data/officials_repository.dart';

final officialsRepositoryProvider = Provider<OfficialsRepository>((ref) {
  return OfficialsRepository(ref.watch(apiClientProvider));
});

/// Org-level officials for the caller's active org, optionally filtered by
/// role — backs the Officials list screen's role filter and the match
/// form's umpire/scorer pickers. `null` means "all roles".
final officialsListProvider =
    FutureProvider.autoDispose.family<List<Official>, OfficialRole?>((ref, role) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(officialsRepositoryProvider).list(organizationId, role: role?.value);
});
