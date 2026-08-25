import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../players/data/models/player.dart';
import '../../teams/data/models/roster_entry.dart';
import '../../teams/data/models/team.dart';
import '../application/player_dashboard_providers.dart';

/// Bottom-nav Team tab — the caller's own team roster/squad for the
/// tournament they're rostered on (see [myTeamMembershipProvider]). A
/// read-only view of the same data `TeamSquadTab`
/// (features/teams/presentation/widgets/team_squad_tab.dart) shows admins,
/// minus its popup-menu edit actions — captain/vice-captain/jersey/
/// wicketkeeper are shown as plain badges here, not editable.
///
/// Shows an honest empty state — never a fabricated team — when membership
/// can't be resolved. See that provider's doc comment for why that can
/// genuinely happen even for an approved, applied player: roster assignment
/// happens via the admin-side auction flow, which can lag well behind
/// approval.
class PlayerTeamTab extends ConsumerWidget {
  const PlayerTeamTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipAsync = ref.watch(myTeamMembershipProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Team'), automaticallyImplyLeading: false),
      body: membershipAsync.when(
        data: (membership) {
          if (membership == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "You haven't been added to a team roster yet. Once an organizer adds you "
                  "to a team's squad, it'll show up here.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myTeamMembershipProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TeamHeader(team: membership.team, rosterSize: membership.roster.length),
                const SizedBox(height: 20),
                Text('Squad', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final entry in membership.roster)
                        _RosterTile(entry: entry, isMe: entry.id == membership.myEntry.id),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load your team'),
        ),
      ),
    );
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.team, required this.rosterSize});

  final Team team;
  final int rosterSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundImage: team.logoUrl != null ? NetworkImage(Env.mediaUrl(team.logoUrl!)) : null,
          child: team.logoUrl == null ? const Icon(Icons.shield, size: 30) : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text('$rosterSize player${rosterSize == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _RosterTile extends StatelessWidget {
  const _RosterTile({required this.entry, required this.isMe});

  final RosterEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final player = entry.player;
    return Container(
      color: isMe ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              player.photoUrl != null ? NetworkImage(Env.mediaUrl(player.photoUrl!)) : null,
          child: player.photoUrl == null ? const Icon(Icons.person) : null,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                isMe ? '${player.fullName} (You)' : player.fullName,
                overflow: TextOverflow.ellipsis,
                style: isMe ? const TextStyle(fontWeight: FontWeight.bold) : null,
              ),
            ),
            if (entry.jerseyNumber != null) ...[
              const SizedBox(width: 6),
              _Badge(label: '#${entry.jerseyNumber}', color: Colors.blueGrey),
            ],
            if (entry.isCaptain) ...[
              const SizedBox(width: 6),
              const _Badge(label: 'C', color: Colors.amber),
            ],
            if (entry.isViceCaptain) ...[
              const SizedBox(width: 6),
              const _Badge(label: 'VC', color: Colors.teal),
            ],
            if (entry.isWicketkeeper) ...[
              const SizedBox(width: 6),
              const _Badge(label: 'WK', color: Colors.deepPurple),
            ],
          ],
        ),
        subtitle: Text(player.role.label),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
