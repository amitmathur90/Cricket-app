import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../../matches/application/matches_providers.dart';
import '../../matches/data/models/match.dart';
import '../../teams/application/teams_providers.dart';
import '../../teams/data/models/team.dart';
import '../../tournaments/application/tournaments_providers.dart';
import '../../tournaments/data/models/tournament.dart';
import '../data/captain_notifications_repository.dart';

final captainNotificationsRepositoryProvider = Provider<CaptainNotificationsRepository>((ref) {
  return CaptainNotificationsRepository(ref.watch(apiClientProvider));
});

/// The org-level teams captained by the signed-in user — `Team.ownerUserId
/// == callerId`. There is no backend "my teams" endpoint, so this filters
/// the same org-level teams list TeamListTab already fetches
/// (`TeamsRepository.list`) down to the ones this user owns, which is what
/// the `team_owner` role actually means in this data model (see
/// `Team.ownerUserId`'s doc comment).
final captainOwnedTeamsProvider = FutureProvider.autoDispose<List<Team>>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  final organizationId = session.activeOrgId;
  final userId = session.user?.id;
  if (organizationId == null || userId == null) return const [];
  final teams = await ref.watch(teamsRepositoryProvider).list(organizationId);
  return teams.where((t) => t.ownerUserId == userId).toList();
});

/// Which of [captainOwnedTeamsProvider]'s teams the Captain App is currently
/// showing — null means "not chosen yet" (CaptainHomeScreen auto-selects
/// when there's exactly one, or shows a picker when there's more than one).
final selectedCaptainTeamIdProvider = StateProvider<String?>((ref) => null);

/// Tournaments (within the caller's active org) that [teamId] is actually
/// registered to (i.e. has a `tournament_teams` row).
///
/// There is currently no backend endpoint that lists a team's tournament
/// registrations directly — the same gap `TeamMatchesTab`/`TeamAuctionTab`/
/// `tournamentTeamsProvider` already document for the inverse lookup. This
/// works around it the same way `LineupSelectionScreen` works around its own
/// gap: probe the one endpoint that *is* keyed by (teamId, tournamentId) —
/// `TeamsRepository.getRoster`, which 404s via `TeamsService.getRoster` when
/// the team isn't registered to that tournament — across every tournament in
/// the org, and keep the ones that don't 404. Bounded by the org's
/// tournament count, which is small in practice.
final captainTeamTournamentsProvider =
    FutureProvider.autoDispose.family<List<Tournament>, String>((ref, teamId) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  final tournaments = await ref.watch(tournamentsListProvider.future);
  final teamsRepository = ref.watch(teamsRepositoryProvider);

  final registered = await Future.wait(tournaments.map((tournament) async {
    try {
      await teamsRepository.getRoster(organizationId, teamId, tournament.id);
      return tournament;
    } on ApiException {
      return null;
    }
  }));
  return registered.whereType<Tournament>().toList();
});

/// Picks the "current" tournament to default the Squad tab to when a team is
/// registered to more than one: live beats upcoming beats draft beats
/// completed, ties broken by most recent start date. Exposed as a plain
/// function (not a provider) since it's a pure selection over data
/// [captainTeamTournamentsProvider] already fetched.
Tournament? pickPrimaryTournament(List<Tournament> tournaments) {
  if (tournaments.isEmpty) return null;
  const statusRank = {'live': 0, 'upcoming': 1, 'draft': 2, 'completed': 3};
  final sorted = [...tournaments]
    ..sort((a, b) {
      final rankCompare = (statusRank[a.status] ?? 4).compareTo(statusRank[b.status] ?? 4);
      if (rankCompare != 0) return rankCompare;
      return b.startDate.compareTo(a.startDate);
    });
  return sorted.first;
}

typedef CaptainMatchesKey = ({String teamId, String teamName});

/// This team's matches across every tournament it's registered to (see
/// [captainTeamTournamentsProvider]) — merged and sorted by `scheduledAt`
/// (nulls/TBD last). Matched by team *name* against the match's
/// server-resolved `homeTeamName`/`awayTeamName`, same technique
/// `TeamMatchesTab` already uses for the equivalent single-tournament case
/// (there is no direct `teamId -> tournamentTeamId` lookup — see that
/// widget's doc comment for why name-matching is this app's established
/// workaround, not a one-off shortcut).
final captainMatchesProvider =
    FutureProvider.autoDispose.family<List<Match>, CaptainMatchesKey>((ref, key) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  final tournaments = await ref.watch(captainTeamTournamentsProvider(key.teamId).future);
  if (tournaments.isEmpty) return const [];

  final matchesRepository = ref.watch(matchesRepositoryProvider);
  final lists = await Future.wait(
    tournaments.map((t) => matchesRepository.list(organizationId, t.id)),
  );

  final normalized = key.teamName.trim().toLowerCase();
  final merged = <Match>[
    for (final list in lists)
      ...list.where(
        (m) =>
            (m.homeTeamName?.trim().toLowerCase() ?? '') == normalized ||
            (m.awayTeamName?.trim().toLowerCase() ?? '') == normalized,
      ),
  ];
  merged.sort((a, b) {
    final aDate = a.scheduledAt;
    final bDate = b.scheduledAt;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return aDate.compareTo(bDate);
  });
  return merged;
});

/// True when [match] is this team's home side, based on the same
/// name-matching as [captainMatchesProvider]. Used to resolve which side's
/// `tournamentTeamId` (and therefore which "Select Playing XI" target) is
/// *this* team's, as opposed to the opponent's.
bool matchIsHomeTeam(Match match, String teamName) {
  final normalized = teamName.trim().toLowerCase();
  return (match.homeTeamName?.trim().toLowerCase() ?? '') == normalized;
}
