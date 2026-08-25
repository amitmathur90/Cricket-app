import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/models/roster_entry.dart';
import '../data/models/team.dart';
import '../data/teams_repository.dart';

final teamsRepositoryProvider = Provider<TeamsRepository>((ref) {
  return TeamsRepository(ref.watch(apiClientProvider));
});

/// Org-level teams for the caller's active org (see spec: the tournament
/// detail screen's Teams tab lists all org-level teams, not a
/// tournament-specific roster — team-to-tournament registration is a later
/// milestone's screen).
final teamsListProvider = FutureProvider.autoDispose<List<Team>>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(teamsRepositoryProvider).list(organizationId);
});

/// Fallback fetch-by-id for [TeamDetailScreen] — normally the screen is
/// opened with the already-loaded [Team] passed via go_router `extra` (see
/// TeamListTab), so this refetch is only hit on a cold deep-link (e.g. after
/// an app restart lands directly on the route without `extra`).
final teamDetailProvider =
    FutureProvider.autoDispose.family<Team, String>((ref, teamId) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(teamsRepositoryProvider).get(organizationId, teamId);
});

typedef RosterKey = ({String teamId, String tournamentId});

/// A tournament-team's roster (squad) — backs the Squad and Captain tabs
/// (see TeamSquadTab/TeamCaptainTab) and the Playing XI selection screen's
/// full-squad checklist (see LineupSelectionScreen).
final rosterProvider =
    FutureProvider.autoDispose.family<List<RosterEntry>, RosterKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(teamsRepositoryProvider).getRoster(organizationId, key.teamId, key.tournamentId);
});
