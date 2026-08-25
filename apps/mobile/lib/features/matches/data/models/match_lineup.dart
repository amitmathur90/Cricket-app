/// A `{teamPlayerId, fullName}` pair read straight out of one `MatchLineup`
/// row's joined `teamPlayer.player` relation — same technique as
/// `ScoringLineupPlayer` (features/scoring/data/models/scoring_lineup.dart),
/// duplicated here rather than shared because that class deliberately only
/// parses the `playing` list (substitutes are irrelevant to in-match
/// scoring), while the read-only Playing XI tab (see MatchPlayingXiTab) needs
/// both.
class NamedLineupPlayer {
  const NamedLineupPlayer({required this.teamPlayerId, required this.fullName});

  factory NamedLineupPlayer.fromJson(Map<String, dynamic> json) {
    final teamPlayer = json['teamPlayer'] as Map<String, dynamic>?;
    final player = teamPlayer?['player'] as Map<String, dynamic>?;
    return NamedLineupPlayer(
      teamPlayerId: json['teamPlayerId'] as String,
      fullName: player?['fullName'] as String? ?? 'Unknown player',
    );
  }

  final String teamPlayerId;
  final String fullName;
}

/// One team's Playing XI + substitutes for one match, mirroring
/// `MatchLineupService.TeamLineupResponse` (apps/backend/src/modules/matches/
/// match-lineup.service.ts). The backend returns full `MatchLineup` rows
/// (with `teamPlayer`/`teamPlayer.player` joined) for BOTH `playing` and
/// `substitutes`.
///
/// [playingTeamPlayerIds]/[substituteTeamPlayerIds] only need the ids — the
/// Playing XI *selection* screen renders player details from the roster it
/// already loads via `rosterProvider` (see LineupSelectionScreen), so
/// re-parsing the joined player payload there would be pure duplication.
/// [playingPlayers]/[substitutePlayers] parse the SAME response's joined
/// names directly (no second roster fetch) — added for the read-only Playing
/// XI tab on the match detail/center screen, which has no roster context to
/// cross-reference against.
class TeamLineup {
  const TeamLineup({
    required this.tournamentTeamId,
    required this.playingTeamPlayerIds,
    required this.substituteTeamPlayerIds,
    required this.playingPlayers,
    required this.substitutePlayers,
  });

  factory TeamLineup.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> rows(String key) =>
        ((json[key] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>();
    final playingRows = rows('playing');
    final subRows = rows('substitutes');
    return TeamLineup(
      tournamentTeamId: json['tournamentTeamId'] as String,
      playingTeamPlayerIds: playingRows.map((e) => e['teamPlayerId'] as String).toList(),
      substituteTeamPlayerIds: subRows.map((e) => e['teamPlayerId'] as String).toList(),
      playingPlayers: playingRows.map(NamedLineupPlayer.fromJson).toList(),
      substitutePlayers: subRows.map(NamedLineupPlayer.fromJson).toList(),
    );
  }

  final String tournamentTeamId;
  final List<String> playingTeamPlayerIds;
  final List<String> substituteTeamPlayerIds;
  final List<NamedLineupPlayer> playingPlayers;
  final List<NamedLineupPlayer> substitutePlayers;
}

/// Mirrors `MatchLineupService.MatchLineupResponse` — both teams' lineups
/// for a match, either of which is null if that side has no
/// `homeTournamentTeamId`/`awayTournamentTeamId` (TBD fixture).
class MatchLineupResponse {
  const MatchLineupResponse({required this.matchId, this.home, this.away});

  factory MatchLineupResponse.fromJson(Map<String, dynamic> json) => MatchLineupResponse(
        matchId: json['matchId'] as String,
        home: json['home'] != null ? TeamLineup.fromJson(json['home'] as Map<String, dynamic>) : null,
        away: json['away'] != null ? TeamLineup.fromJson(json['away'] as Map<String, dynamic>) : null,
      );

  final String matchId;
  final TeamLineup? home;
  final TeamLineup? away;

  /// Picks the [TeamLineup] for [tournamentTeamId], whichever side (home or
  /// away) it matches — null if neither (or that side has no lineup rows
  /// yet, which the caller should treat the same as "no lineup set").
  TeamLineup? forTeam(String tournamentTeamId) {
    if (home?.tournamentTeamId == tournamentTeamId) return home;
    if (away?.tournamentTeamId == tournamentTeamId) return away;
    return null;
  }
}
