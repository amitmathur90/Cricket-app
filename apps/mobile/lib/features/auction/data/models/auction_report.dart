/// Mirrors the `teams[]` entries of `AuctionService.getReport`'s response
/// (apps/backend/src/modules/auction/auction.service.ts).
class AuctionTeamSummary {
  const AuctionTeamSummary({
    required this.tournamentTeamId,
    required this.teamName,
    required this.purseTotal,
    required this.purseRemaining,
    required this.playersBought,
    required this.totalSpent,
  });

  factory AuctionTeamSummary.fromJson(Map<String, dynamic> json) => AuctionTeamSummary(
        tournamentTeamId: json['tournamentTeamId'] as String,
        teamName: json['teamName'] as String,
        purseTotal: json['purseTotal'] as String?,
        purseRemaining: json['purseRemaining'] as String?,
        playersBought: json['playersBought'] as int,
        totalSpent: json['totalSpent'] as String,
      );

  final String tournamentTeamId;
  final String teamName;

  /// Decimal-as-string; null when the team has no purse configured.
  final String? purseTotal;
  final String? purseRemaining;
  final int playersBought;
  final String totalSpent;
}

/// Mirrors the `players[]` entries of `AuctionService.getReport`'s response.
class AuctionPlayerOutcome {
  const AuctionPlayerOutcome({
    required this.playerId,
    required this.playerName,
    required this.status,
    required this.basePrice,
    this.finalPrice,
    this.soldToTeamId,
    this.soldToTeamName,
  });

  factory AuctionPlayerOutcome.fromJson(Map<String, dynamic> json) => AuctionPlayerOutcome(
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String,
        status: json['status'] as String,
        basePrice: json['basePrice'] as String,
        finalPrice: json['finalPrice'] as String?,
        soldToTeamId: json['soldToTeamId'] as String?,
        soldToTeamName: json['soldToTeamName'] as String?,
      );

  final String playerId;
  final String playerName;

  /// Raw `AuctionPoolStatus` string (pending/in_progress/sold/unsold).
  final String status;
  final String basePrice;
  final String? finalPrice;
  final String? soldToTeamId;
  final String? soldToTeamName;
}

class AuctionReportSessionInfo {
  const AuctionReportSessionInfo({
    required this.id,
    required this.name,
    required this.status,
    this.startedAt,
    this.endedAt,
  });

  factory AuctionReportSessionInfo.fromJson(Map<String, dynamic> json) => AuctionReportSessionInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        status: json['status'] as String,
        startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'] as String) : null,
        endedAt: json['endedAt'] != null ? DateTime.tryParse(json['endedAt'] as String) : null,
      );

  final String id;
  final String name;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
}

/// Mirrors `AuctionService.getReport`'s full response shape.
class AuctionReport {
  const AuctionReport({required this.session, required this.teams, required this.players});

  factory AuctionReport.fromJson(Map<String, dynamic> json) => AuctionReport(
        session: AuctionReportSessionInfo.fromJson(json['session'] as Map<String, dynamic>),
        teams: (json['teams'] as List<dynamic>)
            .map((e) => AuctionTeamSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        players: (json['players'] as List<dynamic>)
            .map((e) => AuctionPlayerOutcome.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final AuctionReportSessionInfo session;
  final List<AuctionTeamSummary> teams;
  final List<AuctionPlayerOutcome> players;
}
