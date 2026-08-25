/// Mirrors one entry of the `bids[]` array in `AuctionService
/// .getPlayerPurchaseHistory`'s response
/// (apps/backend/src/modules/auction/auction.service.ts).
class PurchaseHistoryBid {
  const PurchaseHistoryBid({
    required this.teamId,
    required this.teamName,
    required this.amount,
    required this.bidSequence,
    required this.createdAt,
  });

  factory PurchaseHistoryBid.fromJson(Map<String, dynamic> json) => PurchaseHistoryBid(
        teamId: json['teamId'] as String,
        teamName: json['teamName'] as String,
        amount: json['amount'] as String,
        bidSequence: json['bidSequence'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String teamId;
  final String teamName;
  final String amount;
  final int bidSequence;
  final DateTime createdAt;
}

/// One session a player appeared in, mirroring the `history[]` entries of
/// `getPlayerPurchaseHistory`'s response.
class PurchaseHistoryEntry {
  const PurchaseHistoryEntry({
    required this.auctionSessionId,
    required this.auctionSessionName,
    required this.tournamentId,
    required this.status,
    required this.basePrice,
    required this.bids,
    this.finalPrice,
    this.soldToTeamId,
    this.soldToTeamName,
  });

  factory PurchaseHistoryEntry.fromJson(Map<String, dynamic> json) => PurchaseHistoryEntry(
        auctionSessionId: json['auctionSessionId'] as String,
        auctionSessionName: json['auctionSessionName'] as String,
        tournamentId: json['tournamentId'] as String,
        status: json['status'] as String,
        basePrice: json['basePrice'] as String,
        finalPrice: json['finalPrice'] as String?,
        soldToTeamId: json['soldToTeamId'] as String?,
        soldToTeamName: json['soldToTeamName'] as String?,
        bids: (json['bids'] as List<dynamic>)
            .map((e) => PurchaseHistoryBid.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String auctionSessionId;
  final String auctionSessionName;
  final String tournamentId;

  /// Raw `AuctionPoolStatus` string (pending/in_progress/sold/unsold).
  final String status;
  final String basePrice;
  final String? finalPrice;
  final String? soldToTeamId;
  final String? soldToTeamName;
  final List<PurchaseHistoryBid> bids;
}

/// Mirrors `AuctionService.getPlayerPurchaseHistory`'s full response shape.
class PlayerPurchaseHistory {
  const PlayerPurchaseHistory({
    required this.playerId,
    required this.playerName,
    required this.history,
  });

  factory PlayerPurchaseHistory.fromJson(Map<String, dynamic> json) => PlayerPurchaseHistory(
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String,
        history: (json['history'] as List<dynamic>)
            .map((e) => PurchaseHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String playerId;
  final String playerName;
  final List<PurchaseHistoryEntry> history;
}
