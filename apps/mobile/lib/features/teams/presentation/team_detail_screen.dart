import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../application/teams_providers.dart';
import '../data/models/team.dart';
import 'widgets/team_auction_tab.dart';
import 'widgets/team_captain_tab.dart';
import 'widgets/team_coach_tab.dart';
import 'widgets/team_matches_tab.dart';
import 'widgets/team_overview_tab.dart';
import 'widgets/team_placeholder_tab.dart';
import 'widgets/team_squad_tab.dart';

/// Team detail — Overview, Squad, Captain, Coach, Matches, Statistics,
/// Auction, Finance tabs, translating the reference mockup's team-management
/// spec onto this app's actual data model.
///
/// Reality check (see also each tab widget's own doc comment):
/// - `Team` is an org-level "brand"; a team's roster/purse only exist per
///   *tournament* via `tournament_teams`/`team_players` (see those entities'
///   doc comments). This screen is only ever reached from within one
///   tournament's Teams tab, so [tournamentId] scopes the Auction tab.
/// - Overview is real (Team's own fields + its organization).
/// - Squad and Captain are real: `TeamsController.getRoster` (`GET
///   .../teams/:teamId/tournaments/:tournamentId/roster`) and the roster-entry
///   `PATCH` (captain/vice-captain/jersey/wicketkeeper) now exist, so
///   TeamSquadTab/TeamCaptainTab call them directly using this screen's own
///   [teamId]/[tournamentId] — no name-matching workaround needed here,
///   unlike TeamAuctionTab/TeamMatchesTab, which lack a direct
///   teamId->tournamentTeamId lookup for a different reason (see their doc
///   comments).
/// - Matches is real: the fixture-scheduling backend/UI exists now (see
///   features/matches), so this tab filters that tournament's matches list
///   down to fixtures involving this team (see TeamMatchesTab's doc comment
///   for how that filtering works, given the same missing
///   teamId->tournamentTeamId lookup Auction already has to work around).
/// - Coach is real now too: the practice-management backend/UI exists (see
///   features/practice), and this tab shows this team's practice sessions
///   (see TeamCoachTab's doc comment for why practice sessions, not a
///   direct team->coach field, is what actually backs this tab).
/// - Statistics, Finance have no backing data or endpoints at all (out of
///   MVP scope) — same "Soon" treatment as AdminDrawer's not-yet-built
///   items.
/// - Auction is real: it reuses the existing auction report endpoint,
///   scoped to this team (see TeamAuctionTab's doc comment for how the
///   team-name-based matching works, given there's no direct
///   teamId->tournamentTeamId lookup either).
class TeamDetailScreen extends ConsumerWidget {
  const TeamDetailScreen({
    super.key,
    required this.tournamentId,
    required this.teamId,
    this.initialTeam,
  });

  final String tournamentId;
  final String teamId;

  /// Passed via go_router `extra` by TeamListTab, which already has this
  /// loaded — avoids a redundant fetch. Null on a cold deep-link, in which
  /// case [teamDetailProvider] fetches it by id instead.
  final Team? initialTeam;

  static const _tabs = [
    Tab(text: 'Overview'),
    Tab(text: 'Squad'),
    Tab(text: 'Captain'),
    Tab(text: 'Coach'),
    Tab(text: 'Matches'),
    Tab(text: 'Statistics'),
    Tab(text: 'Auction'),
    Tab(text: 'Finance'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = initialTeam;

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(team?.name ?? 'Team'),
          bottom: const TabBar(isScrollable: true, tabs: _tabs),
        ),
        body: team != null ? _TabViews(team: team, tournamentId: tournamentId) : _FetchTeam(
          teamId: teamId,
          tournamentId: tournamentId,
        ),
      ),
    );
  }
}

class _FetchTeam extends ConsumerWidget {
  const _FetchTeam({required this.teamId, required this.tournamentId});

  final String teamId;
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamDetailProvider(teamId));
    return teamAsync.when(
      data: (team) => _TabViews(team: team, tournamentId: tournamentId),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(error is ApiException ? error.message : 'Failed to load team'),
      ),
    );
  }
}

class _TabViews extends StatelessWidget {
  const _TabViews({required this.team, required this.tournamentId});

  final Team team;
  final String tournamentId;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: [
        TeamOverviewTab(team: team),
        TeamSquadTab(team: team, tournamentId: tournamentId),
        TeamCaptainTab(team: team, tournamentId: tournamentId),
        TeamCoachTab(team: team),
        TeamMatchesTab(team: team, tournamentId: tournamentId),
        const TeamPlaceholderTab(
          icon: Icons.bar_chart_outlined,
          title: 'Statistics',
          message: 'Live-scoring-derived statistics are coming soon.',
        ),
        TeamAuctionTab(team: team, tournamentId: tournamentId),
        const TeamPlaceholderTab(
          icon: Icons.payments_outlined,
          title: 'Finance',
          message: 'Team finance tracking is coming soon.',
        ),
      ],
    );
  }
}
