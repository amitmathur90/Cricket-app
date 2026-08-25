import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';

/// The tournament detail screen's "Auction" tab — a simple entry point
/// (rather than embedded list content, unlike the Teams/Players tabs) that
/// navigates to the full-screen auction sessions list for this tournament.
/// Kept as a tab (not just an AppBar button) per the spec, but implemented
/// as a CTA card rather than auto-navigating on tab selection, since
/// auto-navigating away the instant a tab is tapped would fight the
/// TabBar's own back/forward selection state.
class AuctionEntryTab extends StatelessWidget {
  const AuctionEntryTab({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gavel, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Run a live player auction for this tournament.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push(auctionSessionListPath(tournamentId)),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Open auction sessions'),
            ),
          ],
        ),
      ),
    );
  }
}
