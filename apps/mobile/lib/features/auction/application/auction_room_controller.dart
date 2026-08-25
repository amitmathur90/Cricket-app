import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/env.dart';
import '../../../core/network/network_providers.dart';
import '../data/models/auction_realtime_models.dart';

enum AuctionConnectionStatus { connecting, connected, disconnected }

/// The outcome banner shown after a lot resolves (`auction.playerSold` /
/// `auction.playerUnsold`) until the next `auction.playerUp` replaces it.
class AuctionLotResult {
  const AuctionLotResult.sold({required this.playerId, required this.finalPrice, this.soldToTeamName})
      : isSold = true;

  const AuctionLotResult.unsold({required this.playerId})
      : isSold = false,
        finalPrice = null,
        soldToTeamName = null;

  final bool isSold;
  final String playerId;
  final String? finalPrice;
  final String? soldToTeamName;
}

/// One row in the live bid history feed, built from `auction.bidPlaced`
/// events (newest first). `createdAt` is client-side receipt time — the
/// broadcast payload itself doesn't carry a timestamp (see
/// AuctionBidPlacedEvent). `voided` flips true if an admin later undoes
/// this exact bid (`auction.bidUndone`, matched by `bidSequence` — the
/// feed is reset to empty on every `auction.playerUp`, so bidSequence is
/// unambiguous within it without also checking poolEntryId).
class AuctionBidFeedItem {
  const AuctionBidFeedItem({
    required this.teamName,
    required this.amount,
    required this.bidSequence,
    required this.createdAt,
    this.voided = false,
  });

  final String teamName;
  final String amount;
  final int bidSequence;
  final DateTime createdAt;
  final bool voided;

  AuctionBidFeedItem asVoided() => AuctionBidFeedItem(
        teamName: teamName,
        amount: amount,
        bidSequence: bidSequence,
        createdAt: createdAt,
        voided: true,
      );
}

class AuctionRoomState {
  const AuctionRoomState({
    this.connectionStatus = AuctionConnectionStatus.connecting,
    this.sessionStatus,
    this.currentLot,
    this.remainingPoolCount = 0,
    this.teams = const [],
    this.bidHistory = const [],
    this.lastResult,
    this.errorMessage,
  });

  final AuctionConnectionStatus connectionStatus;

  /// Raw `AuctionSessionStatus` string (scheduled/live/paused/completed),
  /// kept current via `auction.stateSync`.
  final String? sessionStatus;
  final AuctionCurrentLot? currentLot;
  final int remainingPoolCount;
  final List<AuctionLiveTeam> teams;

  /// Newest first.
  final List<AuctionBidFeedItem> bidHistory;
  final AuctionLotResult? lastResult;
  final String? errorMessage;

  AuctionRoomState copyWith({
    AuctionConnectionStatus? connectionStatus,
    String? sessionStatus,
    AuctionCurrentLot? currentLot,
    bool clearCurrentLot = false,
    int? remainingPoolCount,
    List<AuctionLiveTeam>? teams,
    List<AuctionBidFeedItem>? bidHistory,
    AuctionLotResult? lastResult,
    bool clearLastResult = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuctionRoomState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      sessionStatus: sessionStatus ?? this.sessionStatus,
      currentLot: clearCurrentLot ? null : (currentLot ?? this.currentLot),
      remainingPoolCount: remainingPoolCount ?? this.remainingPoolCount,
      teams: teams ?? this.teams,
      bidHistory: bidHistory ?? this.bidHistory,
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Owns one Socket.IO connection to the backend's `/auction` namespace
/// (apps/backend/src/modules/auction/auction.gateway.ts) for a single
/// auction session, plus all state accumulated from its events. Created via
/// [auctionRoomControllerProvider] (`.autoDispose.family` keyed by
/// sessionId) so leaving the live room screen tears the socket down.
///
/// Reconnection is handled by socket_io_client itself (default reconnection
/// options); on every successful `connect` (initial or reconnect) we
/// re-emit `auction.join`, which makes the server resend a full
/// `auction.stateSync` snapshot — that's what keeps this state correct
/// across drops instead of trying to patch a possibly-stale local state.
class AuctionRoomController extends StateNotifier<AuctionRoomState> {
  AuctionRoomController(this._ref, {required this.sessionId}) : super(const AuctionRoomState()) {
    _connect();
  }

  final Ref _ref;
  final String sessionId;
  io.Socket? _socket;

  Future<void> _connect() async {
    final token = await _ref.read(tokenStorageProvider).readAccessToken();

    final socket = io.io(
      '${Env.apiBaseUrl}/auction',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      state = state.copyWith(connectionStatus: AuctionConnectionStatus.connected, clearError: true);
      socket.emit('auction.join', {'auctionSessionId': sessionId});
    });
    socket.onDisconnect((_) {
      state = state.copyWith(connectionStatus: AuctionConnectionStatus.disconnected);
    });
    socket.onConnectError((_) {
      state = state.copyWith(connectionStatus: AuctionConnectionStatus.disconnected);
    });

    socket.on('auction.stateSync', (data) => _onStateSync(_asMap(data)));
    socket.on('auction.playerUp', (data) => _onPlayerUp(_asMap(data)));
    socket.on('auction.bidPlaced', (data) => _onBidPlaced(_asMap(data)));
    socket.on('auction.bidUndone', (data) => _onBidUndone(_asMap(data)));
    socket.on('auction.playerSold', (data) => _onPlayerSold(_asMap(data)));
    socket.on('auction.playerUnsold', (data) => _onPlayerUnsold(_asMap(data)));
    socket.on('auction.error', (data) => _onErrorEvent(_asMap(data)));

    socket.connect();
  }

  /// socket_io_client hands event payloads through as-is when the server
  /// emitted a single argument (our gateway always does), but normalizes to
  /// a `List` in some code paths — accept either shape defensively.
  Map<String, dynamic> _asMap(dynamic data) {
    if (data is List && data.isNotEmpty) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  void _onStateSync(Map<String, dynamic> json) {
    final sync = AuctionStateSync.fromJson(json);
    state = state.copyWith(
      sessionStatus: sync.session.status,
      currentLot: sync.currentLot,
      clearCurrentLot: sync.currentLot == null,
      remainingPoolCount: sync.remainingPoolCount,
      teams: sync.teams,
      clearLastResult: true,
    );
  }

  void _onPlayerUp(Map<String, dynamic> json) {
    final evt = AuctionPlayerUpEvent.fromJson(json);
    state = state.copyWith(
      currentLot: AuctionCurrentLot(
        poolEntryId: evt.poolEntryId,
        player: evt.player,
        basePrice: evt.basePrice,
        currentBidAmount: evt.basePrice,
        currentLotEndsAt: evt.currentLotEndsAt,
      ),
      bidHistory: const [],
      clearLastResult: true,
    );
  }

  void _onBidPlaced(Map<String, dynamic> json) {
    final evt = AuctionBidPlacedEvent.fromJson(json);
    final lot = state.currentLot;
    final updatedLot = (lot != null && lot.poolEntryId == evt.poolEntryId)
        ? lot.copyWith(
            currentBidAmount: evt.amount,
            currentBidTeamId: evt.teamId,
            currentLotEndsAt: evt.currentLotEndsAt,
          )
        : lot;
    state = state.copyWith(
      currentLot: updatedLot,
      bidHistory: [
        AuctionBidFeedItem(
          teamName: evt.teamName,
          amount: evt.amount,
          bidSequence: evt.bidSequence,
          createdAt: DateTime.now(),
        ),
        ...state.bidHistory,
      ],
    );
  }

  /// Handles `auction.bidUndone` — an admin voided the current lot's most
  /// recent bid via `POST .../undo-last-bid`. Reverts `currentLot`'s
  /// leading-bid fields to whatever the backend recomputed (the previous
  /// bid, or base price / no bidder if that was the only bid), and flags
  /// the matching row in the local bid-history feed as voided rather than
  /// removing it — the audit trail stays visible, same as the backend
  /// never hard-deleting the bid row.
  void _onBidUndone(Map<String, dynamic> json) {
    final evt = AuctionBidUndoneEvent.fromJson(json);
    final lot = state.currentLot;
    final updatedLot = (lot != null && lot.poolEntryId == evt.poolEntryId)
        ? lot.copyWith(
            currentBidAmount: evt.currentBidAmount,
            currentBidTeamId: evt.currentBidTeamId,
            clearCurrentBidTeamId: evt.currentBidTeamId == null,
            currentLotEndsAt: evt.currentLotEndsAt,
          )
        : lot;
    state = state.copyWith(
      currentLot: updatedLot,
      bidHistory: [
        for (final item in state.bidHistory)
          if (item.bidSequence == evt.undoneBidSequence) item.asVoided() else item,
      ],
    );
  }

  void _onPlayerSold(Map<String, dynamic> json) {
    final evt = AuctionPlayerSoldEvent.fromJson(json);
    final updatedTeams = state.teams
        .map((t) => t.tournamentTeamId == evt.soldToTeamId
            ? AuctionLiveTeam(
                tournamentTeamId: t.tournamentTeamId,
                teamName: t.teamName,
                purseTotal: t.purseTotal,
                purseRemaining: evt.purseRemaining,
              )
            : t)
        .toList();
    state = state.copyWith(
      teams: updatedTeams,
      lastResult: AuctionLotResult.sold(
        playerId: evt.playerId,
        finalPrice: evt.finalPrice,
        soldToTeamName: evt.soldToTeamName,
      ),
    );
  }

  void _onPlayerUnsold(Map<String, dynamic> json) {
    final evt = AuctionPlayerUnsoldEvent.fromJson(json);
    state = state.copyWith(lastResult: AuctionLotResult.unsold(playerId: evt.playerId));
  }

  void _onErrorEvent(Map<String, dynamic> json) {
    state = state.copyWith(errorMessage: json['message'] as String? ?? 'Something went wrong');
  }

  /// Clears a surfaced `auction.error` once the UI has shown it (e.g. after
  /// displaying a snackbar), so it doesn't reappear on unrelated rebuilds.
  void dismissError() {
    state = state.copyWith(clearError: true);
  }

  /// Sends `auction.placeBid`. Success arrives as a room-wide
  /// `auction.bidPlaced` broadcast (handled above); failure arrives as an
  /// `auction.error` sent only to this socket — never assume success here.
  void placeBid({required String teamId, required num amount}) {
    _socket?.emit('auction.placeBid', {
      'auctionSessionId': sessionId,
      'teamId': teamId,
      'amount': amount,
    });
  }

  @override
  void dispose() {
    _socket?.dispose();
    _socket = null;
    super.dispose();
  }
}

final auctionRoomControllerProvider = StateNotifierProvider.autoDispose
    .family<AuctionRoomController, AuctionRoomState, String>((ref, sessionId) {
  return AuctionRoomController(ref, sessionId: sessionId);
});
