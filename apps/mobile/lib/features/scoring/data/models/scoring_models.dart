/// Mirrors the JSON shapes returned by `ScoringRealtimeService.getLiveState`
/// / `getScorecard` (apps/backend/src/modules/scoring/scoring-realtime.service.ts)
/// and broadcast by `ScoringGateway` — every `scoring.*` WS event (except
/// `scoring.inningsCompleted`, which wraps this under a `state` key — see
/// ScoringRoomController) carries exactly [LiveScoringState]'s shape as its
/// payload.
///
/// Field-for-field notes (these shapes are NOT uniform — read carefully
/// before extending):
///  - `ScoringPlayerLabel` is the bare `{teamPlayerId, fullName}` shape used
///    for `currentOver.bowler` and `currentPartnership.batter1/2`.
///  - `ScoringBatterFigures` is a MERGED label+batting-figures shape
///    (`{...label, ...figures}` server-side) used for `striker`/
///    `nonStriker` here AND for each entry of `getScorecard`'s `batting[]`.
///  - `ScoringBowlingFigures` is BARE figures (no label) — only
///    `currentOver.bowlerInningsFigures` uses this shape.
///  - `ScoringBowlerFigures` is the MERGED label+bowling-figures shape used
///    for each entry of `getScorecard`'s `bowling[]` — deliberately a
///    separate class from `ScoringBowlingFigures` since the two payloads
///    are shaped differently server-side.
library;

/// Bare `{teamPlayerId, fullName}` label.
class ScoringPlayerLabel {
  const ScoringPlayerLabel({required this.teamPlayerId, required this.fullName});

  factory ScoringPlayerLabel.fromJson(Map<String, dynamic> json) => ScoringPlayerLabel(
        teamPlayerId: json['teamPlayerId'] as String,
        fullName: json['fullName'] as String,
      );

  final String teamPlayerId;
  final String fullName;
}

/// Merged label + live batting figures — `striker`/`nonStriker` in
/// [LiveScoringState], and each `batting[]` entry of a scorecard.
class ScoringBatterFigures {
  const ScoringBatterFigures({
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

  factory ScoringBatterFigures.fromJson(Map<String, dynamic> json) => ScoringBatterFigures(
        teamPlayerId: json['teamPlayerId'] as String,
        fullName: json['fullName'] as String,
        runs: json['runs'] as int? ?? 0,
        ballsFaced: json['ballsFaced'] as int? ?? 0,
        fours: json['fours'] as int? ?? 0,
        sixes: json['sixes'] as int? ?? 0,
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

/// Bare bowling figures (no label) — only `currentOver.bowlerInningsFigures`.
class ScoringBowlingFigures {
  const ScoringBowlingFigures({
    required this.overs,
    required this.runsConceded,
    required this.wickets,
    required this.maidens,
    required this.economy,
  });

  factory ScoringBowlingFigures.fromJson(Map<String, dynamic> json) => ScoringBowlingFigures(
        overs: (json['overs'] as num?)?.toDouble() ?? 0,
        runsConceded: json['runsConceded'] as int? ?? 0,
        wickets: json['wickets'] as int? ?? 0,
        maidens: json['maidens'] as int? ?? 0,
        economy: (json['economy'] as num?)?.toDouble() ?? 0,
      );

  final double overs;
  final int runsConceded;
  final int wickets;
  final int maidens;
  final double economy;
}

/// Merged label + bowling figures — each `bowling[]` entry of a scorecard.
class ScoringBowlerFigures {
  const ScoringBowlerFigures({
    required this.teamPlayerId,
    required this.fullName,
    required this.overs,
    required this.runsConceded,
    required this.wickets,
    required this.maidens,
    required this.economy,
  });

  factory ScoringBowlerFigures.fromJson(Map<String, dynamic> json) => ScoringBowlerFigures(
        teamPlayerId: json['teamPlayerId'] as String,
        fullName: json['fullName'] as String,
        overs: (json['overs'] as num?)?.toDouble() ?? 0,
        runsConceded: json['runsConceded'] as int? ?? 0,
        wickets: json['wickets'] as int? ?? 0,
        maidens: json['maidens'] as int? ?? 0,
        economy: (json['economy'] as num?)?.toDouble() ?? 0,
      );

  final String teamPlayerId;
  final String fullName;
  final double overs;
  final int runsConceded;
  final int wickets;
  final int maidens;
  final double economy;
}

/// `currentOver` — null whenever no over is currently in progress (i.e. an
/// over just completed and `new-bowler` hasn't been called yet for the
/// next one). The screen must treat this null as "prompt for next bowler
/// before allowing further scoring" — see LiveScoringScreen.
class ScoringCurrentOver {
  const ScoringCurrentOver({
    required this.overNumber,
    this.bowler,
    required this.runsConceded,
    required this.wickets,
    required this.status,
    this.bowlerInningsFigures,
  });

  factory ScoringCurrentOver.fromJson(Map<String, dynamic> json) => ScoringCurrentOver(
        overNumber: json['overNumber'] as int,
        bowler: json['bowler'] != null
            ? ScoringPlayerLabel.fromJson(json['bowler'] as Map<String, dynamic>)
            : null,
        runsConceded: json['runsConceded'] as int? ?? 0,
        wickets: json['wickets'] as int? ?? 0,
        status: json['status'] as String,
        bowlerInningsFigures: json['bowlerInningsFigures'] != null
            ? ScoringBowlingFigures.fromJson(json['bowlerInningsFigures'] as Map<String, dynamic>)
            : null,
      );

  final int overNumber;
  final ScoringPlayerLabel? bowler;
  final int runsConceded;
  final int wickets;

  /// Raw `OverStatus` string ('in_progress' | 'completed'). This snapshot
  /// only ever carries the in-progress over (see class doc), so in practice
  /// this is always 'in_progress' when present — kept as the raw string
  /// rather than assumed, in case that ever changes server-side.
  final String status;
  final ScoringBowlingFigures? bowlerInningsFigures;
}

class ScoringPartnership {
  const ScoringPartnership({this.batter1, this.batter2, required this.runs, required this.ballsFaced});

  factory ScoringPartnership.fromJson(Map<String, dynamic> json) => ScoringPartnership(
        batter1:
            json['batter1'] != null ? ScoringPlayerLabel.fromJson(json['batter1'] as Map<String, dynamic>) : null,
        batter2:
            json['batter2'] != null ? ScoringPlayerLabel.fromJson(json['batter2'] as Map<String, dynamic>) : null,
        runs: json['runs'] as int? ?? 0,
        ballsFaced: json['ballsFaced'] as int? ?? 0,
      );

  final ScoringPlayerLabel? batter1;
  final ScoringPlayerLabel? batter2;
  final int runs;
  final int ballsFaced;
}

/// One entry of `recentBalls` (last ~12 non-voided balls, oldest first).
/// Deliberately does NOT carry striker/non-striker/bowler ids — the
/// snapshot only needs this for the current-over ball strip and the undo
/// confirmation summary, neither of which needs to name the batter.
class ScoringRecentBall {
  const ScoringRecentBall({
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

  factory ScoringRecentBall.fromJson(Map<String, dynamic> json) => ScoringRecentBall(
        sequenceNumber: json['sequenceNumber'] as int,
        overNumber: json['overNumber'] as int?,
        ballNumberInOver: json['ballNumberInOver'] as int,
        runsBatter: json['runsBatter'] as int? ?? 0,
        runsExtra: json['runsExtra'] as int? ?? 0,
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

  /// Raw `ExtraType` string ('wide' | 'no_ball' | 'bye' | 'leg_bye' | 'penalty'), or null.
  final String? extraType;
  final bool isWicket;

  /// Raw `DismissalType` string, or null.
  final String? dismissalType;
  final String? commentaryText;
}

class ScoringInningsSnapshot {
  const ScoringInningsSnapshot({
    required this.inningsId,
    required this.inningsNumber,
    required this.battingTournamentTeamId,
    required this.bowlingTournamentTeamId,
    required this.status,
    required this.totalRuns,
    required this.totalWickets,
    required this.totalOversBowled,
    required this.extrasTotal,
    this.striker,
    this.nonStriker,
    this.currentOver,
    this.currentPartnership,
    required this.recentBalls,
  });

  factory ScoringInningsSnapshot.fromJson(Map<String, dynamic> json) => ScoringInningsSnapshot(
        inningsId: json['inningsId'] as String,
        inningsNumber: json['inningsNumber'] as int,
        battingTournamentTeamId: json['battingTournamentTeamId'] as String,
        bowlingTournamentTeamId: json['bowlingTournamentTeamId'] as String,
        status: json['status'] as String,
        totalRuns: json['totalRuns'] as int? ?? 0,
        totalWickets: json['totalWickets'] as int? ?? 0,
        // Decimal column on the Innings entity -> serialized as a string
        // (e.g. "15.2"), same convention as every other `decimal` column in
        // this app (see Player.basePrice/rating, AuctionLiveTeam.purseTotal).
        totalOversBowled: json['totalOversBowled'] as String? ?? '0.0',
        extrasTotal: json['extrasTotal'] as int? ?? 0,
        striker: json['striker'] != null
            ? ScoringBatterFigures.fromJson(json['striker'] as Map<String, dynamic>)
            : null,
        nonStriker: json['nonStriker'] != null
            ? ScoringBatterFigures.fromJson(json['nonStriker'] as Map<String, dynamic>)
            : null,
        currentOver: json['currentOver'] != null
            ? ScoringCurrentOver.fromJson(json['currentOver'] as Map<String, dynamic>)
            : null,
        currentPartnership: json['currentPartnership'] != null
            ? ScoringPartnership.fromJson(json['currentPartnership'] as Map<String, dynamic>)
            : null,
        recentBalls: ((json['recentBalls'] as List<dynamic>?) ?? const [])
            .map((e) => ScoringRecentBall.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String inningsId;
  final int inningsNumber;
  final String battingTournamentTeamId;
  final String bowlingTournamentTeamId;

  /// Raw `InningsStatus` string ('in_progress' | 'completed').
  final String status;
  final int totalRuns;
  final int totalWickets;

  /// `overs.balls` display string, e.g. "15.2" — NOT a true decimal.
  final String totalOversBowled;
  final int extrasTotal;
  final ScoringBatterFigures? striker;
  final ScoringBatterFigures? nonStriker;
  final ScoringCurrentOver? currentOver;
  final ScoringPartnership? currentPartnership;

  /// Oldest first, last ~12 non-voided balls of THIS innings.
  final List<ScoringRecentBall> recentBalls;
}

class ScoringMatchSummary {
  const ScoringMatchSummary({
    required this.id,
    required this.status,
    this.oversLimit,
    this.homeTournamentTeamId,
    this.awayTournamentTeamId,
    this.resultSummary,
    this.winnerTournamentTeamId,
  });

  factory ScoringMatchSummary.fromJson(Map<String, dynamic> json) => ScoringMatchSummary(
        id: json['id'] as String,
        status: json['status'] as String,
        oversLimit: json['oversLimit'] as int?,
        homeTournamentTeamId: json['homeTournamentTeamId'] as String?,
        awayTournamentTeamId: json['awayTournamentTeamId'] as String?,
        resultSummary: json['resultSummary'] as String?,
        winnerTournamentTeamId: json['winnerTournamentTeamId'] as String?,
      );

  final String id;

  /// Raw `MatchStatus` string — mirrors `MatchStatus.value` in
  /// features/matches/data/models/match.dart ('scheduled' | 'live' |
  /// 'completed' | 'cancelled').
  final String status;
  final int? oversLimit;
  final String? homeTournamentTeamId;
  final String? awayTournamentTeamId;
  final String? resultSummary;
  final String? winnerTournamentTeamId;
}

/// Full `GET .../scoring/live-state` response — also every `scoring.*`
/// WS broadcast payload's shape (post-unwrapping for `inningsCompleted`;
/// see ScoringRoomController).
class LiveScoringState {
  const LiveScoringState({required this.match, required this.innings});

  factory LiveScoringState.fromJson(Map<String, dynamic> json) => LiveScoringState(
        match: ScoringMatchSummary.fromJson(json['match'] as Map<String, dynamic>),
        innings: ((json['innings'] as List<dynamic>?) ?? const [])
            .map((e) => ScoringInningsSnapshot.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final ScoringMatchSummary match;

  /// Ordered by `inningsNumber` ascending — one entry per innings that has
  /// actually started (0, 1, or 2 entries).
  final List<ScoringInningsSnapshot> innings;

  /// The innings currently accepting balls, or the most recently completed
  /// one if none is in progress (e.g. between innings 1 completing and
  /// innings 2 starting) — the last entry either way, since `innings` is
  /// created in order and never reordered.
  ScoringInningsSnapshot? get currentInnings => innings.isEmpty ? null : innings.last;

  ScoringInningsSnapshot? get firstInnings => innings.isEmpty ? null : innings.first;

  /// Target for the second innings (`innings1.totalRuns + 1`) — the backend
  /// doesn't surface this field directly, so it's computed here per the
  /// spec. Null unless the second innings has actually started.
  int? get target => innings.length >= 2 ? innings.first.totalRuns + 1 : null;
}

// ---------------------------------------------------------------------
// GET .../scoring/scorecard
// ---------------------------------------------------------------------

class ScoringInningsCard {
  const ScoringInningsCard({
    required this.inningsId,
    required this.inningsNumber,
    required this.battingTournamentTeamId,
    required this.bowlingTournamentTeamId,
    required this.status,
    required this.totalRuns,
    required this.totalWickets,
    required this.totalOversBowled,
    required this.extrasTotal,
    required this.batting,
    required this.bowling,
  });

  factory ScoringInningsCard.fromJson(Map<String, dynamic> json) => ScoringInningsCard(
        inningsId: json['inningsId'] as String,
        inningsNumber: json['inningsNumber'] as int,
        battingTournamentTeamId: json['battingTournamentTeamId'] as String,
        bowlingTournamentTeamId: json['bowlingTournamentTeamId'] as String,
        status: json['status'] as String,
        totalRuns: json['totalRuns'] as int? ?? 0,
        totalWickets: json['totalWickets'] as int? ?? 0,
        totalOversBowled: json['totalOversBowled'] as String? ?? '0.0',
        extrasTotal: json['extrasTotal'] as int? ?? 0,
        batting: ((json['batting'] as List<dynamic>?) ?? const [])
            .map((e) => ScoringBatterFigures.fromJson(e as Map<String, dynamic>))
            .toList(),
        bowling: ((json['bowling'] as List<dynamic>?) ?? const [])
            .map((e) => ScoringBowlerFigures.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String inningsId;
  final int inningsNumber;
  final String battingTournamentTeamId;
  final String bowlingTournamentTeamId;
  final String status;
  final int totalRuns;
  final int totalWickets;
  final String totalOversBowled;
  final int extrasTotal;
  final List<ScoringBatterFigures> batting;
  final List<ScoringBowlerFigures> bowling;
}

class MatchScorecard {
  const MatchScorecard({required this.matchId, this.resultSummary, this.winnerTournamentTeamId, required this.innings});

  factory MatchScorecard.fromJson(Map<String, dynamic> json) {
    final match = json['match'] as Map<String, dynamic>;
    return MatchScorecard(
      matchId: match['id'] as String,
      resultSummary: match['resultSummary'] as String?,
      winnerTournamentTeamId: match['winnerTournamentTeamId'] as String?,
      innings: ((json['innings'] as List<dynamic>?) ?? const [])
          .map((e) => ScoringInningsCard.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String matchId;
  final String? resultSummary;
  final String? winnerTournamentTeamId;
  final List<ScoringInningsCard> innings;
}

// ---------------------------------------------------------------------
// Client-side enums for submitting recordBall — mirror
// apps/backend/src/database/entities/ball.entity.ts's ExtraType/DismissalType
// exactly (raw string values are what the API expects).
// ---------------------------------------------------------------------

enum ScoringExtraType { wide, noBall, bye, legBye, penalty }

extension ScoringExtraTypeX on ScoringExtraType {
  String get apiValue => switch (this) {
        ScoringExtraType.wide => 'wide',
        ScoringExtraType.noBall => 'no_ball',
        ScoringExtraType.bye => 'bye',
        ScoringExtraType.legBye => 'leg_bye',
        ScoringExtraType.penalty => 'penalty',
      };

  String get label => switch (this) {
        ScoringExtraType.wide => 'Wide',
        ScoringExtraType.noBall => 'No ball',
        ScoringExtraType.bye => 'Bye',
        ScoringExtraType.legBye => 'Leg bye',
        ScoringExtraType.penalty => 'Penalty',
      };

  String get shortLabel => switch (this) {
        ScoringExtraType.wide => 'WD',
        ScoringExtraType.noBall => 'NB',
        ScoringExtraType.bye => 'BYE',
        ScoringExtraType.legBye => 'LB',
        ScoringExtraType.penalty => 'PEN',
      };
}

enum ScoringDismissalType { bowled, caught, lbw, runOut, stumped, hitWicket, retiredHurt }

extension ScoringDismissalTypeX on ScoringDismissalType {
  String get apiValue => switch (this) {
        ScoringDismissalType.bowled => 'bowled',
        ScoringDismissalType.caught => 'caught',
        ScoringDismissalType.lbw => 'lbw',
        ScoringDismissalType.runOut => 'run_out',
        ScoringDismissalType.stumped => 'stumped',
        ScoringDismissalType.hitWicket => 'hit_wicket',
        ScoringDismissalType.retiredHurt => 'retired_hurt',
      };

  String get label => switch (this) {
        ScoringDismissalType.bowled => 'Bowled',
        ScoringDismissalType.caught => 'Caught',
        ScoringDismissalType.lbw => 'LBW',
        ScoringDismissalType.runOut => 'Run out',
        ScoringDismissalType.stumped => 'Stumped',
        ScoringDismissalType.hitWicket => 'Hit wicket',
        ScoringDismissalType.retiredHurt => 'Retired hurt',
      };

  /// Whether a fielder is typically credited for this dismissal type — used
  /// to decide whether to show the fielder picker in the wicket dialog.
  bool get usuallyHasFielder =>
      this == ScoringDismissalType.caught || this == ScoringDismissalType.runOut || this == ScoringDismissalType.stumped;
}

/// Human-readable label for a raw dismissal-type string (from `recentBalls`/
/// `striker.dismissalType`/etc.), tolerant of an unrecognized value.
String dismissalTypeLabel(String? raw) {
  if (raw == null) return '';
  for (final type in ScoringDismissalType.values) {
    if (type.apiValue == raw) return type.label;
  }
  return raw;
}
