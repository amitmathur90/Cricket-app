import 'package:flutter/material.dart';

import '../../data/models/player_statistics.dart';
import 'player_stat_list.dart';
import 'player_statistics_format.dart';

/// Batting tab of PlayerStatisticsScreen — career-aggregate batting figures
/// from `PlayerStatisticsResponse.batting`.
class PlayerStatisticsBattingTab extends StatelessWidget {
  const PlayerStatisticsBattingTab({super.key, required this.batting});

  final PlayerBattingStats batting;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        PlayerStatList(
          entries: [
            ('Innings', '${batting.innings}'),
            ('Runs', '${batting.runs}'),
            ('Balls faced', '${batting.ballsFaced}'),
            ('Highest score', formatHighestScore(batting)),
            ('50s', '${batting.fifties}'),
            ('100s', '${batting.hundreds}'),
            ('4s', '${batting.fours}'),
            ('6s', '${batting.sixes}'),
            ('Times out', '${batting.timesOut}'),
            ('Average', formatBattingAverage(batting.average)),
            ('Strike rate', batting.strikeRate.toStringAsFixed(2)),
          ],
        ),
      ],
    );
  }
}
