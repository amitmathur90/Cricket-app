import 'package:flutter/material.dart';

import '../../data/models/player_statistics.dart';
import 'player_stat_list.dart';
import 'player_statistics_format.dart';

/// Bowling tab of PlayerStatisticsScreen — career-aggregate bowling figures
/// from `PlayerStatisticsResponse.bowling`.
class PlayerStatisticsBowlingTab extends StatelessWidget {
  const PlayerStatisticsBowlingTab({super.key, required this.bowling});

  final PlayerBowlingStats bowling;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        PlayerStatList(
          entries: [
            ('Innings bowled', '${bowling.innings}'),
            ('Overs', bowling.overs),
            ('Runs conceded', '${bowling.runsConceded}'),
            ('Wickets', '${bowling.wickets}'),
            ('Best bowling', formatBestBowling(bowling.bestBowling)),
            ('Average', formatOrDash(bowling.average)),
            ('Economy', formatOrDash(bowling.economy)),
            ('Maidens', '${bowling.maidens}'),
          ],
        ),
      ],
    );
  }
}
