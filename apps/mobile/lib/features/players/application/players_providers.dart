import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/models/player.dart';
import '../data/models/player_statistics.dart';
import '../data/players_repository.dart';

final playersRepositoryProvider = Provider<PlayersRepository>((ref) {
  return PlayersRepository(ref.watch(apiClientProvider));
});

/// Org-level players for the caller's active org (see teams_providers.dart
/// for why this is org-level rather than tournament-roster-scoped in M1).
final playersListProvider = FutureProvider.autoDispose<List<Player>>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(playersRepositoryProvider).list(organizationId);
});

/// A player's career/cross-match statistics — used by
/// `PlayerStatisticsScreen`. Same "playerId only, org resolved from active
/// session" shape as `playerPurchaseHistoryProvider` in auction_providers.dart.
final playerStatisticsProvider =
    FutureProvider.autoDispose.family<PlayerStatistics, String>((ref, playerId) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(playersRepositoryProvider).getStatistics(organizationId, playerId);
});

/// One player's full org-level profile, keyed by playerId (org resolved from
/// the active session, same convention as [playerStatisticsProvider]). Used
/// by the live auction room to enrich the current lot's player display with
/// `battingStyle`/`bowlingStyle` — fields the WS `auction.playerUp`/
/// `auction.stateSync` payloads don't carry (see `PlayersRepository.getOne`).
final playerDetailProvider = FutureProvider.autoDispose.family<Player, String>((ref, playerId) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(playersRepositoryProvider).getOne(organizationId, playerId);
});
