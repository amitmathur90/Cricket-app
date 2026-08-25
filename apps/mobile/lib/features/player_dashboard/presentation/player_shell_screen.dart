import 'package:flutter/material.dart';

import 'home_tab.dart';
import 'matches_tab.dart';
import 'profile_tab.dart';
import 'stats_tab.dart';
import 'team_tab.dart';

/// The player-facing app's shell — a 5-tab bottom nav (Home / Matches /
/// Team / Stats / Profile) that renders at [playerHomePath]
/// (core/router/app_router.dart), replacing the old single-screen
/// `PlayerHomeScreen` (tournament browse/apply only) without changing the
/// route itself or the redirect logic that lands a `player`-role user here.
///
/// Each tab is its own `Scaffold` (own AppBar, own body) held alive in an
/// `IndexedStack` rather than swapped in/out — switching tabs is local
/// widget state, not a route change, so none of go_router's redirect logic
/// needs to know about tabs at all. This mirrors `CaptainHomeScreen`'s shell
/// (features/captain), the same shape for the `team_owner` role.
///
/// The pre-existing tournament browse/apply functionality
/// (`PlayerTournamentsScreen`, features/tournament_applications) isn't one
/// of the 5 tabs — it's still fully reachable, via a "Tournaments" section
/// on the Home tab that pushes it as a sub-screen (see [playerTournamentsPath]).
class PlayerShellScreen extends StatefulWidget {
  const PlayerShellScreen({super.key});

  @override
  State<PlayerShellScreen> createState() => _PlayerShellScreenState();
}

class _PlayerShellScreenState extends State<PlayerShellScreen> {
  int _index = 0;

  void _goToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    // Built fresh each call (mirrors CaptainHomeScreen's analogous shell)
    // rather than a static const list, so the Home tab's "View Full
    // Schedule" button can jump straight to the Matches tab — the same
    // `onTabChanged`-style callback CaptainHomeTab already uses for its
    // "View Squad"/"View Matches" shortcuts, just routed through this
    // shell's own tab index instead of a route.
    final tabs = [
      PlayerHomeTab(onOpenMatches: () => _goToTab(1)),
      const PlayerMatchesTab(),
      const PlayerTeamTab(),
      const PlayerStatsTab(),
      const PlayerProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.sports_cricket_outlined),
            selectedIcon: Icon(Icons.sports_cricket),
            label: 'Matches',
          ),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Team'),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
