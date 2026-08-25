/// A lighter-weight parse of `GET .../matches/:matchId/lineup`'s response
/// than `features/matches/data/models/match_lineup.dart`'s `TeamLineup`,
/// which deliberately discards everything except `teamPlayerId` (see its
/// doc comment — the matches feature renders names by cross-referencing a
/// separately-fetched roster, keyed by the org-level `Team.id`).
///
/// The scoring feature can't reuse that pattern: every picker here
/// (openers, next batter, new bowler, fielder) starts from a
/// `tournamentTeamId` (from `Match`/`LiveScoringState`), and
/// `TeamsRepository.getRoster` needs the org-level `Team.id` instead — and no
/// client-side mapping from `tournamentTeamId` to `Team.id` exists anywhere
/// in this app today. Fortunately `MatchLineupService.getLineup`
/// (apps/backend/src/modules/matches/match-lineup.service.ts) already eager-loads
/// `['teamPlayer', 'teamPlayer.player']` for its own purposes and returns
/// those relations un-stripped, so this model just reads the player name
/// straight out of that same response instead of a second round trip.
library;

class ScoringLineupPlayer {
  const ScoringLineupPlayer({required this.teamPlayerId, required this.fullName});

  factory ScoringLineupPlayer.fromJson(Map<String, dynamic> json) {
    final teamPlayer = json['teamPlayer'] as Map<String, dynamic>?;
    final player = teamPlayer?['player'] as Map<String, dynamic>?;
    return ScoringLineupPlayer(
      teamPlayerId: json['teamPlayerId'] as String,
      fullName: player?['fullName'] as String? ?? 'Unknown player',
    );
  }

  final String teamPlayerId;
  final String fullName;
}

class ScoringTeamLineup {
  const ScoringTeamLineup({required this.tournamentTeamId, required this.playing});

  factory ScoringTeamLineup.fromJson(Map<String, dynamic> json) => ScoringTeamLineup(
        tournamentTeamId: json['tournamentTeamId'] as String,
        playing: ((json['playing'] as List<dynamic>?) ?? const [])
            .map((e) => ScoringLineupPlayer.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String tournamentTeamId;

  /// Playing XI only — substitutes are irrelevant to in-match scoring.
  final List<ScoringLineupPlayer> playing;
}

class ScoringMatchLineup {
  const ScoringMatchLineup({required this.matchId, this.home, this.away});

  factory ScoringMatchLineup.fromJson(Map<String, dynamic> json) => ScoringMatchLineup(
        matchId: json['matchId'] as String,
        home: json['home'] != null ? ScoringTeamLineup.fromJson(json['home'] as Map<String, dynamic>) : null,
        away: json['away'] != null ? ScoringTeamLineup.fromJson(json['away'] as Map<String, dynamic>) : null,
      );

  final String matchId;
  final ScoringTeamLineup? home;
  final ScoringTeamLineup? away;

  ScoringTeamLineup? forTeam(String? tournamentTeamId) {
    if (tournamentTeamId == null) return null;
    if (home?.tournamentTeamId == tournamentTeamId) return home;
    if (away?.tournamentTeamId == tournamentTeamId) return away;
    return null;
  }
}
