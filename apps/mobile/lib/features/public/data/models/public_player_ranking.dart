/// Mirrors `PlayerRankingRow`
/// (apps/backend/src/modules/players/players.service.ts), returned
/// unmodified by both the authenticated rankings endpoint and
/// `GET public/organizations/:organizationId/players/rankings` — performance
/// figures and a name only, no PII, so the same shape is safe to reuse for
/// both surfaces. Defined locally (rather than imported from a
/// `features/players` model) because no such model exists yet on the
/// authenticated side today.
class PublicPlayerRanking {
  const PublicPlayerRanking({
    required this.position,
    required this.playerId,
    required this.playerName,
    required this.matchesPlayed,
    required this.runs,
    required this.wickets,
    this.average,
    this.economy,
  });

  factory PublicPlayerRanking.fromJson(Map<String, dynamic> json) => PublicPlayerRanking(
        position: (json['position'] as num).toInt(),
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String,
        matchesPlayed: (json['matchesPlayed'] as num?)?.toInt() ?? 0,
        runs: (json['runs'] as num?)?.toInt() ?? 0,
        wickets: (json['wickets'] as num?)?.toInt() ?? 0,
        average: (json['average'] as num?)?.toDouble(),
        economy: (json['economy'] as num?)?.toDouble(),
      );

  final int position;
  final String playerId;
  final String playerName;
  final int matchesPlayed;
  final int runs;
  final int wickets;

  /// Null when the player has zero dismissals — not rankable on this metric.
  final double? average;

  /// Null when the player has bowled zero legal balls — not rankable on this
  /// metric.
  final double? economy;
}

/// Mirrors `RankingMetric`
/// (apps/backend/src/modules/players/dto/player-rankings-query.dto.ts).
enum PublicRankingMetric {
  runs('runs', 'Runs'),
  wickets('wickets', 'Wickets'),
  average('average', 'Average'),
  economy('economy', 'Economy');

  const PublicRankingMetric(this.apiValue, this.label);

  final String apiValue;
  final String label;
}
