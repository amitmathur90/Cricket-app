import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';
import '../../scoring/application/scoring_providers.dart';
import '../../scoring/data/models/scoring_models.dart';
import 'matches_providers.dart';

/// Read-only data providers backing `MatchCenterScreen`'s tabs (Overview,
/// Scorecard, Commentary, Fall of Wickets, Partnerships) — every one of
/// them is a plain REST GET against endpoints the scoring feature already
/// wraps (`ScoringRepository`), so this file only adds the
/// [MatchDetailKey]-keyed providers, not new repository code.
///
/// Both providers below work for matches with `status: 'live'` AND
/// `status: 'completed'` — neither `getLiveState` nor `getScorecard` gate on
/// match status server-side (see `ScoringRealtimeService`'s doc comment):
/// `getScorecard` is a pure derive-from-ball-log read, and `getLiveState`
/// keeps returning the same shape after `Match.status` flips to `completed`
/// (only `currentOver`/`striker`/`nonStriker` go null/stale once there's no
/// more in-progress over — see this file's screen-side doc comments for how
/// each tab treats that).
///
/// Deliberately NOT using `scoringRoomControllerProvider` (the Socket.IO
/// room) here — that's built for the live, single-ball-at-a-time scoring
/// screen; Match Center is a read-only browse of already-recorded state
/// (frequently for a `completed` match, where there's nothing left to
/// stream), so a one-shot REST fetch per tab-open is the right fit. A
/// completed match's data also never changes underneath the viewer, so
/// there's no live-update need to justify a socket connection here.
final matchScorecardProvider =
    FutureProvider.autoDispose.family<MatchScorecard, MatchDetailKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(scoringRepositoryProvider).getScorecard(organizationId, key.tournamentId, key.matchId);
});

final matchLiveStateProvider =
    FutureProvider.autoDispose.family<LiveScoringState, MatchDetailKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(scoringRepositoryProvider).getLiveState(organizationId, key.tournamentId, key.matchId);
});
