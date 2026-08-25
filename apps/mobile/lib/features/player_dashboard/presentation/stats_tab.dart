import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../players/presentation/player_statistics_screen.dart';
import '../application/player_dashboard_providers.dart';

/// Bottom-nav Stats tab — the caller's own career statistics.
///
/// Reuses `PlayerStatisticsScreen` (features/players/presentation/
/// player_statistics_screen.dart) in `embedded: true` mode — its header,
/// summary grid, and Batting/Bowling/Fielding/Match History/Performance
/// Graph tabs, without a second `Scaffold`/`AppBar` — rather than
/// duplicating that widget tree for a self-view.
class PlayerStatsTab extends ConsumerWidget {
  const PlayerStatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myPlayerAsync = ref.watch(myPlayerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stats'), automaticallyImplyLeading: false),
      body: myPlayerAsync.when(
        data: (player) {
          if (player == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "You don't have a player profile yet — apply to a tournament to create "
                  'one, then your stats will show up here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return PlayerStatisticsScreen(player: player, embedded: true);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load your profile'),
        ),
      ),
    );
  }
}
