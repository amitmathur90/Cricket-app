/// Mirrors `PlayerStatisticsResponse` and its nested interfaces in
/// apps/backend/src/modules/players/players.service.ts (`getStatistics`) —
/// a computed-on-read career/cross-match aggregation, nothing persisted.
///
/// Null-average handling: `battingAverage`/`bowling.average` come back as
/// JSON `null` (not `0`, `NaN`, or `Infinity`) when the player has never
/// been dismissed / never taken a wicket — see each field's doc comment on
/// the backend. This model preserves that as a nullable `double?` all the
/// way through; the UI is responsible for rendering "Not out" / "-" rather
/// than a bare number when null (see PlayerStatisticsScreen).
library;

/// `num?` -> `double?` helper — the backend serializes some of these fields
/// as whole JS numbers (e.g. `45`), which arrive over JSON as a Dart `int`,
/// not `double`. `as double?` alone would throw on those; going through
/// `num` first and calling `.toDouble()` handles both shapes.
double? _asNullableDouble(dynamic value) => (value as num?)?.toDouble();

double _asDouble(dynamic value) => (value as num).toDouble();

class PlayerStatisticsSummary {
  const PlayerStatisticsSummary({
    required this.matchesPlayed,
    required this.totalRuns,
    required this.timesOut,
    required this.battingAverage,
    required this.strikeRate,
    required this.totalWickets,
    required this.bowlingEconomy,
  });

  factory PlayerStatisticsSummary.fromJson(Map<String, dynamic> json) => PlayerStatisticsSummary(
        matchesPlayed: json['matchesPlayed'] as int,
        totalRuns: json['totalRuns'] as int,
        timesOut: json['timesOut'] as int,
        battingAverage: _asNullableDouble(json['battingAverage']),
        strikeRate: _asDouble(json['strikeRate']),
        totalWickets: json['totalWickets'] as int,
        bowlingEconomy: _asNullableDouble(json['bowlingEconomy']),
      );

  final int matchesPlayed;
  final int totalRuns;
  final int timesOut;

  /// runs / timesOut. Null (never NaN/Infinity) when [timesOut] is 0.
  final double? battingAverage;
  final double strikeRate;
  final int totalWickets;

  /// Null when the player has never bowled a legal ball.
  final double? bowlingEconomy;
}

class PlayerBattingStats {
  const PlayerBattingStats({
    required this.innings,
    required this.runs,
    required this.ballsFaced,
    required this.highestScore,
    required this.highestScoreNotOut,
    required this.fifties,
    required this.hundreds,
    required this.fours,
    required this.sixes,
    required this.timesOut,
    required this.average,
    required this.strikeRate,
  });

  factory PlayerBattingStats.fromJson(Map<String, dynamic> json) => PlayerBattingStats(
        innings: json['innings'] as int,
        runs: json['runs'] as int,
        ballsFaced: json['ballsFaced'] as int,
        highestScore: json['highestScore'] as int,
        highestScoreNotOut: json['highestScoreNotOut'] as bool,
        fifties: json['fifties'] as int,
        hundreds: json['hundreds'] as int,
        fours: json['fours'] as int,
        sixes: json['sixes'] as int,
        timesOut: json['timesOut'] as int,
        average: _asNullableDouble(json['average']),
        strikeRate: _asDouble(json['strikeRate']),
      );

  final int innings;
  final int runs;
  final int ballsFaced;
  final int highestScore;
  final bool highestScoreNotOut;
  final int fifties;
  final int hundreds;
  final int fours;
  final int sixes;
  final int timesOut;

  /// Null when [timesOut] is 0 — render "Not out" (never "-", never NaN),
  /// per the backend's doc comment on `PlayerBattingStats.average`.
  final double? average;
  final double strikeRate;
}

/// Best single-innings bowling figures (most wickets, then fewest runs).
class PlayerBestBowlingFigures {
  const PlayerBestBowlingFigures({required this.wickets, required this.runsConceded});

  factory PlayerBestBowlingFigures.fromJson(Map<String, dynamic> json) => PlayerBestBowlingFigures(
        wickets: json['wickets'] as int,
        runsConceded: json['runsConceded'] as int,
      );

  final int wickets;
  final int runsConceded;
}

class PlayerBowlingStats {
  const PlayerBowlingStats({
    required this.innings,
    required this.overs,
    required this.runsConceded,
    required this.wickets,
    required this.bestBowling,
    required this.average,
    required this.economy,
    required this.maidens,
  });

  factory PlayerBowlingStats.fromJson(Map<String, dynamic> json) => PlayerBowlingStats(
        innings: json['innings'] as int,
        overs: json['overs'] as String,
        runsConceded: json['runsConceded'] as int,
        wickets: json['wickets'] as int,
        bestBowling: json['bestBowling'] != null
            ? PlayerBestBowlingFigures.fromJson(json['bestBowling'] as Map<String, dynamic>)
            : null,
        average: _asNullableDouble(json['average']),
        economy: _asNullableDouble(json['economy']),
        maidens: json['maidens'] as int,
      );

  final int innings;

  /// Overs.balls display notation (e.g. "4.3"), not a true decimal.
  final String overs;
  final int runsConceded;
  final int wickets;

  /// Null if the player has never bowled.
  final PlayerBestBowlingFigures? bestBowling;

  /// Null when [wickets] is 0 — render "-", per the backend's doc comment.
  final double? average;

  /// Null when the player has never bowled a legal ball — render "-".
  final double? economy;
  final int maidens;
}

class PlayerFieldingStats {
  const PlayerFieldingStats({required this.catches, required this.runOuts, required this.stumpings});

  factory PlayerFieldingStats.fromJson(Map<String, dynamic> json) => PlayerFieldingStats(
        catches: json['catches'] as int,
        runOuts: json['runOuts'] as int,
        stumpings: json['stumpings'] as int,
      );

  final int catches;
  final int runOuts;
  final int stumpings;
}

/// One match's personal batting figures, from `PlayerMatchHistoryEntry.batting`.
class PlayerMatchBattingFigures {
  const PlayerMatchBattingFigures({
    required this.runs,
    required this.ballsFaced,
    required this.fours,
    required this.sixes,
    required this.isOut,
    required this.dismissalType,
    required this.strikeRate,
  });

  factory PlayerMatchBattingFigures.fromJson(Map<String, dynamic> json) => PlayerMatchBattingFigures(
        runs: json['runs'] as int,
        ballsFaced: json['ballsFaced'] as int,
        fours: json['fours'] as int,
        sixes: json['sixes'] as int,
        isOut: json['isOut'] as bool,
        dismissalType: json['dismissalType'] as String?,
        strikeRate: _asDouble(json['strikeRate']),
      );

  final int runs;
  final int ballsFaced;
  final int fours;
  final int sixes;
  final bool isOut;

  /// Raw `DismissalType` string (e.g. `caught`, `run_out`), or null when not
  /// out. Rendered via `dismissalTypeLabel` from the scoring feature.
  final String? dismissalType;
  final double strikeRate;
}

/// One match's personal bowling figures, from `PlayerMatchHistoryEntry.bowling`.
class PlayerMatchBowlingFigures {
  const PlayerMatchBowlingFigures({
    required this.overs,
    required this.runsConceded,
    required this.wickets,
    required this.maidens,
    required this.economy,
  });

  factory PlayerMatchBowlingFigures.fromJson(Map<String, dynamic> json) => PlayerMatchBowlingFigures(
        overs: json['overs'] as String,
        runsConceded: json['runsConceded'] as int,
        wickets: json['wickets'] as int,
        maidens: json['maidens'] as int,
        economy: _asDouble(json['economy']),
      );

  final String overs;
  final int runsConceded;
  final int wickets;
  final int maidens;

  /// Always a number for a per-match entry (0 when no legal balls bowled in
  /// that match) — unlike the career-wide `PlayerBowlingStats.economy`,
  /// this one is never null per the backend response shape.
  final double economy;
}

/// One completed match the player appeared in, with their personal figures
/// for it. Mirrors `PlayerMatchHistoryEntry` exactly.
class PlayerMatchHistoryEntry {
  const PlayerMatchHistoryEntry({
    required this.matchId,
    required this.tournamentId,
    required this.scheduledAt,
    required this.playerTournamentTeamId,
    required this.opponentTournamentTeamId,
    required this.playerTeamName,
    required this.opponentTeamName,
    required this.resultSummary,
    required this.won,
    required this.batting,
    required this.bowling,
    required this.fielding,
  });

  factory PlayerMatchHistoryEntry.fromJson(Map<String, dynamic> json) => PlayerMatchHistoryEntry(
        matchId: json['matchId'] as String,
        tournamentId: json['tournamentId'] as String,
        scheduledAt: json['scheduledAt'] != null ? DateTime.tryParse(json['scheduledAt'] as String) : null,
        playerTournamentTeamId: json['playerTournamentTeamId'] as String?,
        opponentTournamentTeamId: json['opponentTournamentTeamId'] as String?,
        playerTeamName: json['playerTeamName'] as String,
        opponentTeamName: json['opponentTeamName'] as String,
        resultSummary: json['resultSummary'] as String?,
        won: json['won'] as bool?,
        batting: json['batting'] != null
            ? PlayerMatchBattingFigures.fromJson(json['batting'] as Map<String, dynamic>)
            : null,
        bowling: json['bowling'] != null
            ? PlayerMatchBowlingFigures.fromJson(json['bowling'] as Map<String, dynamic>)
            : null,
        fielding: PlayerFieldingStats.fromJson(json['fielding'] as Map<String, dynamic>),
      );

  final String matchId;
  final String tournamentId;
  final DateTime? scheduledAt;
  final String? playerTournamentTeamId;
  final String? opponentTournamentTeamId;
  final String playerTeamName;
  final String opponentTeamName;
  final String? resultSummary;

  /// True/false if the player's side won/lost, null if undecidable (no
  /// resolvable team side, e.g. `playerTournamentTeamId` is null) or the
  /// match was a tie — see the backend's `isTie`/`won` derivation.
  final bool? won;

  /// Null if the player didn't bat in this match (e.g. bowler who wasn't
  /// needed to bat, or their side didn't bat).
  final PlayerMatchBattingFigures? batting;

  /// Null if the player didn't bowl in this match.
  final PlayerMatchBowlingFigures? bowling;
  final PlayerFieldingStats fielding;
}

/// Top-level response of `GET .../players/:playerId/statistics`. Mirrors
/// `PlayerStatisticsResponse` in players.service.ts.
class PlayerStatistics {
  const PlayerStatistics({
    required this.playerId,
    required this.summary,
    required this.batting,
    required this.bowling,
    required this.fielding,
    required this.matchHistory,
  });

  factory PlayerStatistics.fromJson(Map<String, dynamic> json) => PlayerStatistics(
        playerId: json['playerId'] as String,
        summary: PlayerStatisticsSummary.fromJson(json['summary'] as Map<String, dynamic>),
        batting: PlayerBattingStats.fromJson(json['batting'] as Map<String, dynamic>),
        bowling: PlayerBowlingStats.fromJson(json['bowling'] as Map<String, dynamic>),
        fielding: PlayerFieldingStats.fromJson(json['fielding'] as Map<String, dynamic>),
        matchHistory: (json['matchHistory'] as List<dynamic>)
            .map((e) => PlayerMatchHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String playerId;
  final PlayerStatisticsSummary summary;
  final PlayerBattingStats batting;
  final PlayerBowlingStats bowling;
  final PlayerFieldingStats fielding;

  /// Chronological (ascending by match date) — safe to plot directly for a
  /// runs/wickets-per-match trend graph, no client-side re-sort needed.
  final List<PlayerMatchHistoryEntry> matchHistory;
}
