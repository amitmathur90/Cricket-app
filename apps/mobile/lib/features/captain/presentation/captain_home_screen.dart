import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../practice/application/practice_providers.dart';
import '../../practice/presentation/widgets/practice_sessions_tab.dart';
import '../../teams/data/models/team.dart';
import '../application/captain_providers.dart';
import 'widgets/captain_home_tab.dart';
import 'widgets/captain_matches_tab.dart';
import 'widgets/captain_profile_tab.dart';
import 'widgets/captain_squad_tab.dart';

/// Home shell for a `team_owner`-role user (the `/captain` shell) —
/// consolidates the Captain Management functionality already built across
/// the admin-side team/match screens (Squad/Captain tabs, Playing XI
/// selection, matches, practice) into a single Captain-focused app with the
/// spec's 5-tab bottom nav: Home | Squad | Matches | Practice | Profile.
/// Parallel to [playerHomePath]/[adminHomePath] for the `player`/other-role
/// shells (see `core/router/app_router.dart`'s redirect logic).
///
/// A `team_owner` maps to a specific [Team] via `Team.ownerUserId` — the
/// caller's own id (see `captainOwnedTeamsProvider`'s doc comment; there is
/// no dedicated "my teams" endpoint). If the owner captains more than one
/// team, a picker in the app bar lets them switch; with exactly one, it's
/// auto-selected.
class CaptainHomeScreen extends ConsumerStatefulWidget {
  const CaptainHomeScreen({super.key});

  @override
  ConsumerState<CaptainHomeScreen> createState() => _CaptainHomeScreenState();
}

class _CaptainHomeScreenState extends ConsumerState<CaptainHomeScreen> {
  int _tabIndex = 0;

  void _goToTab(int index) => setState(() => _tabIndex = index);

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(captainOwnedTeamsProvider);

    return teamsAsync.when(
      data: (teams) {
        if (teams.isEmpty) {
          return const _NoTeamScaffold();
        }
        final selectedId = ref.watch(selectedCaptainTeamIdProvider);
        final team = teams.firstWhere((t) => t.id == selectedId, orElse: () => teams.first);
        return _CaptainShell(
          team: team,
          teams: teams,
          tabIndex: _tabIndex,
          onTabChanged: _goToTab,
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Captain')),
        body: Center(
          child: Text(error is ApiException ? error.message : 'Failed to load your team'),
        ),
      ),
    );
  }
}

class _CaptainShell extends ConsumerWidget {
  const _CaptainShell({
    required this.team,
    required this.teams,
    required this.tabIndex,
    required this.onTabChanged,
  });

  final Team team;
  final List<Team> teams;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;

  static const _titles = ['Home', 'Squad', 'Matches', 'Practice', 'Profile'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final practiceKey = (teamId: team.id, status: null);

    final pages = [
      CaptainHomeTab(
        team: team,
        onOpenSquad: () => onTabChanged(1),
        onOpenMatches: () => onTabChanged(2),
      ),
      CaptainSquadTab(team: team),
      CaptainMatchesTab(team: team),
      PracticeSessionsTab(teamId: team.id),
      CaptainProfileTab(team: team, onOpenSquad: () => onTabChanged(1)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[tabIndex]),
        automaticallyImplyLeading: false,
        actions: [
          if (teams.length > 1)
            PopupMenuButton<String>(
              tooltip: 'Switch team',
              icon: const Icon(Icons.groups_2_outlined),
              onSelected: (teamId) {
                ref.read(selectedCaptainTeamIdProvider.notifier).state = teamId;
                // A different team likely has different tournament
                // registrations, so any provider keyed off the previous
                // team's practice-session list won't auto-refresh —
                // invalidate it explicitly (Squad/Matches use
                // .autoDispose.family providers keyed by the new team's own
                // id, so those refetch naturally without this).
                ref.invalidate(practiceSessionsListProvider(practiceKey));
              },
              itemBuilder: (context) => [
                for (final t in teams)
                  PopupMenuItem(
                    value: t.id,
                    child: Row(
                      children: [
                        if (t.id == team.id) const Icon(Icons.check, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(t.name, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: IndexedStack(index: tabIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: onTabChanged,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Squad'),
          NavigationDestination(
              icon: Icon(Icons.sports_cricket_outlined),
              selectedIcon: Icon(Icons.sports_cricket),
              label: 'Matches'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'Practice'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

/// Shown when the signed-in `team_owner` doesn't own any org-level team yet
/// (`Team.ownerUserId` never set to their id) — nothing else in this shell
/// has anything to show without a team, so this is the whole screen rather
/// than an empty state buried in one tab.
class _NoTeamScaffold extends ConsumerWidget {
  const _NoTeamScaffold();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Captain'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined, size: 48, color: Theme.of(context).disabledColor),
              const SizedBox(height: 16),
              const Text(
                'You aren\'t set as the owner of any team yet. Ask your organization admin to '
                'assign you as a team\'s owner to unlock the Captain App.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
