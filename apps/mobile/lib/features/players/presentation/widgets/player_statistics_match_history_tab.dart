import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../scoring/data/models/scoring_models.dart';
import '../../data/models/player_statistics.dart';

/// Match History tab of PlayerStatisticsScreen — one row per completed
/// match the player appeared in (`PlayerStatisticsResponse.matchHistory`,
/// already chronological ascending per the backend). Each row carries a
/// real `matchId`/`tournamentId` pair straight off the response, so it's
/// always safe to push into Match Center from here (see
/// `matchCenterPath`) — unlike some other summarized-entry screens in this
/// app, there's no case where the linking id is missing.
class PlayerStatisticsMatchHistoryTab extends StatelessWidget {
  const PlayerStatisticsMatchHistoryTab({super.key, required this.matchHistory});

  final List<PlayerMatchHistoryEntry> matchHistory;

  @override
  Widget build(BuildContext context) {
    if (matchHistory.isEmpty) {
      return const Center(child: Text('No match history yet.'));
    }
    // Most recent first for a history list, even though the source array is
    // chronological ascending (kept ascending there for the graph tab).
    final descending = matchHistory.reversed.toList();
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: descending.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _MatchHistoryCard(entry: descending[index]),
    );
  }
}

class _MatchHistoryCard extends StatelessWidget {
  const _MatchHistoryCard({required this.entry});

  final PlayerMatchHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    if (entry.batting != null) {
      final b = entry.batting!;
      lines.add(
        'Bat: ${b.runs}${b.isOut ? '' : '*'} (${b.ballsFaced}b, ${b.fours}x4 ${b.sixes}x6)'
        '${b.isOut ? ' — ${dismissalTypeLabel(b.dismissalType)}' : ''}',
      );
    }
    if (entry.bowling != null) {
      final bw = entry.bowling!;
      lines.add('Bowl: ${bw.wickets}/${bw.runsConceded} (${bw.overs} ov, econ ${bw.economy.toStringAsFixed(2)})');
    }
    final f = entry.fielding;
    if (f.catches > 0 || f.runOuts > 0 || f.stumpings > 0) {
      lines.add(
        'Field: ${[
          if (f.catches > 0) '${f.catches} ct',
          if (f.runOuts > 0) '${f.runOuts} ro',
          if (f.stumpings > 0) '${f.stumpings} st',
        ].join(', ')}',
      );
    }

    final (resultColor, resultIcon) = switch (entry.won) {
      true => (Colors.green, Icons.check_circle),
      false => (Colors.red, Icons.cancel),
      null => (Colors.grey, Icons.remove_circle_outline),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => context.push(matchCenterPath(entry.tournamentId, entry.matchId)),
        title: Text('${entry.playerTeamName} vs ${entry.opponentTeamName}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text([
              if (entry.scheduledAt != null) DateFormat.yMMMd().format(entry.scheduledAt!.toLocal()),
              if (entry.resultSummary != null) entry.resultSummary!,
            ].join(' · ')),
            for (final line in lines) Text(line),
          ],
        ),
        trailing: Icon(resultIcon, color: resultColor),
      ),
    );
  }
}
