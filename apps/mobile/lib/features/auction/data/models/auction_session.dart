/// Mirrors `AuctionSessionStatus` in
/// apps/backend/src/database/entities/auction-session.entity.ts.
enum AuctionSessionStatus { scheduled, live, paused, completed }

extension AuctionSessionStatusX on AuctionSessionStatus {
  String get apiValue => switch (this) {
        AuctionSessionStatus.scheduled => 'scheduled',
        AuctionSessionStatus.live => 'live',
        AuctionSessionStatus.paused => 'paused',
        AuctionSessionStatus.completed => 'completed',
      };

  String get label => switch (this) {
        AuctionSessionStatus.scheduled => 'Scheduled',
        AuctionSessionStatus.live => 'Live',
        AuctionSessionStatus.paused => 'Paused',
        AuctionSessionStatus.completed => 'Completed',
      };

  static AuctionSessionStatus fromApi(String value) => AuctionSessionStatus.values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => AuctionSessionStatus.scheduled,
      );
}

/// One tier of the tiered bid-increment schedule, as returned on the
/// session's `bidIncrementRules` (mirrors `BidIncrementRule` in
/// auction-session.entity.ts). `upTo: null` is the catch-all top tier —
/// applies above every other tier's ceiling.
class AuctionBidIncrementTier {
  const AuctionBidIncrementTier({required this.increment, this.upTo});

  factory AuctionBidIncrementTier.fromJson(Map<String, dynamic> json) => AuctionBidIncrementTier(
        upTo: json['upTo'] as num?,
        increment: json['increment'] as num,
      );

  final num? upTo;
  final num increment;
}

/// Mirrors apps/backend/src/database/entities/auction-session.entity.ts.
class AuctionSession {
  const AuctionSession({
    required this.id,
    required this.tournamentId,
    required this.name,
    required this.status,
    this.currentPlayerId,
    this.currentBidAmount,
    this.currentBidTeamId,
    this.currentLotEndsAt,
    this.startedAt,
    this.endedAt,
    this.durationMinutes,
    this.defaultTeamPoints,
    this.maxSquadSize,
    this.bidIncrementRules,
  });

  factory AuctionSession.fromJson(Map<String, dynamic> json) => AuctionSession(
        id: json['id'] as String,
        tournamentId: json['tournamentId'] as String,
        name: json['name'] as String,
        status: AuctionSessionStatusX.fromApi(json['status'] as String? ?? 'scheduled'),
        currentPlayerId: json['currentPlayerId'] as String?,
        currentBidAmount: json['currentBidAmount'] as String?,
        currentBidTeamId: json['currentBidTeamId'] as String?,
        currentLotEndsAt: json['currentLotEndsAt'] != null
            ? DateTime.tryParse(json['currentLotEndsAt'] as String)
            : null,
        startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'] as String) : null,
        endedAt: json['endedAt'] != null ? DateTime.tryParse(json['endedAt'] as String) : null,
        durationMinutes: json['durationMinutes'] as int?,
        defaultTeamPoints: json['defaultTeamPoints'] as String?,
        maxSquadSize: json['maxSquadSize'] as int?,
        bidIncrementRules: (json['bidIncrementRules'] as List<dynamic>?)
            ?.map((e) => AuctionBidIncrementTier.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String tournamentId;
  final String name;
  final AuctionSessionStatus status;
  final String? currentPlayerId;

  /// Decimal-as-string, matching the backend's `numeric` column serialization.
  final String? currentBidAmount;
  final String? currentBidTeamId;

  /// Always null — the column is kept on the entity (to avoid a destructive
  /// migration) but nothing writes to it anymore; there is no auto-timer.
  /// Never read as a deadline.
  final DateTime? currentLotEndsAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Informational total-time budget for the whole session, in minutes.
  /// Never enforced server-side; null when unset (don't fabricate a
  /// countdown for it).
  final int? durationMinutes;

  /// Decimal-as-string. Starting purse applied to every registered team
  /// when the session starts (not at creation time). Null leaves each
  /// team's existing purse untouched.
  final String? defaultTeamPoints;

  /// Max roster size per team; a team at this count is rejected from
  /// bidding ("SQUAD FULL"). Null means no cap.
  final int? maxSquadSize;

  /// Optional tiered bid-increment schedule (see `computeMinIncrement` in
  /// auction-bid-increment.util.ts). Null/empty means the backend falls back
  /// to its default 5%-of-current-bid formula. Not carried on the WS
  /// `auction.stateSync`/`auction.playerUp` payloads (see
  /// AuctionRealtimeService.buildStateSyncPayload) — only this REST
  /// session fetch has it, which is why the live room's "Next Bid" preview
  /// (bid_increment.dart's `computeMinIncrement`) reads it from here rather
  /// than from socket state.
  final List<AuctionBidIncrementTier>? bidIncrementRules;
}
