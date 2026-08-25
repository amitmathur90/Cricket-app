import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../application/teams_providers.dart';
import '../../data/models/team.dart';
import 'add_team_dialog.dart';

/// Lists the caller's org-level teams (not tournament-specific rosters —
/// team-to-tournament registration is a later milestone's screen; see
/// teams_providers.dart) with a button to add a new one. Each team is a
/// card showing what's actually known about it at this point — logo/name
/// only; captain, squad size and purse all require tournament-scoped data
/// (`tournament_teams`/`team_players`) this org-level list doesn't have, and
/// there's no "matches" concept anywhere in this app, so none of those are
/// shown here rather than faking them. Tapping a card (or its "View team"
/// action) opens TeamDetailScreen, scoped to [tournamentId] — that's where
/// the tournament-scoped tabs (Auction, etc.) live.
class TeamListTab extends ConsumerWidget {
  const TeamListTab({super.key, required this.organizationId, required this.tournamentId});

  final String organizationId;
  final String tournamentId;

  Future<void> _addTeam(BuildContext context, WidgetRef ref) async {
    final result = await showAddTeamDialog(context);
    if (result == null) return;
    try {
      await ref
          .read(teamsRepositoryProvider)
          .create(organizationId, name: result.name, shortCode: result.shortCode);
      ref.invalidate(teamsListProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openTeam(BuildContext context, Team team) {
    context.push(teamDetailPath(tournamentId, team.id), extra: team);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamsListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Expanded(child: Text('Org-level teams', style: TextStyle(fontWeight: FontWeight.bold))),
              OutlinedButton.icon(
                onPressed: () => _addTeam(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add team'),
              ),
            ],
          ),
        ),
        Expanded(
          child: teamsAsync.when(
            data: (teams) {
              if (teams.isEmpty) {
                return const Center(child: Text('No teams yet.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: teams.length,
                itemBuilder: (context, index) {
                  final team = teams[index];
                  return _TeamCard(
                    team: team,
                    onTap: () => _openTeam(context, team),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text(error is ApiException ? error.message : 'Failed to load teams'),
            ),
          ),
        ),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.onTap});

  final Team team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage:
                    team.logoUrl != null ? NetworkImage(Env.mediaUrl(team.logoUrl!)) : null,
                child: team.logoUrl == null ? const Icon(Icons.shield_outlined) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (team.shortCode != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          team.shortCode!,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onTap,
                child: const Text('View team'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
