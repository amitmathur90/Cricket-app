import 'auction_pool_entry.dart';

/// One tournament team's purse, as embedded in `auction.stateSync`'s
/// `teams[]` array (`AuctionRealtimeService.buildStateSyncPayload`, in
/// apps/backend/src/modules/auction/auction-realtime.service.ts). Lighter
/// than `AuctionTeamSummary` (auction_report.dart) — no spend/outcome
/// fields, since this is the live purse view, not the post-hoc report.
class AuctionLiveTeam {
  const AuctionLiveTeam({
    required this.tournamentTeamId,
    required this.teamName,
    this.purseTotal,
    this.purseRemaining,
  });

  factory AuctionLiveTeam.fromJson(Map<String, dynamic> json) => AuctionLiveTeam(
        tournamentTeamId: json['tournamentTeamId'] as String,
        teamName: json['teamName'] as String,
        purseTotal: json['purseTotal'] as String?,
        purseRemaining: json['purseRemaining'] as String?,
      );

  final String tournamentTeamId;
  final String teamName;
  final String? purseTotal;
  final String? purseRemaining;
}

/// The lot currently under the hammer, as embedded in `auction.stateSync`.
class AuctionCurrentLot {
  const AuctionCurrentLot({
    required this.poolEntryId,
    required this.player,
    required this.basePrice,
    this.currentBidAmount,
    this.currentBidTeamId,
    this.currentLotEndsAt,
  });

  factory AuctionCurrentLot.fromJson(Map<String, dynamic> json) => AuctionCurrentLot(
        poolEntryId: json['poolEntryId'] as String,
        player: AuctionLotPlayer.fromJson(json['player'] as Map<String, dynamic>),
        basePrice: json['basePrice'] as String,
        currentBidAmount: json['currentBidAmount'] as String?,
        currentBidTeamId: json['currentBidTeamId'] as String?,
        currentLotEndsAt: json['currentLotEndsAt'] != null
            ? DateTime.tryParse(json['currentLotEndsAt'] as String)
            : null,
      );

  final String poolEntryId;
  final AuctionLotPlayer player;
  final String basePrice;
  final String? currentBidAmount;
  final String? currentBidTeamId;
  final DateTime? currentLotEndsAt;

  AuctionCurrentLot copyWith({
    String? currentBidAmount,
    String? currentBidTeamId,
    // `undoLastBid` can revert the lot to "no bidder yet" (currentBidTeamId
    // = null) when the undone bid was the only one — the `?? this.…`
    // pattern above can't express "set to null", so give that case an
    // explicit escape hatch, same convention as AuctionRoomState's
    // clearCurrentLot/clearLastResult/clearError flags.
    bool clearCurrentBidTeamId = false,
    DateTime? currentLotEndsAt,
  }) =>
      AuctionCurrentLot(
        poolEntryId: poolEntryId,
        player: player,
        basePrice: basePrice,
        currentBidAmount: currentBidAmount ?? this.currentBidAmount,
        currentBidTeamId: clearCurrentBidTeamId ? null : (currentBidTeamId ?? this.currentBidTeamId),
        currentLotEndsAt: currentLotEndsAt ?? this.currentLotEndsAt,
      );
}

class AuctionStateSyncSessionInfo {
  const AuctionStateSyncSessionInfo({
    required this.id,
    required this.name,
    required this.status,
    required this.tournamentId,
  });

  factory AuctionStateSyncSessionInfo.fromJson(Map<String, dynamic> json) => AuctionStateSyncSessionInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        status: json['status'] as String,
        tournamentId: json['tournamentId'] as String,
      );

  final String id;
  final String name;

  /// Raw `AuctionSessionStatus` string (scheduled/live/paused/completed).
  final String status;
  final String tournamentId;
}

/// Full `auction.stateSync` payload — sent on `auction.join` (initial join
/// and every reconnect) and broadcast to the whole room on pause/resume/
/// session-completion.
/// See `AuctionRealtimeService.buildStateSyncPayload`.
class AuctionStateSync {
  const AuctionStateSync({
    required this.session,
    required this.currentLot,
    required this.remainingPoolCount,
    required this.teams,
  });

  factory AuctionStateSync.fromJson(Map<String, dynamic> json) => AuctionStateSync(
        session: AuctionStateSyncSessionInfo.fromJson(json['session'] as Map<String, dynamic>),
        currentLot: json['currentLot'] != null
            ? AuctionCurrentLot.fromJson(json['currentLot'] as Map<String, dynamic>)
            : null,
        remainingPoolCount: json['remainingPoolCount'] as int,
        teams: (json['teams'] as List<dynamic>)
            .map((e) => AuctionLiveTeam.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final AuctionStateSyncSessionInfo session;
  final AuctionCurrentLot? currentLot;
  final int remainingPoolCount;
  final List<AuctionLiveTeam> teams;
}

/// `auction.playerUp` payload — a new lot just opened (either the session's
/// first lot on start, or the next lot after the previous one resolved).
class AuctionPlayerUpEvent {
  const AuctionPlayerUpEvent({
    required this.poolEntryId,
    required this.player,
    required this.basePrice,
    required this.currentLotEndsAt,
  });

  factory AuctionPlayerUpEvent.fromJson(Map<String, dynamic> json) => AuctionPlayerUpEvent(
        poolEntryId: json['poolEntryId'] as String,
        player: AuctionLotPlayer.fromJson(json['player'] as Map<String, dynamic>),
        basePrice: json['basePrice'] as String,
        currentLotEndsAt: DateTime.parse(json['currentLotEndsAt'] as String),
      );

  final String poolEntryId;
  final AuctionLotPlayer player;
  final String basePrice;
  final DateTime currentLotEndsAt;
}

/// `auction.bidPlaced` payload — a bid was accepted; the lot's countdown was
/// reset to `currentLotEndsAt`.
class AuctionBidPlacedEvent {
  const AuctionBidPlacedEvent({
    required this.auctionSessionId,
    required this.poolEntryId,
    required this.teamId,
    required this.teamName,
    required this.amount,
    required this.bidSequence,
    required this.currentLotEndsAt,
  });

  factory AuctionBidPlacedEvent.fromJson(Map<String, dynamic> json) => AuctionBidPlacedEvent(
        auctionSessionId: json['auctionSessionId'] as String,
        poolEntryId: json['poolEntryId'] as String,
        teamId: json['teamId'] as String,
        teamName: json['teamName'] as String,
        amount: json['amount'] as String,
        bidSequence: json['bidSequence'] as int,
        currentLotEndsAt: DateTime.parse(json['currentLotEndsAt'] as String),
      );

  final String auctionSessionId;
  final String poolEntryId;
  final String teamId;
  final String teamName;
  final String amount;
  final int bidSequence;
  final DateTime currentLotEndsAt;
}

/// `auction.playerSold` payload — the lot that just closed found a buyer.
class AuctionPlayerSoldEvent {
  const AuctionPlayerSoldEvent({
    required this.playerId,
    required this.poolEntryId,
    required this.finalPrice,
    required this.soldToTeamId,
    required this.soldToTeamName,
    required this.purseRemaining,
  });

  factory AuctionPlayerSoldEvent.fromJson(Map<String, dynamic> json) => AuctionPlayerSoldEvent(
        playerId: json['playerId'] as String,
        poolEntryId: json['poolEntryId'] as String,
        finalPrice: json['finalPrice'] as String,
        soldToTeamId: json['soldToTeamId'] as String,
        soldToTeamName: json['soldToTeamName'] as String?,
        purseRemaining: json['purseRemaining'] as String,
      );

  final String playerId;
  final String poolEntryId;
  final String finalPrice;
  final String soldToTeamId;
  final String? soldToTeamName;
  final String purseRemaining;
}

/// `auction.playerUnsold` payload — the lot that just closed found no bids.
class AuctionPlayerUnsoldEvent {
  const AuctionPlayerUnsoldEvent({required this.playerId, required this.poolEntryId});

  factory AuctionPlayerUnsoldEvent.fromJson(Map<String, dynamic> json) => AuctionPlayerUnsoldEvent(
        playerId: json['playerId'] as String,
        poolEntryId: json['poolEntryId'] as String,
      );

  final String playerId;
  final String poolEntryId;
}

/// `auction.bidUndone` payload — an admin rolled back the most recent bid
/// on the current lot via `POST .../undo-last-bid`
/// (`AuctionRealtimeService.undoLastBid`). `currentBidTeamId`/
/// `currentBidTeamName` are null when the undone bid was the only bid on
/// the lot (state reverts to "no bidder yet, at base price").
class AuctionBidUndoneEvent {
  const AuctionBidUndoneEvent({
    required this.auctionSessionId,
    required this.poolEntryId,
    required this.undoneBidTeamId,
    required this.undoneBidAmount,
    required this.undoneBidSequence,
    required this.currentBidAmount,
    this.currentBidTeamId,
    this.currentBidTeamName,
    this.currentLotEndsAt,
  });

  factory AuctionBidUndoneEvent.fromJson(Map<String, dynamic> json) {
    final undoneBid = json['undoneBid'] as Map<String, dynamic>;
    return AuctionBidUndoneEvent(
      auctionSessionId: json['auctionSessionId'] as String,
      poolEntryId: json['poolEntryId'] as String,
      undoneBidTeamId: undoneBid['teamId'] as String,
      undoneBidAmount: undoneBid['amount'] as String,
      undoneBidSequence: undoneBid['bidSequence'] as int,
      currentBidAmount: json['currentBidAmount'] as String,
      currentBidTeamId: json['currentBidTeamId'] as String?,
      currentBidTeamName: json['currentBidTeamName'] as String?,
      currentLotEndsAt: json['currentLotEndsAt'] != null
          ? DateTime.tryParse(json['currentLotEndsAt'] as String)
          : null,
    );
  }

  final String auctionSessionId;
  final String poolEntryId;
  final String undoneBidTeamId;
  final String undoneBidAmount;
  final int undoneBidSequence;
  final String currentBidAmount;
  final String? currentBidTeamId;
  final String? currentBidTeamName;
  final DateTime? currentLotEndsAt;
}
