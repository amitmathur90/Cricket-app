import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/models/tournament_application.dart';
import '../data/tournament_applications_repository.dart';

final tournamentApplicationsRepositoryProvider =
    Provider<TournamentApplicationsRepository>((ref) {
  return TournamentApplicationsRepository(ref.watch(apiClientProvider));
});

/// The caller's own applications across the active org — backs the player
/// dashboard's per-tournament status ("Not applied" / "Pending" / etc).
final myApplicationsProvider =
    FutureProvider.autoDispose<List<TournamentApplication>>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(tournamentApplicationsRepositoryProvider).listMine(organizationId);
});

/// Admin-only: applications for one tournament, optionally filtered by
/// status — backs the "Applications" review tab on TournamentDetailScreen.
/// Keyed by (tournamentId, status) so switching the filter chip re-fetches
/// (and, being autoDispose, drops the previously-selected filter's cache
/// once nothing is watching it).
final tournamentApplicationsProvider = FutureProvider.autoDispose
    .family<List<TournamentApplication>, ({String tournamentId, TournamentApplicationStatus? status})>(
  (ref, args) async {
    final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
    if (organizationId == null) return const [];
    return ref
        .watch(tournamentApplicationsRepositoryProvider)
        .listForTournament(organizationId, args.tournamentId, status: args.status);
  },
);
