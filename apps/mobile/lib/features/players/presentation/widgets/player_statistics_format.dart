import '../../data/models/player_statistics.dart';

/// Shared formatting helpers for the Player Statistics screen and its tabs.
/// Centralized here so every tab renders the null-average edge case the
/// same way — see PlayerStatisticsSummary/PlayerBattingStats/
/// PlayerBowlingStats' doc comments in player_statistics.dart for why these
/// fields come back as `null` (never `NaN`/`Infinity`) rather than a number.

/// A batting average is null only because the player has never been
/// dismissed (0 for 0 innings, or every innings so far unbeaten) — "Not
/// out" is the correct cricket-convention label, not "-" or "0.00".
String formatBattingAverage(double? average) =>
    average == null ? 'Not out' : average.toStringAsFixed(2);

/// A bowling average/economy is null because the player has never taken a
/// wicket / never bowled a legal ball — there's no meaningful cricket
/// convention label for that (unlike batting's "not out"), so this is
/// rendered as a plain dash.
String formatOrDash(double? value) => value == null ? '-' : value.toStringAsFixed(2);

/// "3/24" style figures, or a dash if the player has never bowled.
String formatBestBowling(PlayerBestBowlingFigures? figures) =>
    figures == null ? '-' : '${figures.wickets}/${figures.runsConceded}';

/// "87*" when the innings was unbeaten, plain "87" otherwise. Matches the
/// real-world scorecard convention the backend's `highestScoreNotOut`
/// derivation already follows (see PlayersService.getStatistics doc).
String formatHighestScore(PlayerBattingStats batting) =>
    '${batting.highestScore}${batting.highestScoreNotOut ? '*' : ''}';
