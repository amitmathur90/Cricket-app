import 'package:flutter/material.dart';

/// One label/value pair rendered by [PlayerStatList] — e.g. ("Innings", "12").
typedef PlayerStatEntry = (String label, String value);

/// A simple label-on-the-left, bold-value-on-the-right stat list, used by
/// the Batting/Bowling/Fielding tabs of PlayerStatisticsScreen. These tabs
/// each show one row of *career-aggregate* numbers (not a multi-player
/// table), so a DataTable (the convention used for the per-player Match
/// Center scorecard — see match_scorecard_tab.dart) would be the wrong
/// shape here; a plain Card of rows matches how AuctionReportScreen and
/// DashboardOverview already render single-entity stat summaries in this
/// app.
class PlayerStatList extends StatelessWidget {
  const PlayerStatList({super.key, required this.entries});

  final List<PlayerStatEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Text(entries[i].$1)),
                  Text(
                    entries[i].$2,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
