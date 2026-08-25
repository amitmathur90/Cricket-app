import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../tournaments/data/models/tournament.dart' show TournamentFormatX;
import '../application/public_providers.dart';
import '../data/models/public_tournament.dart';

/// `GET public/organizations/:organizationId/tournaments`, rendered as a
/// simple card list — the public-section equivalent of `AdminHomeScreen`'s
/// tournament list, minus anything not public-safe (see `PublicTournament`'s
/// doc comment) and minus any create/edit/delete actions (this section is
/// entirely read-only).
class PublicTournamentListScreen extends ConsumerWidget {
  const PublicTournamentListScreen({super.key, required this.organizationId});

  final String organizationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentsAsync = ref.watch(publicTournamentsProvider(organizationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      body: tournamentsAsync.when(
        data: (tournaments) {
          if (tournaments.isEmpty) {
            return const Center(child: Text('No tournaments published yet.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(publicTournamentsProvider(organizationId).future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tournaments.length,
              itemBuilder: (context, index) => _TournamentTile(
                tournament: tournaments[index],
                onTap: () => context.push(
                  publicTournamentDetailPath(organizationId, tournaments[index].id),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load tournaments'),
        ),
      ),
    );
  }
}

class _TournamentTile extends StatelessWidget {
  const _TournamentTile({required this.tournament, required this.onTap});

  final PublicTournament tournament;
  final VoidCallback onTap;

  static const _statusColors = {
    'draft': Colors.grey,
    'upcoming': Colors.blue,
    'live': Colors.green,
    'completed': Colors.blueGrey,
  };

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(tournament.startDate);
    final end = DateTime.tryParse(tournament.endDate);
    final dateFormat = DateFormat.MMMd();
    final dateRange = (start != null && end != null)
        ? '${dateFormat.format(start)} – ${dateFormat.format(end)}'
        : '${tournament.startDate} to ${tournament.endDate}';
    final statusColor = _statusColors[tournament.status] ?? Colors.grey;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundImage: tournament.logoUrl != null
              ? NetworkImage(Env.mediaUrl(tournament.logoUrl!))
              : null,
          child: tournament.logoUrl == null ? const Icon(Icons.emoji_events) : null,
        ),
        title: Text(tournament.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${tournament.format.label} · $dateRange'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            tournament.status,
            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
