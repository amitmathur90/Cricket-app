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
      );

  final String id;
  final String tournamentId;
  final String name;
  final AuctionSessionStatus status;
  final String? currentPlayerId;

  /// Decimal-as-string, matching the backend's `numeric` column serialization.
  final String? currentBidAmount;
  final String? currentBidTeamId;
  final DateTime? currentLotEndsAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
}
