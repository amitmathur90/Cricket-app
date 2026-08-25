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

/// Captain tab — the tournament-team's current captain and vice-captain,
/// shown prominently, each with a "Change" action that opens a picker over
/// the same roster the Squad tab manages (reusing `RosterActions` /
/// `rosterProvider` rather than duplicating the mutation logic — see
/// TeamSquadTab, which offers the same actions per-row for finer-grained
/// control).
class TeamCaptainTab extends ConsumerWidget {
  const TeamCaptainTab({super.key, required this.team, required this.tournamentId});

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

        RosterEntry? captain;
        RosterEntry? viceCaptain;
        for (final entry in roster) {
          if (entry.isCaptain) captain = entry;
          if (entry.isViceCaptain) viceCaptain = entry;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _RoleCard(
              title: 'Captain',
              icon: Icons.shield,
              entry: captain,
              onChange: () async {
                final selectedId = await _pickPlayer(
                  context,
                  roster,
                  title: 'Select captain',
                  currentId: captain?.id,
                );
                if (selectedId == null || !context.mounted) return;
                await actions.update(context, selectedId, isCaptain: true);
              },
            ),
            const SizedBox(height: 16),
            _RoleCard(
              title: 'Vice Captain',
              icon: Icons.shield_outlined,
              entry: viceCaptain,
              onChange: () async {
                final selectedId = await _pickPlayer(
                  context,
                  roster,
                  title: 'Select vice-captain',
                  currentId: viceCaptain?.id,
                );
                if (selectedId == null || !context.mounted) return;
                await actions.update(context, selectedId, isViceCaptain: true);
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(error is ApiException ? error.message : 'Failed to load roster'),
      ),
    );
  }
}

Future<String?> _pickPlayer(
  BuildContext context,
  List<RosterEntry> roster, {
  required String title,
  String? currentId,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        for (final entry in roster)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(entry.id),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: entry.id == currentId
                      ? const Icon(Icons.check, size: 18)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.player.fullName)),
              ],
            ),
          ),
      ],
    ),
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.icon,
    required this.entry,
    required this.onChange,
  });

  final String title;
  final IconData icon;
  final RosterEntry? entry;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final player = entry?.player;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(onPressed: onChange, child: const Text('Change')),
              ],
            ),
            const SizedBox(height: 8),
            if (player == null)
              Text(
                'Not assigned',
                style: TextStyle(color: Theme.of(context).disabledColor),
              )
            else
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: player.photoUrl != null
                        ? NetworkImage(Env.mediaUrl(player.photoUrl!))
                        : null,
                    child: player.photoUrl == null ? const Icon(Icons.person, size: 28) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.fullName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(player.role.label),
                        if (entry?.jerseyNumber != null) Text('Jersey #${entry!.jerseyNumber}'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
