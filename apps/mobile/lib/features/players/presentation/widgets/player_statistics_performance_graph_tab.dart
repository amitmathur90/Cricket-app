import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/player_statistics.dart';

/// Performance Graph tab of PlayerStatisticsScreen — a simple chronological
/// trend of runs-per-match and wickets-per-match off `matchHistory` (which
/// the backend already returns in ascending-date order, see
/// `PlayerStatisticsResponse.matchHistory`'s doc comment — no client-side
/// re-sort needed).
///
/// Charting approach: hand-rolled bars (`Container`s sized proportionally
/// inside a fixed-height row), not a charting package. This app has stayed
/// dependency-light throughout (see pubspec.yaml — every dependency here
/// earns its place: dio for networking, socket_io_client for the live
/// auction room, etc.), and the two trend charts this tab needs (runs and
/// wickets per match, plain proportional bars, no zoom/pan/tooltips-on-drag
/// requirement) don't need a charting library's feature set. Adding
/// `fl_chart` for two bar rows would be a lot of new surface area for a
/// visual result plain `Container`s already deliver cleanly.
class PlayerStatisticsPerformanceGraphTab extends StatelessWidget {
  const PlayerStatisticsPerformanceGraphTab({super.key, required this.matchHistory});

  final List<PlayerMatchHistoryEntry> matchHistory;

  @override
  Widget build(BuildContext context) {
    if (matchHistory.isEmpty) {
      return const Center(child: Text('No match history yet to chart.'));
    }

    final labels = [
      for (final entry in matchHistory)
        entry.scheduledAt != null ? DateFormat.Md().format(entry.scheduledAt!.toLocal()) : '—',
    ];
    final runs = [for (final entry in matchHistory) (entry.batting?.runs ?? 0).toDouble()];
    final wickets = [for (final entry in matchHistory) (entry.bowling?.wickets ?? 0).toDouble()];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Chronological trend across ${matchHistory.length} match'
          '${matchHistory.length == 1 ? '' : 'es'}. Bars read 0 for a match the '
          'player didn\'t bat/bowl in.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 16),
        Text('Runs per match', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _TrendChart(values: runs, labels: labels, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text('Wickets per match', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _TrendChart(values: wickets, labels: labels, color: Theme.of(context).colorScheme.tertiary),
      ],
    );
  }
}

/// A row of proportional vertical bars, one per match, horizontally
/// scrollable so it stays readable regardless of how many matches are in
/// the player's history.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.values, required this.labels, required this.color});

  final List<double> values;
  final List<String> labels;
  final Color color;

  static const double _barAreaHeight = 120;
  static const double _barWidth = 24;
  static const double _barGap = 14;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, (max, v) => v > max ? v : max);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: _barGap),
            _Bar(
              value: values[i],
              maxValue: maxValue,
              label: labels[i],
              color: color,
              barAreaHeight: _barAreaHeight,
              width: _barWidth,
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.maxValue,
    required this.label,
    required this.color,
    required this.barAreaHeight,
    required this.width,
  });

  final double value;
  final double maxValue;
  final String label;
  final Color color;
  final double barAreaHeight;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = maxValue > 0 ? (value / maxValue) * (barAreaHeight - 20) : 0.0;
    return Tooltip(
      message: '$label: ${value.toStringAsFixed(0)}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: barAreaHeight,
            width: width,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(value.toStringAsFixed(0), style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Container(
                  height: height.clamp(2.0, barAreaHeight),
                  width: width,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: width + 12,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
