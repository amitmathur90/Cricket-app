import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/session_controller.dart';
import '../application/auction_providers.dart';
import '../data/models/auction_report.dart';
import '../data/models/auction_session.dart';
import 'widgets/live_auction_room_view.dart';
import 'widgets/pool_management_view.dart';

/// Session detail — dispatches to the right view for the session's current
/// status: pool management (`scheduled`), the live room (`live`/`paused`),
/// or an end-of-auction summary (`completed`).
///
/// The "Auction history" and "Team dashboard" app bar actions are this
/// feature's entry points for [AuctionHistoryScreen] and
/// [AuctionTeamDashboardScreen] — shown regardless of status (both read the
/// same `GET .../report` data the completed-session summary and
/// AuctionReportScreen already use, which returns a sensible, if partly
/// empty, shape for a session that hasn't started or is still live) rather
/// than being buried inside only one of the status-specific views below.
class AuctionSessionDetailScreen extends ConsumerWidget {
  const AuctionSessionDetailScreen({super.key, required this.tournamentId, required this.sessionId});

  final String tournamentId;
  final String sessionId;

  AuctionSessionKey get _key => (tournamentId: tournamentId, sessionId: sessionId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
    final sessionAsync = ref.watch(auctionSessionDetailProvider(_key));

    return Scaffold(
      appBar: AppBar(
        title: sessionAsync.when(
          data: (session) => Text(session.name),
          loading: () => const Text('Auction session'),
          error: (error, stackTrace) => const Text('Auction session'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Auction history',
            onPressed: () => context.push(auctionHistoryPath(tournamentId, sessionId)),
          ),
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'Team dashboard',
            onPressed: () => context.push(auctionTeamDashboardPath(tournamentId, sessionId)),
          ),
        ],
      ),
      body: organizationId == null
          ? const Center(child: Text('No active organization'))
          : sessionAsync.when(
              data: (session) => switch (session.status) {
                AuctionSessionStatus.scheduled => PoolManagementView(
                    organizationId: organizationId,
                    tournamentId: tournamentId,
                    sessionId: sessionId,
                  ),
                AuctionSessionStatus.live ||
                AuctionSessionStatus.paused =>
                  LiveAuctionRoomView(
                    organizationId: organizationId,
                    tournamentId: tournamentId,
                    sessionId: sessionId,
                  ),
                AuctionSessionStatus.completed => _CompletedSummary(
                    tournamentId: tournamentId,
                    sessionId: sessionId,
                  ),
                // Defensive fallback — every real AuctionSessionStatus value
                // is already handled above; this only exists so the switch
                // expression is provably exhaustive to the compiler.
                _ => const SizedBox.shrink(),
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(error is ApiException ? error.message : 'Failed to load auction session'),
              ),
            ),
    );
  }
}

/// End-of-auction summary, rendered by [AuctionSessionDetailScreen] once
/// `session.status == 'completed'`. Every figure comes straight off
/// `GET .../report` (`auctionReportProvider`, the same call
/// AuctionReportScreen/AuctionHistoryScreen/AuctionTeamDashboardScreen all
/// share) — nothing here is a stored aggregate of its own, so it can never
/// drift from those other views: Total/Sold/Unsold Players come straight off
/// `players[].length`/`status`, and Teams/Total/Spent/Remaining Points are
/// plain sums over `teams[]`.
class _CompletedSummary extends ConsumerWidget {
  const _CompletedSummary({required this.tournamentId, required this.sessionId});

  final String tournamentId;
  final String sessionId;

  AuctionSessionKey get _key => (tournamentId: tournamentId, sessionId: sessionId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(auctionReportProvider(_key));

    return reportAsync.when(
      data: (report) => _CompletedSummaryBody(
        tournamentId: tournamentId,
        sessionId: sessionId,
        report: report,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(error is ApiException ? error.message : 'Failed to load auction summary'),
      ),
    );
  }
}

class _CompletedSummaryBody extends StatelessWidget {
  const _CompletedSummaryBody({
    required this.tournamentId,
    required this.sessionId,
    required this.report,
  });

  final String tournamentId;
  final String sessionId;
  final AuctionReport report;

  static num _sum(Iterable<String?> values) =>
      values.fold<num>(0, (sum, v) => sum + (num.tryParse(v ?? '') ?? 0));

  static String _fmt(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final totalPlayers = report.players.length;
    final soldPlayers = report.players.where((p) => p.status == 'sold').length;
    final unsoldPlayers = report.players.where((p) => p.status == 'unsold').length;
    final totalTeams = report.teams.length;
    final totalPoints = _sum(report.teams.map((t) => t.purseTotal));
    final pointsSpent = _sum(report.teams.map((t) => t.totalSpent));
    final remainingPoints = _sum(report.teams.map((t) => t.purseRemaining));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.check_circle, size: 48, color: AppColors.primary),
        const SizedBox(height: 12),
        const Text(
          'AUCTION COMPLETED',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.8),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.7,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _SummaryStatCard(label: 'Total Players', value: '$totalPlayers'),
            _SummaryStatCard(label: 'Sold Players', value: '$soldPlayers', color: AppColors.primary),
            _SummaryStatCard(label: 'Unsold Players', value: '$unsoldPlayers', color: AppColors.negative),
            _SummaryStatCard(label: 'Teams', value: '$totalTeams'),
            _SummaryStatCard(label: 'Total Points', value: '₹${_fmt(totalPoints)}'),
            _SummaryStatCard(label: 'Points Spent', value: '₹${_fmt(pointsSpent)}', color: AppColors.amber),
            _SummaryStatCard(
              label: 'Remaining Points',
              value: '₹${_fmt(remainingPoints)}',
              color: AppColors.info,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => context.push(auctionHistoryPath(tournamentId, sessionId)),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Auction history'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push(auctionTeamDashboardPath(tournamentId, sessionId)),
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Team dashboard'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push(auctionReportPath(tournamentId, sessionId)),
              icon: const Icon(Icons.summarize_outlined),
              label: const Text('View report'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: tint),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
