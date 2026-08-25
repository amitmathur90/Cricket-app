import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../matches/application/matches_providers.dart';
import '../../matches/data/models/match.dart';
import '../../players/data/models/player.dart';
import '../../practice/application/practice_providers.dart';
import '../../practice/data/models/practice_session.dart';
import '../../teams/application/teams_providers.dart';
import '../../teams/data/models/roster_entry.dart';
import '../../teams/data/models/team.dart';
import '../../tournament_applications/application/tournament_applications_providers.dart';
import '../../tournament_applications/data/models/tournament_application.dart';

// Providers that back the player bottom-nav shell (Home / Matches / Team /
// Stats / Profile — see PlayerShellScreen) with the one piece of context
// none of them can get for free: *which* Player profile and *which* team
// the signed-in `player`-role user actually is.
//
// *** Genuine backend/data gap, documented once here ***: there is no
// `GET /me/player` (or similar) endpoint, and neither `SafeUser` nor the JWT
// claims carry a `playerId`/`teamId`. The only client-visible link from the
// logged-in `User` to a `Player` profile is `GET .../applications/mine`
// (`myApplicationsProvider`, tournament_applications feature), which the
// backend populates with the nested `player` relation — see
// [myPlayerProvider] below. Beyond that, there is also no endpoint that goes
// "player X -> which tournament-team". `TeamsService.getRoster` only goes
// the other way (teamId + tournamentId -> roster), matching what
// `TeamMatchesTab`/`TeamAuctionTab`/`tournamentTeamsProvider` already
// document as the same missing-lookup shape elsewhere in this app. See
// [myTeamMembershipProvider] for how that's worked around (bounded fan-out,
// same technique `_orgApplicationsProvider` in DashboardOverview already
// uses for an analogous gap) and where it honestly gives up instead.

/// The signed-in user's own [Player] profile in the active org, resolved
/// from [myApplicationsProvider] rather than a dedicated fetch — `GET
/// .../applications/mine` already eager-loads the `player` relation on every
/// application (see `TournamentApplication`'s doc comment), so this is free.
///
/// Prefers the player attached to an *approved* application (the caller's
/// real registered profile); falls back to the most recent application of
/// any status when none is approved yet, since `TournamentApplicationsRepository
/// .apply`'s doc comment notes a caller who already has a `Player` profile
/// in the org gets that same profile attached regardless of the new
/// application's review outcome. Null if the caller has never applied to
/// anything in this org (no `Player` profile exists for them yet).
final myPlayerProvider = FutureProvider.autoDispose<Player?>((ref) async {
  final applications = await ref.watch(myApplicationsProvider.future);
  final withPlayer = applications.where((a) => a.player != null).toList()
    ..sort((a, b) {
      final aApproved = a.status == TournamentApplicationStatus.approved;
      final bApproved = b.status == TournamentApplicationStatus.approved;
      if (aApproved != bApproved) return aApproved ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
  return withPlayer.isEmpty ? null : withPlayer.first.player;
});

/// The tournament the caller most recently applied to, in the active org —
/// the spec-mandated fallback context ("the player's org's most-recently-
/// applied-to tournament") for Matches/Home when [myTeamMembershipProvider]
/// can't pin down an actual team (e.g. approved but not yet rostered onto a
/// team by an admin — roster assignment happens via the auction flow, which
/// can lag well behind approval).
final myPrimaryTournamentIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  final applications = await ref.watch(myApplicationsProvider.future);
  if (applications.isEmpty) return null;
  final sorted = [...applications]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted.first.tournamentId;
});

/// One org team's roster for one tournament — the unit [myTeamMembershipProvider]
/// fans out over.
typedef _TeamRosterResult = ({Team team, List<RosterEntry> roster});

/// The caller's resolved team membership: which org [Team] they're actually
/// rostered onto for [myPrimaryTournamentIdProvider]'s tournament, plus that
/// team's full roster and the caller's own [RosterEntry] within it (captain
/// flag, jersey number, etc).
typedef MyTeamMembership = ({
  String tournamentId,
  Team team,
  List<RosterEntry> roster,
  RosterEntry myEntry,
});

/// Resolves [MyTeamMembership] by brute-force: fetch every org team (already
/// a cheap, unpaginated call everywhere else in this app — see
/// `teamsListProvider`), then fetch each one's roster for the resolved
/// tournament *in parallel* and keep whichever roster actually lists
/// [myPlayerProvider]'s id. This mirrors `_orgApplicationsProvider` in
/// `DashboardOverview` (features/tournaments/presentation/widgets/
/// dashboard_overview.dart), which fans out the exact same way over every
/// tournament for the analogous "no org-wide listing endpoint" gap — this
/// isn't a one-off hack, it's the established pattern this codebase already
/// reaches for when a reverse lookup is missing.
///
/// A per-team roster fetch that errors (typically: that team was never
/// registered for this tournament, so there's no `tournament_teams` row to
/// resolve) is swallowed rather than surfaced — "not on this particular
/// team" is the expected outcome for most of the org's teams, not a failure.
///
/// Returns `null` when no team can be resolved (no active org, the caller
/// has never applied to anything, or — very plausibly — they've been
/// approved but an admin hasn't rostered them onto a team yet). Every screen
/// that depends on this degrades gracefully rather than fabricating a team:
/// [playerRelevantMatchesProvider] falls back to the whole tournament's
/// schedule (clearly flagged via its `teamScoped` field), and the Team tab /
/// [playerUpcomingPracticeProvider] (which has no tournament-level fallback
/// available at all — practice sessions are purely team-scoped) show an
/// honest "not on a team yet" empty state.
final myTeamMembershipProvider = FutureProvider.autoDispose<MyTeamMembership?>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  final player = await ref.watch(myPlayerProvider.future);
  final tournamentId = await ref.watch(myPrimaryTournamentIdProvider.future);
  if (organizationId == null || player == null || tournamentId == null) return null;

  final teams = await ref.watch(teamsListProvider.future);
  if (teams.isEmpty) return null;

  final teamsRepository = ref.watch(teamsRepositoryProvider);
  final results = await Future.wait<_TeamRosterResult?>(
    teams.map((team) async {
      try {
        final roster = await teamsRepository.getRoster(organizationId, team.id, tournamentId);
        return (team: team, roster: roster);
      } on ApiException {
        return null;
      }
    }),
  );

  for (final result in results) {
    if (result == null) continue;
    for (final entry in result.roster) {
      if (entry.playerId == player.id) {
        return (
          tournamentId: tournamentId,
          team: result.team,
          roster: result.roster,
          myEntry: entry,
        );
      }
    }
  }
  return null;
});

/// [playerRelevantMatchesProvider]'s result: the resolved match list plus
/// whether it was actually filterable down to the caller's own team
/// ([teamScoped]) or is the tournament-wide fallback — Home/Matches use
/// [teamScoped] to caption the data honestly instead of implying every match
/// shown is specifically the caller's.
typedef PlayerMatches = ({List<Match> matches, bool teamScoped, String? tournamentId});

/// The caller's relevant matches: if [myTeamMembershipProvider] resolves a
/// team, this is that team's fixtures within its tournament (matched by
/// resolved team *name* against `homeTeamName`/`awayTeamName`, the exact
/// same technique `TeamMatchesTab` already uses and documents — there's no
/// direct `tournamentTeamId` to filter by once a team is known). Otherwise
/// this falls back to the whole [myPrimaryTournamentIdProvider] tournament's
/// schedule, unfiltered.
final playerRelevantMatchesProvider = FutureProvider.autoDispose<PlayerMatches>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  final membership = await ref.watch(myTeamMembershipProvider.future);
  final tournamentId =
      membership?.tournamentId ?? await ref.watch(myPrimaryTournamentIdProvider.future);
  if (organizationId == null || tournamentId == null) {
    return (matches: const <Match>[], teamScoped: false, tournamentId: tournamentId);
  }

  final all = await ref.watch(matchesRepositoryProvider).list(organizationId, tournamentId);
  if (membership == null) {
    return (matches: all, teamScoped: false, tournamentId: tournamentId);
  }

  final teamName = membership.team.name.trim().toLowerCase();
  final filtered = all
      .where(
        (m) =>
            (m.homeTeamName?.trim().toLowerCase() ?? '') == teamName ||
            (m.awayTeamName?.trim().toLowerCase() ?? '') == teamName,
      )
      .toList();
  return (matches: filtered, teamScoped: true, tournamentId: tournamentId);
});

/// The caller's team's practice sessions. Unlike matches, there is no
/// tournament-wide fallback available here at all — practice sessions are
/// purely team-scoped (`GET .../teams/:teamId/practice-sessions`, no
/// tournament dimension, see `PracticeSessionsRepository`'s doc comment), so
/// this returns empty until [myTeamMembershipProvider] resolves a real team.
final playerUpcomingPracticeProvider = FutureProvider.autoDispose<List<PracticeSession>>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  final membership = await ref.watch(myTeamMembershipProvider.future);
  if (organizationId == null || membership == null) return const [];
  return ref.watch(practiceSessionsRepositoryProvider).list(organizationId, membership.team.id);
});
