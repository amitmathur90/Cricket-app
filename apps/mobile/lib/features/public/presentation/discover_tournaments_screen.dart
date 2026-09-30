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

/// `GET public/tournaments` — every organization's public tournaments in one
/// feed, the cross-org counterpart to `PublicTournamentListScreen` (which
/// needs an already-known `organizationId`). Reached from `OrgSelectScreen`'s
/// "Discover tournaments" FAB — the entry point for a user who doesn't
/// belong to any organization yet and wants to find one to register for,
/// rather than creating or joining one by code first.
///
/// Tapping a tournament pushes the *existing* `PublicTournamentDetailScreen`
/// with the `organizationId` this feed supplies per-row — that screen is
/// otherwise unchanged, it just now has a second way to be reached.
class DiscoverTournamentsScreen extends ConsumerWidget {
  const DiscoverTournamentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentsAsync = ref.watch(publicAllTournamentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Discover tournaments')),
      body: tournamentsAsync.when(
        data: (tournaments) {
          if (tournaments.isEmpty) {
            return const Center(child: Text('No public tournaments yet.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(publicAllTournamentsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tournaments.length,
              itemBuilder: (context, index) {
                final tournament = tournaments[index];
                return _DiscoverTile(
                  tournament: tournament,
                  onTap: tournament.organizationId == null
                      ? null
                      : () => context.push(
                            publicTournamentDetailPath(tournament.organizationId!, tournament.id),
                          ),
                );
              },
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

class _DiscoverTile extends StatelessWidget {
  const _DiscoverTile({required this.tournament, required this.onTap});

  final PublicTournament tournament;
  final VoidCallback? onTap;

  static const _statusColors = {
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
        subtitle: Text(
          [
            if ((tournament.organizationName ?? '').isNotEmpty) tournament.organizationName!,
            '${tournament.format.label} · $dateRange',
          ].join('\n'),
        ),
        isThreeLine: (tournament.organizationName ?? '').isNotEmpty,
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
