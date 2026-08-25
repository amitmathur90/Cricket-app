import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../tournaments/data/models/tournament.dart' show TournamentFormatX;
import '../application/public_providers.dart';

/// `GET public/organizations/:organizationId/tournaments/:tournamentId`
/// (basic info) plus jump-in tiles for this tournament's Teams/Fixtures &
/// Results/Points Table — the public-section equivalent of
/// `TournamentDetailScreen`'s tab bar, but as separate pushed screens rather
/// than tabs (this section has far fewer per-tournament sub-views than the
/// admin one — no Players/Applications/Auction/Finance tabs, all of which
/// are admin-only concerns).
class PublicTournamentDetailScreen extends ConsumerWidget {
  const PublicTournamentDetailScreen({
    super.key,
    required this.organizationId,
    required this.tournamentId,
  });

  final String organizationId;
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = (organizationId: organizationId, tournamentId: tournamentId);
    final tournamentAsync = ref.watch(publicTournamentProvider(scope));

    return Scaffold(
      appBar: AppBar(title: const Text('Tournament')),
      body: tournamentAsync.when(
        data: (tournament) {
          final start = DateTime.tryParse(tournament.startDate);
          final end = DateTime.tryParse(tournament.endDate);
          final dateFormat = DateFormat.yMMMd();
          final dateRange = (start != null && end != null)
              ? '${dateFormat.format(start)} – ${dateFormat.format(end)}'
              : '${tournament.startDate} to ${tournament.endDate}';

          return RefreshIndicator(
            onRefresh: () => ref.refresh(publicTournamentProvider(scope).future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: tournament.logoUrl != null
                          ? NetworkImage(Env.mediaUrl(tournament.logoUrl!))
                          : null,
                      child: tournament.logoUrl == null ? const Icon(Icons.emoji_events, size: 28) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tournament.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text('${tournament.format.label} · $dateRange'),
                        ],
                      ),
                    ),
                  ],
                ),
                if ((tournament.location ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 6),
                      Expanded(child: Text(tournament.location!)),
                    ],
                  ),
                ],
                if ((tournament.organizerName ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Organized by ${tournament.organizerName}')),
                    ],
                  ),
                ],
                if ((tournament.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(tournament.description!),
                ],
                const SizedBox(height: 24),
                _NavTile(
                  icon: Icons.groups_outlined,
                  label: 'Teams',
                  onTap: () => context.push(publicTeamsPath(organizationId, tournamentId)),
                ),
                _NavTile(
                  icon: Icons.sports_outlined,
                  label: 'Fixtures & Results',
                  onTap: () => context.push(publicFixturesPath(organizationId, tournamentId)),
                ),
                _NavTile(
                  icon: Icons.leaderboard_outlined,
                  label: 'Points Table',
                  onTap: () => context.push(publicPointsTablePath(organizationId, tournamentId)),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load tournament'),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
