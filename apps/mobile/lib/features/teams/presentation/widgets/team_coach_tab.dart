import 'package:flutter/material.dart';

import '../../../practice/presentation/widgets/practice_sessions_tab.dart';
import '../../data/models/team.dart';

/// TeamDetailScreen's "Coach" tab, repurposed from a "coming soon"
/// placeholder to show this team's real practice sessions.
///
/// There is no direct team -> coach relation on the backend (see
/// `Team`/`Coach`/`PracticeSession` entities) — a coach is assigned per
/// *practice session*, not to a team as a whole, so "this team's assigned
/// coach(es)" surfaces implicitly through each session's own coach field
/// (see PracticeSessionCard) rather than as a separate standalone section
/// here. Keeping the tab under its original "Coach" label (rather than
/// adding a 9th "Practice" tab) matches the existing 8-tab structure the
/// practice-management spec doesn't otherwise dictate a placement for.
class TeamCoachTab extends StatelessWidget {
  const TeamCoachTab({super.key, required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    return PracticeSessionsTab(teamId: team.id);
  }
}
