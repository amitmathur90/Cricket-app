import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../application/auction_providers.dart';
import '../data/models/auction_report.dart';

/// Player-by-player auction history for one session: Player | Team | Final
/// Bid | Status, sourced from the same `GET .../report` data
/// AuctionReportScreen already uses (`auctionReportProvider`) — no parallel
/// fetch. SOLD rows show the buying team and final price; every other
/// status (unsold/pending/in_progress) shows "—" for both, since neither
/// field is populated server-side until a sale actually happens
/// (`AuctionPlayerOutcome.soldToTeamName`/`finalPrice` are null).
///
/// Tapping a row pushes [AuctionPlayerBidHistoryScreen] — that player's full
/// bid-by-bid history for this session (`GET .../bids?playerId=`). That
/// endpoint is admin-only as of this pass; see this file's sibling doc
/// comment on AuctionPlayerBidHistoryScreen for how a non-admin caller's 403
/// is handled.
class AuctionHistoryScreen extends ConsumerWidget {
  const AuctionHistoryScreen({super.key, required this.tournamentId, required this.sessionId});

  final String tournamentId;
  final String sessionId;

  AuctionSessionKey get _key => (tournamentId: tournamentId, sessionId: sessionId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(auctionReportProvider(_key));

    return Scaffold(
      appBar: AppBar(title: const Text('Auction history')),
      body: reportAsync.when(
        data: (report) {
          if (report.players.isEmpty) {
            return const Center(child: Text('No players in this auction yet.'));
          }
          return Column(
            children: [
              const _HeaderRow(),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: report.players.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final player = report.players[index];
                    return _PlayerHistoryRow(
                      player: player,
                      onTap: () => context.push(
                        auctionPlayerBidHistoryPath(tournamentId, sessionId, player.playerId),
                        extra: player.playerName,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load auction history'),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted);
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('PLAYER', style: style)),
          Expanded(flex: 2, child: Text('TEAM', style: style)),
          Expanded(flex: 2, child: Text('FINAL BID', style: style, textAlign: TextAlign.end)),
          SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _PlayerHistoryRow extends StatelessWidget {
  const _PlayerHistoryRow({required this.player, required this.onTap});

  final AuctionPlayerOutcome player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSold = player.status == 'sold';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.playerName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _StatusBadge(status: player.status),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                isSold ? (player.soldToTeamName ?? '—') : '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                isSold ? '₹${player.finalPrice}' : '—',
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'sold' => ('SOLD', AppColors.primary),
      'unsold' => ('UNSOLD', AppColors.negative),
      'in_progress' => ('IN PROGRESS', AppColors.info),
      _ => ('PENDING', AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }
}
