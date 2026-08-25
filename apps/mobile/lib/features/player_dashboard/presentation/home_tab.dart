import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../matches/presentation/widgets/match_card.dart';
import '../../notifications/presentation/widgets/notification_bell.dart';
import '../application/player_dashboard_providers.dart';
import 'widgets/match_info_sheet.dart';
import 'widgets/next_match_card.dart';
import 'widgets/performance_summary_row.dart';
import 'widgets/upcoming_practice_card.dart';

/// Bottom-nav Home tab — restyled to match the "Match Centre" mockup: an
/// AppBar bell (see [NotificationBell]'s doc comment — it already documents
/// itself as shared by the admin and player home screens' AppBars, this tab
/// just hadn't picked it up yet), a live/next-match banner ([NextMatchCard]),
/// an "Upcoming Matches" list, and a "View Full Schedule" button that jumps
/// to the Matches tab via [onOpenMatches] (see [PlayerShellScreen], which
/// wires this the same way `CaptainHomeTab`'s `onOpenMatches` callback
/// already does for the analogous captain shell). Below that, the tab keeps
/// its pre-existing "Your Performance", "Upcoming Practice", and Tournaments
/// entry point (features/tournament_applications) — none of that is part of
/// the Match Centre mockup panel itself, but nothing here was asked to be
/// removed, so it stays, just restyled to the same card language.
class PlayerHomeTab extends ConsumerWidget {
  const PlayerHomeTab({super.key, required this.onOpenMatches});

  /// Switches the shell to the Matches tab (index 1) — see
  /// [PlayerShellScreen]. Used by "View Full Schedule" and the "Upcoming
  /// Matches" section header's chevron.
  final VoidCallback onOpenMatches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myPlayerAsync = ref.watch(myPlayerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Centre'),
        automaticallyImplyLeading: false,
        actions: const [NotificationBell(), SizedBox(width: 4)],
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          ref.refresh(myPlayerProvider.future),
          ref.refresh(myTeamMembershipProvider.future),
          ref.refresh(playerRelevantMatchesProvider.future),
          ref.refresh(playerUpcomingPracticeProvider.future),
        ]),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const NextMatchCard(),
            const SizedBox(height: 20),
            _UpcomingMatchesSection(onOpenMatches: onOpenMatches),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOpenMatches,
                child: const Text('View Full Schedule'),
              ),
            ),
            const SizedBox(height: 20),
            myPlayerAsync.when(
              data: (player) =>
                  player == null ? const SizedBox.shrink() : PerformanceSummaryRow(playerId: player.id),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            const UpcomingPracticeCard(),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: const Text('Tournaments'),
                subtitle: const Text('Browse tournaments and apply'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(playerTournamentsPath),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Upcoming Matches" section: a tappable section header (chevron
/// affordance, jumps to the Matches tab) followed by a short list of the
/// caller's next few matches, reusing the exact same [MatchCard] row used by
/// the Matches tab / Schedule screen — see that widget's doc comment — so
/// this doesn't invent a third visual variant of a match row. The match
/// already shown in [NextMatchCard]'s banner is excluded so it isn't
/// duplicated here (see [NextMatchCard.featured]/[NextMatchCard.upcomingList]).
class _UpcomingMatchesSection extends ConsumerWidget {
  const _UpcomingMatchesSection({required this.onOpenMatches});

  final VoidCallback onOpenMatches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(playerRelevantMatchesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onOpenMatches,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  'Upcoming Matches',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        matchesAsync.when(
          data: (result) {
            final featuredId = NextMatchCard.featured(result.matches)?.id;
            final upcoming = NextMatchCard.upcomingList(result.matches, excludeId: featuredId)
                .take(3)
                .toList();
            if (upcoming.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No further matches scheduled.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              );
            }
            return Column(
              children: [
                for (final match in upcoming)
                  MatchCard(match: match, onTap: () => showMatchInfoSheet(context, match)),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Text(
            error is ApiException ? error.message : 'Failed to load matches',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }
}
