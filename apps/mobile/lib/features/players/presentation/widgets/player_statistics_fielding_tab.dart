import 'package:flutter/material.dart';

import '../../data/models/player_statistics.dart';
import 'player_stat_list.dart';

/// Fielding tab of PlayerStatisticsScreen — career-aggregate fielding
/// figures from `PlayerStatisticsResponse.fielding`.
class PlayerStatisticsFieldingTab extends StatelessWidget {
  const PlayerStatisticsFieldingTab({super.key, required this.fielding});

  final PlayerFieldingStats fielding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        PlayerStatList(
          entries: [
            ('Catches', '${fielding.catches}'),
            ('Run outs', '${fielding.runOuts}'),
            ('Stumpings', '${fielding.stumpings}'),
          ],
        ),
      ],
    );
  }
}
