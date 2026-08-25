/// Mirrors apps/backend/src/database/entities/auction-bid.entity.ts
/// (`AuctionService.listBids` response — relations: team, team.team). Used
/// for the REST bid-history endpoint; the live room instead builds its feed
/// from `auction.bidPlaced` socket events (see auction_realtime_models.dart).
class AuctionBidRecord {
  const AuctionBidRecord({
    required this.id,
    required this.auctionSessionId,
    required this.auctionPlayerPoolId,
    required this.teamId,
    required this.teamName,
    required this.bidAmount,
    required this.bidSequence,
    required this.createdAt,
  });

  factory AuctionBidRecord.fromJson(Map<String, dynamic> json) {
    final team = json['team'] as Map<String, dynamic>?;
    final teamBrand = team?['team'] as Map<String, dynamic>?;
    return AuctionBidRecord(
      id: json['id'] as String,
      auctionSessionId: json['auctionSessionId'] as String,
      auctionPlayerPoolId: json['auctionPlayerPoolId'] as String,
      teamId: json['teamId'] as String,
      teamName: teamBrand?['name'] as String? ?? 'Unknown team',
      bidAmount: json['bidAmount'] as String,
      bidSequence: json['bidSequence'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String auctionSessionId;
  final String auctionPlayerPoolId;
  final String teamId;
  final String teamName;

  /// Decimal-as-string.
  final String bidAmount;
  final int bidSequence;
  final DateTime createdAt;
}
