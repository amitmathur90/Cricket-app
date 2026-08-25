import '../../data/models/match.dart';

/// Resolves a `tournamentTeamId` (as carried by `getScorecard`/`getLiveState`
/// innings payloads, which only ever identify a side by that id — see
/// `ScoringInningsCard`/`ScoringInningsSnapshot`) to a display name, using
/// `Match.home/awayTournamentTeamId` + the server-resolved
/// `homeTeamName`/`awayTeamName` already carried on [Match] (see
/// `MatchesService.MatchResponse`'s doc comment). Falls back to a short
/// placeholder if the id matches neither side (shouldn't happen in
/// practice, since scoring only ever runs between a match's own two teams).
String matchTeamName(Match match, String tournamentTeamId) {
  if (match.homeTournamentTeamId == tournamentTeamId) return match.homeTeamName ?? 'Home team';
  if (match.awayTournamentTeamId == tournamentTeamId) return match.awayTeamName ?? 'Away team';
  return 'Unknown team';
}
