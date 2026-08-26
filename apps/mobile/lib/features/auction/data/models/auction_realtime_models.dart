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
    required this.squadFull,
    this.purseTotal,
    this.purseRemaining,
  });

  factory AuctionLiveTeam.fromJson(Map<String, dynamic> json) => AuctionLiveTeam(
        tournamentTeamId: json['tournamentTeamId'] as String,
        teamName: json['teamName'] as String,
        purseTotal: json['purseTotal'] as String?,
        purseRemaining: json['purseRemaining'] as String?,
        // Defaults false when absent (e.g. older cached data) rather than
        // failing to parse — a session with no `maxSquadSize` configured
        // never has a full squad, matching the backend's `isSquadFull`
        // returning false when maxSquadSize is unset.
        squadFull: json['squadFull'] as bool? ?? false,
      );

  final String tournamentTeamId;
  final String teamName;
  final String? purseTotal;
  final String? purseRemaining;

  /// True once this team's roster is at (or above) the session's configured
  /// `maxSquadSize` — server-computed (`AuctionRealtimeService.isSquadFull`).
  /// The bidding UI must disable this team's PLACE BID action and show a
  /// "SQUAD FULL" badge instead, rather than letting the bid go through and
  /// fail server-side with `"SQUAD FULL — this team has reached its maximum
  /// roster size"`.
  final bool squadFull;

  AuctionLiveTeam copyWith({String? purseTotal, String? purseRemaining, bool? squadFull}) => AuctionLiveTeam(
        tournamentTeamId: tournamentTeamId,
        teamName: teamName,
        purseTotal: purseTotal ?? this.purseTotal,
        purseRemaining: purseRemaining ?? this.purseRemaining,
        squadFull: squadFull ?? this.squadFull,
      );
}

/// The lot currently under the hammer, as embedded in `auction.stateSync`.
///
/// There is deliberately no countdown/deadline field here (no
/// `currentLotEndsAt`) — the backend rewrite removed the auto-timer
/// entirely (see `AuctionRealtimeService`'s class doc comment: "There is
/// deliberately no timer anywhere in this class"). A lot never resolves on
/// its own; [resolved] is the only signal the UI has for "this lot is done,
/// show the SOLD/UNSOLD confirmation and the Next Player prompt instead of
/// bidding controls."
class AuctionCurrentLot {
  const AuctionCurrentLot({
    required this.poolEntryId,
    required this.player,
    required this.basePrice,
    required this.resolved,
    this.currentBidAmount,
    this.currentBidTeamId,
  });

  factory AuctionCurrentLot.fromJson(Map<String, dynamic> json) => AuctionCurrentLot(
        poolEntryId: json['poolEntryId'] as String,
        player: AuctionLotPlayer.fromJson(json['player'] as Map<String, dynamic>),
        basePrice: json['basePrice'] as String,
        currentBidAmount: json['currentBidAmount'] as String?,
        currentBidTeamId: json['currentBidTeamId'] as String?,
        resolved: json['resolved'] as bool,
      );

  final String poolEntryId;
  final AuctionLotPlayer player;
  final String basePrice;
  final String? currentBidAmount;
  final String? currentBidTeamId;

  /// True once the admin has marked this lot SOLD or UNSOLD — mirrors
  /// `AuctionPlayerPool.status !== IN_PROGRESS` server-side (see
  /// `buildStateSyncPayload`'s doc comment on this field). While false, the
  /// lot is still open to bids; once true, bidding is done and the only
  /// valid admin action left is "Next Player" (`next-lot`).
  final bool resolved;

  AuctionCurrentLot copyWith({
    String? currentBidAmount,
    String? currentBidTeamId,
    // `undoLastBid` can revert the lot to "no bidder yet" (currentBidTeamId
    // = null) when the undone bid was the only one — the `?? this.…`
    // pattern above can't express "set to null", so give that case an
    // explicit escape hatch, same convention as AuctionRoomState's
    // clearCurrentLot/clearLastResult/clearError flags.
    bool clearCurrentBidTeamId = false,
    bool? resolved,
  }) =>
      AuctionCurrentLot(
        poolEntryId: poolEntryId,
        player: player,
        basePrice: basePrice,
        currentBidAmount: currentBidAmount ?? this.currentBidAmount,
        currentBidTeamId: clearCurrentBidTeamId ? null : (currentBidTeamId ?? this.currentBidTeamId),
        resolved: resolved ?? this.resolved,
      );
}

class AuctionStateSyncSessionInfo {
  const AuctionStateSyncSessionInfo({
    required this.id,
    required this.name,
    required this.status,
    required this.tournamentId,
    this.durationMinutes,
    this.maxSquadSize,
  });

  factory AuctionStateSyncSessionInfo.fromJson(Map<String, dynamic> json) => AuctionStateSyncSessionInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        status: json['status'] as String,
        tournamentId: json['tournamentId'] as String,
        durationMinutes: json['durationMinutes'] as int?,
        maxSquadSize: json['maxSquadSize'] as int?,
      );

  final String id;
  final String name;

  /// Raw `AuctionSessionStatus` string (scheduled/live/paused/completed).
  final String status;
  final String tournamentId;

  /// Informational total-time budget for the whole session, in minutes.
  /// Never enforced server-side — purely a display value, and null when the
  /// session was created without one (don't fabricate a countdown for it).
  final int? durationMinutes;

  /// Max roster size per team, if configured for this session. Also
  /// reflected per-team as `AuctionLiveTeam.squadFull`.
  final int? maxSquadSize;
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
/// first lot on start, or the next lot after the previous one resolved). No
/// `resolved` flag is sent here — a freshly-opened lot is always unresolved
/// (the pool entry was just flipped to `IN_PROGRESS`), so the controller
/// sets `resolved: false` directly when building `AuctionCurrentLot` from
/// this event.
class AuctionPlayerUpEvent {
  const AuctionPlayerUpEvent({
    required this.poolEntryId,
    required this.player,
    required this.basePrice,
  });

  factory AuctionPlayerUpEvent.fromJson(Map<String, dynamic> json) => AuctionPlayerUpEvent(
        poolEntryId: json['poolEntryId'] as String,
        player: AuctionLotPlayer.fromJson(json['player'] as Map<String, dynamic>),
        basePrice: json['basePrice'] as String,
      );

  final String poolEntryId;
  final AuctionLotPlayer player;
  final String basePrice;
}

/// `auction.bidPlaced` payload — a bid was accepted. There is no bidding
/// deadline to reset anymore (see `AuctionCurrentLot`'s doc comment) — a lot
/// stays open until the admin marks it SOLD/UNSOLD.
class AuctionBidPlacedEvent {
  const AuctionBidPlacedEvent({
    required this.auctionSessionId,
    required this.poolEntryId,
    required this.teamId,
    required this.teamName,
    required this.amount,
    required this.bidSequence,
  });

  factory AuctionBidPlacedEvent.fromJson(Map<String, dynamic> json) => AuctionBidPlacedEvent(
        auctionSessionId: json['auctionSessionId'] as String,
        poolEntryId: json['poolEntryId'] as String,
        teamId: json['teamId'] as String,
        teamName: json['teamName'] as String,
        amount: json['amount'] as String,
        bidSequence: json['bidSequence'] as int,
      );

  final String auctionSessionId;
  final String poolEntryId;
  final String teamId;
  final String teamName;
  final String amount;
  final int bidSequence;
}

/// `auction.playerSold` payload — the current lot was marked SOLD to the
/// leading bidder (`POST .../mark-sold`). Purse deduction and the roster
/// upsert already happened server-side by the time this broadcasts; the lot
/// does NOT advance — that's a separate `auction.playerUp` from a later
/// `POST .../next-lot` call.
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

/// `auction.playerUnsold` payload — the current lot was marked UNSOLD
/// (`POST .../mark-unsold`), with or without a leading bid. No purse ever
/// moves for an UNSOLD lot. Does not advance (same as playerSold).
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
/// the lot (state reverts to "no bidder yet, at base price"). The backend
/// payload still carries a `currentLotEndsAt` key (always null — the
/// column is kept but never written to anymore, see the
/// `AuctionSession.currentLotEndsAt` doc comment) — deliberately not parsed
/// here since nothing should ever read it as a deadline.
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
}
