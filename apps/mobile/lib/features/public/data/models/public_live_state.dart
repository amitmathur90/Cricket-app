import '../../../matches/data/models/match.dart' show MatchStatus;

/// Mirrors `ScoringRealtimeService.getLiveState`'s return shape
/// (apps/backend/src/modules/scoring/scoring-realtime.service.ts), reused
/// verbatim by
/// `GET public/organizations/:organizationId/tournaments/:tournamentId/live-score/:matchId`
/// (apps/backend/src/modules/public/public-tournaments.controller.ts#getLiveScore)
/// — built entirely from player names + ball-by-ball figures, no PII, so
/// the authenticated computation's result is safe to return unmodified. This
/// is a REST snapshot (no WebSocket here — the authenticated live-scoring
/// screen uses Socket.IO for scorer input, but this public read-only view
/// just polls this endpoint periodically, see `PublicLiveMatchScreen`).
class PublicLiveMatchState {
  const PublicLiveMatchState({required this.match, required this.innings});

  factory PublicLiveMatchState.fromJson(Map<String, dynamic> json) => PublicLiveMatchState(
        match: PublicLiveMatchInfo.fromJson(json['match'] as Map<String, dynamic>),
        innings: (json['innings'] as List<dynamic>)
            .map((e) => PublicLiveInnings.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final PublicLiveMatchInfo match;
  final List<PublicLiveInnings> innings;

  /// The innings currently being scored (highest `inningsNumber` with status
  /// `in_progress`), or the last innings present if none is in progress
  /// (e.g. the match just completed). Null if no innings has started yet.
  PublicLiveInnings? get currentInnings {
    if (innings.isEmpty) return null;
    final inProgress = innings.where((i) => i.status == 'in_progress');
    if (inProgress.isNotEmpty) {
      return inProgress.reduce((a, b) => a.inningsNumber > b.inningsNumber ? a : b);
    }
    return innings.reduce((a, b) => a.inningsNumber > b.inningsNumber ? a : b);
  }
}

class PublicLiveMatchInfo {
  const PublicLiveMatchInfo({
    required this.id,
    required this.status,
    this.oversLimit,
    this.homeTournamentTeamId,
    this.awayTournamentTeamId,
    this.resultSummary,
    this.winnerTournamentTeamId,
  });

  factory PublicLiveMatchInfo.fromJson(Map<String, dynamic> json) => PublicLiveMatchInfo(
        id: json['id'] as String,
        status: MatchStatus.fromValue(json['status'] as String),
        oversLimit: (json['oversLimit'] as num?)?.toInt(),
        homeTournamentTeamId: json['homeTournamentTeamId'] as String?,
        awayTournamentTeamId: json['awayTournamentTeamId'] as String?,
        resultSummary: json['resultSummary'] as String?,
        winnerTournamentTeamId: json['winnerTournamentTeamId'] as String?,
      );

  final String id;
  final MatchStatus status;
  final int? oversLimit;
  final String? homeTournamentTeamId;
  final String? awayTournamentTeamId;
  final String? resultSummary;
  final String? winnerTournamentTeamId;
}

class PublicLiveInnings {
  const PublicLiveInnings({
    required this.inningsId,
    required this.inningsNumber,
    this.battingTournamentTeamId,
    this.bowlingTournamentTeamId,
    required this.status,
    required this.totalRuns,
    required this.totalWickets,
    required this.totalOversBowled,
    required this.extrasTotal,
    this.striker,
    this.nonStriker,
    this.currentOver,
    this.currentPartnership,
    this.recentBalls = const [],
  });

  factory PublicLiveInnings.fromJson(Map<String, dynamic> json) => PublicLiveInnings(
        inningsId: json['inningsId'] as String,
        inningsNumber: (json['inningsNumber'] as num).toInt(),
        battingTournamentTeamId: json['battingTournamentTeamId'] as String?,
        bowlingTournamentTeamId: json['bowlingTournamentTeamId'] as String?,
        status: json['status'] as String,
        totalRuns: (json['totalRuns'] as num?)?.toInt() ?? 0,
        totalWickets: (json['totalWickets'] as num?)?.toInt() ?? 0,
        // Backend `decimal` column -> serialized as a string, e.g. "15.2"
        // meaning 15 overs + 2 balls (overs.balls notation, NOT a decimal
        // fraction of an over) — kept as a string and displayed verbatim,
        // never parsed as a fraction.
        totalOversBowled: json['totalOversBowled'] as String? ?? '0.0',
        extrasTotal: (json['extrasTotal'] as num?)?.toInt() ?? 0,
        striker: json['striker'] != null
            ? PublicBattingFigures.fromJson(json['striker'] as Map<String, dynamic>)
            : null,
        nonStriker: json['nonStriker'] != null
            ? PublicBattingFigures.fromJson(json['nonStriker'] as Map<String, dynamic>)
            : null,
        currentOver: json['currentOver'] != null
            ? PublicCurrentOver.fromJson(json['currentOver'] as Map<String, dynamic>)
            : null,
        currentPartnership: json['currentPartnership'] != null
            ? PublicPartnership.fromJson(json['currentPartnership'] as Map<String, dynamic>)
            : null,
        recentBalls: (json['recentBalls'] as List<dynamic>? ?? [])
            .map((e) => PublicBallSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String inningsId;
  final int inningsNumber;
  final String? battingTournamentTeamId;
  final String? bowlingTournamentTeamId;

  /// One of `in_progress` | `completed` (`InningsStatus`).
  final String status;
  final int totalRuns;
  final int totalWickets;

  /// Overs.balls notation as a string (e.g. `"15.2"`) — display verbatim.
  final String totalOversBowled;
  final int extrasTotal;
  final PublicBattingFigures? striker;
  final PublicBattingFigures? nonStriker;
  final PublicCurrentOver? currentOver;
  final PublicPartnership? currentPartnership;
  final List<PublicBallSummary> recentBalls;

  /// `"105/3"`-style scoreline for compact display (e.g. the LIVE NOW card).
  String get scoreline => '$totalRuns/$totalWickets';
}

/// A player's name + team-player id, resolved server-side from
/// `TeamPlayer.player.fullName` — mirrors `playerLabel`'s return shape in
/// `scoring-realtime.service.ts`.
class PublicPlayerLabel {
  const PublicPlayerLabel({required this.teamPlayerId, required this.fullName});

  factory PublicPlayerLabel.fromJson(Map<String, dynamic> json) => PublicPlayerLabel(
        teamPlayerId: json['teamPlayerId'] as String,
        fullName: json['fullName'] as String,
      );

  final String teamPlayerId;
  final String fullName;
}

/// A batter's live figures within the current innings — mirrors
/// `battingFiguresFor`'s return shape, spread onto a [PublicPlayerLabel].
class PublicBattingFigures {
  const PublicBattingFigures({
    required this.teamPlayerId,
    required this.fullName,
    required this.runs,
    required this.ballsFaced,
    required this.fours,
    required this.sixes,
    required this.strikeRate,
    required this.isOut,
    this.dismissalType,
  });

  factory PublicBattingFigures.fromJson(Map<String, dynamic> json) => PublicBattingFigures(
        teamPlayerId: json['teamPlayerId'] as String,
        fullName: json['fullName'] as String,
        runs: (json['runs'] as num?)?.toInt() ?? 0,
        ballsFaced: (json['ballsFaced'] as num?)?.toInt() ?? 0,
        fours: (json['fours'] as num?)?.toInt() ?? 0,
        sixes: (json['sixes'] as num?)?.toInt() ?? 0,
        strikeRate: (json['strikeRate'] as num?)?.toDouble() ?? 0,
        isOut: json['isOut'] as bool? ?? false,
        dismissalType: json['dismissalType'] as String?,
      );

  final String teamPlayerId;
  final String fullName;
  final int runs;
  final int ballsFaced;
  final int fours;
  final int sixes;
  final double strikeRate;
  final bool isOut;
  final String? dismissalType;
}

/// A bowler's live figures within the current innings — mirrors
/// `bowlingFiguresFor`'s return shape. `overs` here is a computed JS number
/// (e.g. `1.2`), unlike [PublicLiveInnings.totalOversBowled] which is a raw
/// decimal-column string — both use overs.balls notation, just serialized
/// differently by the backend.
class PublicBowlingFigures {
  const PublicBowlingFigures({
    required this.overs,
    required this.runsConceded,
    required this.wickets,
    required this.maidens,
    required this.economy,
  });

  factory PublicBowlingFigures.fromJson(Map<String, dynamic> json) => PublicBowlingFigures(
        overs: (json['overs'] as num?)?.toDouble() ?? 0,
        runsConceded: (json['runsConceded'] as num?)?.toInt() ?? 0,
        wickets: (json['wickets'] as num?)?.toInt() ?? 0,
        maidens: (json['maidens'] as num?)?.toInt() ?? 0,
        economy: (json['economy'] as num?)?.toDouble() ?? 0,
      );

  final double overs;
  final int runsConceded;
  final int wickets;
  final int maidens;
  final double economy;
}

class PublicCurrentOver {
  const PublicCurrentOver({
    required this.overNumber,
    this.bowler,
    required this.runsConceded,
    required this.wickets,
    required this.status,
    this.bowlerInningsFigures,
  });

  factory PublicCurrentOver.fromJson(Map<String, dynamic> json) => PublicCurrentOver(
        overNumber: (json['overNumber'] as num).toInt(),
        bowler: json['bowler'] != null
            ? PublicPlayerLabel.fromJson(json['bowler'] as Map<String, dynamic>)
            : null,
        runsConceded: (json['runsConceded'] as num?)?.toInt() ?? 0,
        wickets: (json['wickets'] as num?)?.toInt() ?? 0,
        status: json['status'] as String,
        bowlerInningsFigures: json['bowlerInningsFigures'] != null
            ? PublicBowlingFigures.fromJson(json['bowlerInningsFigures'] as Map<String, dynamic>)
            : null,
      );

  final int overNumber;
  final PublicPlayerLabel? bowler;
  final int runsConceded;
  final int wickets;

  /// One of `in_progress` | `completed` (`OverStatus`).
  final String status;
  final PublicBowlingFigures? bowlerInningsFigures;
}

class PublicPartnership {
  const PublicPartnership({
    required this.batter1,
    required this.batter2,
    required this.runs,
    required this.ballsFaced,
  });

  factory PublicPartnership.fromJson(Map<String, dynamic> json) => PublicPartnership(
        batter1: PublicPlayerLabel.fromJson(json['batter1'] as Map<String, dynamic>),
        batter2: PublicPlayerLabel.fromJson(json['batter2'] as Map<String, dynamic>),
        runs: (json['runs'] as num?)?.toInt() ?? 0,
        ballsFaced: (json['ballsFaced'] as num?)?.toInt() ?? 0,
      );

  final PublicPlayerLabel batter1;
  final PublicPlayerLabel batter2;
  final int runs;
  final int ballsFaced;
}

/// One ball-by-ball commentary entry — mirrors the last-12-balls window
/// `buildInningsSnapshot` returns.
class PublicBallSummary {
  const PublicBallSummary({
    required this.sequenceNumber,
    this.overNumber,
    required this.ballNumberInOver,
    required this.runsBatter,
    required this.runsExtra,
    this.extraType,
    required this.isWicket,
    this.dismissalType,
    this.commentaryText,
  });

  factory PublicBallSummary.fromJson(Map<String, dynamic> json) => PublicBallSummary(
        sequenceNumber: (json['sequenceNumber'] as num).toInt(),
        overNumber: (json['overNumber'] as num?)?.toInt(),
        ballNumberInOver: (json['ballNumberInOver'] as num?)?.toInt() ?? 0,
        runsBatter: (json['runsBatter'] as num?)?.toInt() ?? 0,
        runsExtra: (json['runsExtra'] as num?)?.toInt() ?? 0,
        extraType: json['extraType'] as String?,
        isWicket: json['isWicket'] as bool? ?? false,
        dismissalType: json['dismissalType'] as String?,
        commentaryText: json['commentaryText'] as String?,
      );

  final int sequenceNumber;
  final int? overNumber;
  final int ballNumberInOver;
  final int runsBatter;
  final int runsExtra;
  final String? extraType;
  final bool isWicket;
  final String? dismissalType;
  final String? commentaryText;
}
