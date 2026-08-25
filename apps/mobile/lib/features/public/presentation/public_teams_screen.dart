import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../application/public_providers.dart';

/// `GET public/organizations/:organizationId/tournaments/:tournamentId/teams`
/// — name/logo only (see `PublicTeam`'s doc comment), withdrawn teams
/// already excluded server-side.
class PublicTeamsScreen extends ConsumerWidget {
  const PublicTeamsScreen({super.key, required this.organizationId, required this.tournamentId});

  final String organizationId;
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = (organizationId: organizationId, tournamentId: tournamentId);
    final teamsAsync = ref.watch(publicTeamsProvider(scope));

    return Scaffold(
      appBar: AppBar(title: const Text('Teams')),
      body: teamsAsync.when(
        data: (teams) {
          if (teams.isEmpty) {
            return const Center(child: Text('No teams registered yet.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(publicTeamsProvider(scope).future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          team.logoUrl != null ? NetworkImage(Env.mediaUrl(team.logoUrl!)) : null,
                      child: team.logoUrl == null ? const Icon(Icons.shield_outlined) : null,
                    ),
                    title: Text(team.name),
                    subtitle: team.shortCode != null ? Text(team.shortCode!) : null,
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(error is ApiException ? error.message : 'Failed to load teams')),
      ),
    );
  }
}
