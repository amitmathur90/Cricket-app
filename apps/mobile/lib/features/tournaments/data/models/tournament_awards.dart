// Mirrors `AwardResult` / `MatchAwardEntry` / `TournamentAwardsResponse`
// (apps/backend/src/modules/tournaments/tournaments.service.ts) — the
// computed (never persisted) response of
// `GET .../tournaments/:tournamentId/awards`. See that file's doc comments
// for the full per-award methodology (composite formulas, thresholds,
// data-availability caveats) — this file only mirrors the wire shape.

/// One award's winner — present only when `AwardResult.winner` is non-null.
class AwardWinner {
  const AwardWinner({
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.value,
  });

  factory AwardWinner.fromJson(Map<String, dynamic> json) => AwardWinner(
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String,
        teamName: json['teamName'] as String,
        value: json['value'] as String,
      );

  final String playerId;
  final String playerName;
  final String teamName;

  /// Human-readable stat line backing this award, e.g. "312 runs, 9 wkts
  /// (composite 492)".
  final String value;
}

/// One award's outcome — `winner` is null whenever there's genuinely no
/// determinable winner; `reasoning` is always present and explains the
/// formula/threshold used, or (when null) why no winner could be
/// determined. Never suppress `reasoning` in the UI — it's the whole point
/// of an honest "not awarded" state.
class AwardResult {
  const AwardResult({required this.winner, required this.reasoning});

  factory AwardResult.fromJson(Map<String, dynamic> json) => AwardResult(
        winner: json['winner'] == null
            ? null
            : AwardWinner.fromJson(json['winner'] as Map<String, dynamic>),
        reasoning: json['reasoning'] as String? ?? '',
      );

  final AwardWinner? winner;
  final String reasoning;
}

/// One completed match's Man-of-the-Match entry.
class MatchAwardEntry {
  const MatchAwardEntry({
    required this.matchId,
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.value,
  });

  factory MatchAwardEntry.fromJson(Map<String, dynamic> json) => MatchAwardEntry(
        matchId: json['matchId'] as String,
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String,
        teamName: json['teamName'] as String,
        value: json['value'] as String,
      );

  final String matchId;
  final String playerId;
  final String playerName;
  final String teamName;
  final String value;
}

/// The per-match Man-of-the-Match section — a shared `reasoning` (the
/// composite formula used for every match) plus one entry per completed
/// match.
class ManOfTheMatchAward {
  const ManOfTheMatchAward({required this.reasoning, required this.matches});

  factory ManOfTheMatchAward.fromJson(Map<String, dynamic> json) => ManOfTheMatchAward(
        reasoning: json['reasoning'] as String? ?? '',
        matches: (json['matches'] as List<dynamic>? ?? const [])
            .map((e) => MatchAwardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String reasoning;
  final List<MatchAwardEntry> matches;
}

/// The full `GET .../tournaments/:tournamentId/awards` response — 8 award
/// categories: Player of the Tournament, Man of the Match (per completed
/// match), Best Batsman/Bowler/Fielder/All-Rounder, Emerging Player, and
/// Best Captain.
class TournamentAwardsResponse {
  const TournamentAwardsResponse({
    required this.playerOfTheTournament,
    required this.manOfTheMatch,
    required this.bestBatsman,
    required this.bestBowler,
    required this.bestFielder,
    required this.bestAllRounder,
    required this.emergingPlayer,
    required this.bestCaptain,
  });

  factory TournamentAwardsResponse.fromJson(Map<String, dynamic> json) => TournamentAwardsResponse(
        playerOfTheTournament:
            AwardResult.fromJson(json['playerOfTheTournament'] as Map<String, dynamic>),
        manOfTheMatch: ManOfTheMatchAward.fromJson(json['manOfTheMatch'] as Map<String, dynamic>),
        bestBatsman: AwardResult.fromJson(json['bestBatsman'] as Map<String, dynamic>),
        bestBowler: AwardResult.fromJson(json['bestBowler'] as Map<String, dynamic>),
        bestFielder: AwardResult.fromJson(json['bestFielder'] as Map<String, dynamic>),
        bestAllRounder: AwardResult.fromJson(json['bestAllRounder'] as Map<String, dynamic>),
        emergingPlayer: AwardResult.fromJson(json['emergingPlayer'] as Map<String, dynamic>),
        bestCaptain: AwardResult.fromJson(json['bestCaptain'] as Map<String, dynamic>),
      );

  final AwardResult playerOfTheTournament;
  final ManOfTheMatchAward manOfTheMatch;
  final AwardResult bestBatsman;
  final AwardResult bestBowler;
  final AwardResult bestFielder;
  final AwardResult bestAllRounder;
  final AwardResult emergingPlayer;
  final AwardResult bestCaptain;
}
