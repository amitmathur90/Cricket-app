import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';

final quickMatchApiClientProvider = Provider<ApiClient>((ref) => ref.watch(apiClientProvider));

/// The caller's org-wide hidden "Quick Match" tournament id — created on
/// first use by the backend (`GET .../quick-matches/tournament`, see
/// QuickMatchService) and reused for every subsequent quick match. Once
/// resolved, every other Quick Match action (team creation/registration,
/// roster, match creation, lineup, scoring) just uses this id with the
/// exact same tournament-scoped endpoints the normal admin flow uses.
final quickMatchTournamentIdProvider = FutureProvider.autoDispose<String>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  final response =
      await ref.watch(quickMatchApiClientProvider).get('/organizations/$organizationId/quick-matches/tournament');
  return (response.data as Map<String, dynamic>)['id'] as String;
});
