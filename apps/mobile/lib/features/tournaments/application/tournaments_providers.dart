import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/models/points_table_row.dart';
import '../data/models/tournament.dart';
import '../data/models/tournament_awards.dart';
import '../data/tournaments_repository.dart';

final tournamentsRepositoryProvider = Provider<TournamentsRepository>((ref) {
  return TournamentsRepository(ref.watch(apiClientProvider));
});

/// Tournaments for the caller's active org. Empty (rather than an error)
/// when there's no active org yet — the router won't reach a screen that
/// uses this before org selection completes, but this keeps it safe.
final tournamentsListProvider = FutureProvider.autoDispose<List<Tournament>>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(tournamentsRepositoryProvider).list(organizationId);
});

final tournamentDetailProvider =
    FutureProvider.autoDispose.family<Tournament, String>((ref, tournamentId) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(tournamentsRepositoryProvider).getById(organizationId, tournamentId);
});

/// Computed standings for the Points Table tab — no role restriction on the
/// backend route (any authenticated org member may view it), so this is
/// fetched the same way for every caller of TournamentDetailScreen.
final pointsTableProvider =
    FutureProvider.autoDispose.family<List<PointsTableRow>, String>((ref, tournamentId) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(tournamentsRepositoryProvider).getPointsTable(organizationId, tournamentId);
});

/// Computed awards for the Awards tab — same no-role-restriction, derived-
/// on-read shape as [pointsTableProvider].
final tournamentAwardsProvider =
    FutureProvider.autoDispose.family<TournamentAwardsResponse?, String>((ref, tournamentId) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return null;
  return ref.watch(tournamentsRepositoryProvider).getAwards(organizationId, tournamentId);
});
