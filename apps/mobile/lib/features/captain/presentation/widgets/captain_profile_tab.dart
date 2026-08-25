import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/session_controller.dart';
import '../../../teams/data/models/team.dart';
import 'send_announcement_dialog.dart';

/// Profile tab for the Captain App — account info, sign-out, "Captain
/// announcements" (send a notice to the squad), and a link to "Team
/// statistics".
///
/// Team statistics gap: there is no team-level/aggregate statistics
/// endpoint anywhere in the backend (only `GET .../players/:playerId/
/// statistics`, a per-player career aggregate — see
/// `PlayersController.getStatistics`). Rather than fabricate a team rollup
/// client-side from per-player stats (which would silently misrepresent
/// partial data — e.g. a mid-season transfer's stats from a different team),
/// this is honest about the gap: it links to the Squad tab, where tapping
/// any player already opens their real `PlayerStatisticsScreen`.
class CaptainProfileTab extends ConsumerWidget {
  const CaptainProfileTab({super.key, required this.team, required this.onOpenSquad});

  final Team team;
  final VoidCallback onOpenSquad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final user = session.user;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 28)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'Captain',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (user?.email != null) Text(user!.email),
                      Text('Captain · ${team.name}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('Captain announcements'),
            subtitle: const Text('Send a message to squad members with an account'),
            onTap: () => showSendAnnouncementDialog(context, ref, team: team),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Team statistics'),
            subtitle: const Text('No team-level stats endpoint yet — view a player\'s stats from Squad'),
            onTap: onOpenSquad,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}
