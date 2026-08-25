import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/models/scoring_lineup.dart';
import '../data/scoring_repository.dart';

final scoringRepositoryProvider = Provider<ScoringRepository>((ref) {
  return ScoringRepository(ref.watch(apiClientProvider));
});

typedef ScoringMatchKey = ({String tournamentId, String matchId});

/// Both teams' Playing XI, with player names resolved — backs every picker
/// in the start/start-innings setup flow and the wicket/new-bowler dialogs.
/// See `ScoringLineupPlayer`'s doc comment for why this is its own fetch
/// rather than reusing `matchLineupProvider` from the matches feature.
final scoringLineupProvider =
    FutureProvider.autoDispose.family<ScoringMatchLineup, ScoringMatchKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(scoringRepositoryProvider).getLineupPlayers(organizationId, key.tournamentId, key.matchId);
});
