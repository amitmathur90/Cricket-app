import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/models/practice_attendance.dart';
import '../data/models/practice_session.dart';
import '../data/practice_attendance_repository.dart';
import '../data/practice_sessions_repository.dart';

final practiceSessionsRepositoryProvider = Provider<PracticeSessionsRepository>((ref) {
  return PracticeSessionsRepository(ref.watch(apiClientProvider));
});

final practiceAttendanceRepositoryProvider = Provider<PracticeAttendanceRepository>((ref) {
  return PracticeAttendanceRepository(ref.watch(apiClientProvider));
});

typedef PracticeSessionsListKey = ({String teamId, String? status});

/// All practice sessions for one team, optionally filtered by status —
/// mirrors [matchesListProvider]. Not currently driven by any status filter
/// UI (PracticeSessionsTab fetches everything and filters Upcoming/Past
/// client-side, same as MatchesTab) but kept as part of the provider's
/// contract since the backend route supports it.
final practiceSessionsListProvider =
    FutureProvider.autoDispose.family<List<PracticeSession>, PracticeSessionsListKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(practiceSessionsRepositoryProvider).list(
        organizationId,
        key.teamId,
        status: key.status,
      );
});

typedef PracticeSessionKey = ({String teamId, String sessionId});

final practiceSessionDetailProvider =
    FutureProvider.autoDispose.family<PracticeSession, PracticeSessionKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(practiceSessionsRepositoryProvider).get(organizationId, key.teamId, key.sessionId);
});

/// Marked attendance rows for one session — only players who have actually
/// been marked appear here (see [PracticeAttendance]'s doc comment); a
/// player with no row is "not yet marked", which PracticeAttendanceScreen
/// renders by diffing this list against the org's full player list.
final practiceAttendanceProvider =
    FutureProvider.autoDispose.family<List<PracticeAttendance>, PracticeSessionKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(practiceAttendanceRepositoryProvider).get(organizationId, key.teamId, key.sessionId);
});
