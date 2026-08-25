import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../auth/application/session_controller.dart';
import '../../../players/data/models/player.dart';
import '../../application/roster_actions.dart';
import '../../application/teams_providers.dart';
import '../../data/models/roster_entry.dart';
import '../../data/models/team.dart';

/// Squad tab — this tournament-team's full roster, with per-player captain /
/// vice-captain / jersey-number / wicketkeeper admin actions (a popup menu
/// per row, mirroring PlayerListTab's popup-menu convention) and read-only
/// availability badges sourced from the same `Player.isAvailableFor*` flags
/// PlayerListTab already surfaces — the roster GET's `player` join brings
/// those fields along, so this is real data, not fabricated.
class TeamSquadTab extends ConsumerWidget {
  const TeamSquadTab({super.key, required this.team, required this.tournamentId});

  final Team team;
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
    if (organizationId == null) {
      return const Center(child: Text('No active organization'));
    }

    final key = (teamId: team.id, tournamentId: tournamentId);
    final rosterAsync = ref.watch(rosterProvider(key));
    final actions = RosterActions(
      ref,
      organizationId: organizationId,
      teamId: team.id,
      tournamentId: tournamentId,
    );

    return rosterAsync.when(
      data: (roster) {
        if (roster.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '${team.name} has no roster entries in this tournament yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).disabledColor),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: roster.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) => _RosterTile(entry: roster[index], actions: actions),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(error is ApiException ? error.message : 'Failed to load roster'),
      ),
    );
  }
}

class _RosterTile extends StatelessWidget {
  const _RosterTile({required this.entry, required this.actions});

  final RosterEntry entry;
  final RosterActions actions;

  Future<void> _setJerseyNumber(BuildContext context) async {
    final controller = TextEditingController(text: entry.jerseyNumber?.toString() ?? '');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set jersey number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Jersey number'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(int.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result < 0 || !context.mounted) return;
    await actions.update(context, entry.id, jerseyNumber: result);
  }

  @override
  Widget build(BuildContext context) {
    final player = entry.player;
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            player.photoUrl != null ? NetworkImage(Env.mediaUrl(player.photoUrl!)) : null,
        child: player.photoUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Row(
        children: [
          Flexible(child: Text(player.fullName, overflow: TextOverflow.ellipsis)),
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
      subtitle: Row(
        children: [
          Flexible(child: Text(player.role.label, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          _AvailabilityBadges(player: player),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) {
          switch (action) {
            case 'make_captain':
              actions.update(context, entry.id, isCaptain: true);
            case 'remove_captain':
              actions.update(context, entry.id, isCaptain: false);
            case 'make_vice_captain':
              actions.update(context, entry.id, isViceCaptain: true);
            case 'remove_vice_captain':
              actions.update(context, entry.id, isViceCaptain: false);
            case 'toggle_wicketkeeper':
              actions.update(context, entry.id, isWicketkeeper: !entry.isWicketkeeper);
            case 'jersey':
              _setJerseyNumber(context);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: entry.isCaptain ? 'remove_captain' : 'make_captain',
            child: Text(entry.isCaptain ? 'Remove as captain' : 'Make captain'),
          ),
          PopupMenuItem(
            value: entry.isViceCaptain ? 'remove_vice_captain' : 'make_vice_captain',
            child: Text(entry.isViceCaptain ? 'Remove as vice-captain' : 'Make vice-captain'),
          ),
          PopupMenuItem(
            value: 'toggle_wicketkeeper',
            child: Text(entry.isWicketkeeper ? 'Remove wicketkeeper' : 'Make wicketkeeper'),
          ),
          const PopupMenuItem(value: 'jersey', child: Text('Set jersey number')),
        ],
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

/// Read-only availability display for the Squad tab — reuses the granular
/// `isAvailableForTournaments/Matches/Practice` flags already on `Player`
/// (see player.dart), the same fields PlayerListTab's toggle-setting UI
/// writes to. This widget only reads them; the toggle UI itself stays on
/// the Players tab, not duplicated here.
class _AvailabilityBadges extends StatelessWidget {
  const _AvailabilityBadges({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    if (player.isAvailable) {
      return const SizedBox.shrink();
    }
    return const Tooltip(
      message: 'Marked unavailable',
      child: Icon(Icons.event_busy, size: 16, color: Colors.redAccent),
    );
  }
}
