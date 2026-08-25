import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auction/presentation/widgets/auction_entry_tab.dart';
import '../../auth/application/session_controller.dart';
import '../../finance/presentation/finance_tab.dart';
import '../../matches/presentation/widgets/matches_tab.dart';
import '../../players/presentation/widgets/player_list_tab.dart';
import '../../teams/presentation/widgets/team_list_tab.dart';
import '../../tournament_applications/presentation/widgets/applications_review_tab.dart';
import '../application/tournaments_providers.dart';
import '../data/models/tournament.dart';
import 'widgets/awards_tab.dart';
import 'widgets/points_table_tab.dart';

/// Tournament detail — Teams, Players, Auction, Applications, Matches,
/// Points Table, Finance, and Awards tabs. Teams/Players list the org's
/// existing teams/players with a simple "add" dialog (see spec: M1 does not
/// yet wire tournament-team registration or roster assignment, those are
/// M2+ screens once fixtures exist). Auction is just an entry point into the
/// full-screen auction sessions flow (see features/auction/presentation) —
/// there's too much going on there (pool management, a live socket-driven
/// bidding room, reports) to fit inside a tab. Applications is the admin
/// review queue for player self-service tournament applications (see
/// features/tournament_applications). Matches is the fixture
/// scheduling/calendar tab (see features/matches) — a grouped, date-sorted
/// list of this tournament's matches with create/edit/cancel actions.
/// Points Table is the computed standings (see `TournamentsService
/// .getPointsTable`) — tournament-scoped like every other tab here, so it
/// sits alongside them rather than as a separate route. Finance is the
/// revenue/expense dashboard (see features/finance) — same tournament-scoped
/// placement, embedding its own summary directly with navigation into the
/// fuller transaction list / team fees / player fees flows. Awards is the
/// computed award-categories view (see `TournamentsService.getAwards` and
/// `AwardsTab`) — same "derived on read, never persisted" placement as
/// Points Table.
class TournamentDetailScreen extends ConsumerWidget {
  const TournamentDetailScreen({super.key, required this.tournamentId, this.initialTabIndex = 0});

  final String tournamentId;

  /// Which of the eight tabs (Teams=0, Players=1, Auction=2, Applications=3,
  /// Matches=4, Points Table=5, Finance=6, Awards=7) to land on. Lets
  /// callers deep-link straight into a specific tab — e.g. AdminHomeScreen's
  /// drawer, when there's exactly one tournament to jump into for
  /// "Teams"/"Players"/"Applications"/"Matches"/"Schedule"/"Points
  /// Table"/"Finance".
  final int initialTabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentAsync = ref.watch(tournamentDetailProvider(tournamentId));
    final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));

    return DefaultTabController(
      length: 8,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: tournamentAsync.when(
            data: (tournament) => Text(tournament.name),
            loading: () => const Text('Tournament'),
            error: (error, stackTrace) => const Text('Tournament'),
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Teams'),
              Tab(text: 'Players'),
              Tab(text: 'Auction'),
              Tab(text: 'Applications'),
              Tab(text: 'Matches'),
              Tab(text: 'Points Table'),
              Tab(text: 'Finance'),
              Tab(text: 'Awards'),
            ],
          ),
        ),
        body: tournamentAsync.when(
          data: (tournament) {
            if (organizationId == null) {
              return const Center(child: Text('No active organization'));
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '${tournament.format.label} · ${tournament.startDate} to ${tournament.endDate} · '
                    'Status: ${tournament.status}${tournament.auctionEnabled ? ' · Auction enabled' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      TeamListTab(organizationId: organizationId, tournamentId: tournamentId),
                      PlayerListTab(organizationId: organizationId),
                      AuctionEntryTab(tournamentId: tournamentId),
                      ApplicationsReviewTab(
                        organizationId: organizationId,
                        tournamentId: tournamentId,
                      ),
                      MatchesTab(organizationId: organizationId, tournamentId: tournamentId),
                      PointsTableTab(tournamentId: tournamentId),
                      FinanceTab(tournamentId: tournamentId),
                      AwardsTab(tournamentId: tournamentId),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(
              error is ApiException ? error.message : 'Failed to load tournament',
            ),
          ),
        ),
      ),
    );
  }
}
