import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../auction/application/auction_providers.dart';
import '../../../auction/data/models/auction_report.dart';
import '../../../auction/data/models/auction_session.dart';
import '../../data/models/team.dart';

/// This team's auction standing within one tournament — reuses the same
/// `GET .../auction-sessions/:sessionId/report` data AuctionReportScreen
/// already renders (per-team purse/spend, per-player sold outcomes), just
/// filtered down to this one team and shown for the most recent session.
///
/// There's no direct `teamId -> tournamentTeamId` lookup exposed by the
/// backend (no GET endpoint returns a team's `tournament_teams` row), so the
/// match below is done by team *name* against the report's `teams[]`
/// entries — the same identifier the backend itself surfaces elsewhere
/// (e.g. `soldToTeamName` on bids/pool entries). This is a real limitation,
/// not a fabrication: if two org-level teams shared an identical name, this
/// would show the wrong one, but names aren't meaningfully expected to
/// collide within one org.
class TeamAuctionTab extends ConsumerWidget {
  const TeamAuctionTab({super.key, required this.team, required this.tournamentId});

  final Team team;
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(auctionSessionsListProvider(tournamentId));

    return sessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return _EmptyState(
            icon: Icons.gavel_outlined,
            title: 'No auction sessions yet',
            message: 'This tournament has no auction sessions yet.',
            actionLabel: 'Go to Auction',
            onAction: () => context.push(auctionSessionListPath(tournamentId)),
          );
        }
        // Sessions come back newest-first (see AuctionService.findAll).
        final latest = sessions.first;
        return _SessionReport(
          team: team,
          tournamentId: tournamentId,
          session: latest,
          sessionCount: sessions.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(error is ApiException ? error.message : 'Failed to load auction sessions'),
      ),
    );
  }
}

class _SessionReport extends ConsumerWidget {
  const _SessionReport({
    required this.team,
    required this.tournamentId,
    required this.session,
    required this.sessionCount,
  });

  final Team team;
  final String tournamentId;
  final AuctionSession session;
  final int sessionCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (tournamentId: tournamentId, sessionId: session.id);
    final reportAsync = ref.watch(auctionReportProvider(key));

    return reportAsync.when(
      data: (report) {
        AuctionTeamSummary? summary;
        for (final entry in report.teams) {
          if (entry.teamName.trim().toLowerCase() == team.name.trim().toLowerCase()) {
            summary = entry;
            break;
          }
        }

        if (summary == null) {
          return _EmptyState(
            icon: Icons.block_outlined,
            title: 'Not registered in this tournament',
            message: "${team.name} isn't registered as a participant in this tournament's auction.",
            actionLabel: 'View auction sessions',
            onAction: () => context.push(auctionSessionListPath(tournamentId)),
          );
        }

        final wonPlayers = report.players
            .where(
              (p) =>
                  p.status == 'sold' &&
                  (p.soldToTeamName?.trim().toLowerCase() ?? '') == team.name.trim().toLowerCase(),
            )
            .toList();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Purse', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Stat(label: 'Remaining', value: summary.purseRemaining ?? '—'),
                        _Stat(label: 'Total', value: summary.purseTotal ?? '—'),
                        _Stat(label: 'Spent', value: summary.totalSpent),
                        _Stat(label: 'Players bought', value: '${summary.playersBought}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Players won · ${session.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (wonPlayers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No players won in this session yet.'),
              )
            else
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final player in wonPlayers)
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(player.playerName),
                        trailing: Text(player.finalPrice ?? '—'),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => context.push(auctionReportPath(tournamentId, session.id)),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  sessionCount > 1
                      ? 'View full report ($sessionCount sessions total)'
                      : 'View full report',
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(error is ApiException ? error.message : 'Failed to load auction report'),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).disabledColor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: mutedColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: mutedColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: mutedColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
