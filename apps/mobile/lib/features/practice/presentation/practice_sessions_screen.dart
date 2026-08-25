import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../teams/application/teams_providers.dart';
import '../../teams/data/models/team.dart';
import 'widgets/practice_sessions_tab.dart';

/// Standalone practice-sessions screen for one team — the destination of
/// the admin drawer's "Practice" item (see AdminDrawer._openPractice).
/// Practice sessions are team-scoped rather than tournament-scoped (unlike
/// matches), so unlike the drawer's other jump-ins (which land on a tab
/// inside a *tournament's* detail screen), this needs its own top-level
/// route rather than reusing TournamentDetailScreen. Just wraps
/// [PracticeSessionsTab] — the same widget embedded as TeamDetailScreen's
/// "Coach" tab content — in a Scaffold with a team-named app bar.
class PracticeSessionsScreen extends ConsumerWidget {
  const PracticeSessionsScreen({super.key, required this.teamId, this.initialTeam});

  final String teamId;

  /// Passed via go_router `extra` by AdminDrawer, which already has the
  /// team loaded — avoids a redundant fetch. Null on a cold deep-link.
  final Team? initialTeam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamDetailProvider(teamId));
    final teamName = initialTeam?.name ?? teamAsync.value?.name;

    return Scaffold(
      appBar: AppBar(title: Text(teamName != null ? '$teamName · Practice' : 'Practice')),
      body: PracticeSessionsTab(teamId: teamId),
    );
  }
}
