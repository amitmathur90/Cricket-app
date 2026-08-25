import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/env.dart';
import '../../../core/network/network_providers.dart';
import '../data/models/scoring_models.dart';

enum ScoringConnectionStatus { connecting, connected, disconnected }

class ScoringRoomState {
  const ScoringRoomState({
    this.connectionStatus = ScoringConnectionStatus.connecting,
    this.liveState,
    this.errorMessage,
  });

  final ScoringConnectionStatus connectionStatus;

  /// The full current-state snapshot, kept up to date by every `scoring.*`
  /// broadcast this socket receives (see `_applyState`). Null until the
  /// first `scoring.stateSync` arrives after joining the room.
  final LiveScoringState? liveState;
  final String? errorMessage;

  ScoringRoomState copyWith({
    ScoringConnectionStatus? connectionStatus,
    LiveScoringState? liveState,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ScoringRoomState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      liveState: liveState ?? this.liveState,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Owns one Socket.IO connection to the backend's `/scoring` namespace
/// (apps/backend/src/modules/scoring/scoring.gateway.ts) for a single
/// match's live scoring room, plus all state accumulated from its events —
/// structurally mirroring `AuctionRoomController`
/// (features/auction/application/auction_room_controller.dart), the only
/// other Socket.IO-driven live-state screen in this app. Created via
/// [scoringRoomControllerProvider] (`.autoDispose.family` keyed by
/// organizationId+matchId) so leaving the live scoring screen tears the
/// socket down.
///
/// Reconnection is handled by socket_io_client itself; on every successful
/// `connect` (initial or reconnect) this re-emits `scoring.join`, which
/// makes the server resend a full `scoring.stateSync` snapshot — exactly
/// the reconnect-recovery mechanism the spec calls for, same as the
/// auction room's `auction.join`/`auction.stateSync` pair.
///
/// Unlike the auction gateway (which derives org scope from the session
/// server-side), `ScoringGateway` requires `organizationId` on every single
/// emitted event alongside `matchId` — see that file's doc comment — so
/// every emit method below sends both.
class ScoringRoomController extends StateNotifier<ScoringRoomState> {
  ScoringRoomController(this._ref, {required this.organizationId, required this.matchId})
      : super(const ScoringRoomState()) {
    _connect();
  }

  final Ref _ref;
  final String organizationId;
  final String matchId;
  io.Socket? _socket;

  /// The bowler of the most recently seen in-progress over. `currentOver`
  /// itself goes null exactly during the "over just completed, next bowler
  /// not yet selected" window the new-bowler prompt is shown in — so this
  /// is the only place that bowler id survives to be excluded from the
  /// prompt's picker (same-bowler-can't-bowl-consecutive-overs rule).
  ///
  /// Known gap: if the screen is opened fresh (or reconnects) exactly
  /// during that window, this is null — neither `live-state`/`stateSync`
  /// nor `recentBalls` carry the completed over's bowler id, so there's no
  /// way to recover it from a single snapshot. The picker just won't
  /// exclude anyone in that rare case; the backend's own
  /// "no consecutive overs" check still rejects an invalid pick and surfaces
  /// a `scoring.error`, so this degrades to an extra error message rather
  /// than a silent bad state.
  String? lastOverBowlerTeamPlayerId;

  Future<void> _connect() async {
    final token = await _ref.read(tokenStorageProvider).readAccessToken();

    final socket = io.io(
      '${Env.apiBaseUrl}/scoring',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      state = state.copyWith(connectionStatus: ScoringConnectionStatus.connected, clearError: true);
      socket.emit('scoring.join', {'organizationId': organizationId, 'matchId': matchId});
    });
    socket.onDisconnect((_) {
      state = state.copyWith(connectionStatus: ScoringConnectionStatus.disconnected);
    });
    socket.onConnectError((_) {
      state = state.copyWith(connectionStatus: ScoringConnectionStatus.disconnected);
    });

    // Every one of these carries a bare LiveScoringState payload EXCEPT
    // scoring.inningsCompleted, which wraps it as `{inningsNumber, state}`
    // (see ScoringRealtimeService.recordBall/endInnings) — handled
    // separately below.
    socket.on('scoring.stateSync', (data) => _applyState(_asMap(data)));
    socket.on('scoring.inningsStarted', (data) => _applyState(_asMap(data)));
    socket.on('scoring.ballRecorded', (data) => _applyState(_asMap(data)));
    socket.on('scoring.ballUndone', (data) => _applyState(_asMap(data)));
    socket.on('scoring.newBowlerSet', (data) => _applyState(_asMap(data)));
    socket.on('scoring.matchCompleted', (data) => _applyState(_asMap(data)));
    socket.on('scoring.inningsCompleted', (data) {
      final wrapped = _asMap(data);
      final inner = wrapped['state'];
      if (inner is Map) {
        _applyState(Map<String, dynamic>.from(inner));
      }
    });
    socket.on('scoring.error', (data) => _onErrorEvent(_asMap(data)));

    socket.connect();
  }

  /// socket_io_client hands event payloads through as-is when the server
  /// emitted a single argument (our gateway always does), but normalizes to
  /// a `List` in some code paths — accept either shape defensively (same as
  /// AuctionRoomController._asMap).
  Map<String, dynamic> _asMap(dynamic data) {
    if (data is List && data.isNotEmpty) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  void _applyState(Map<String, dynamic> json) {
    final liveState = LiveScoringState.fromJson(json);
    final bowler = liveState.currentInnings?.currentOver?.bowler;
    if (bowler != null) {
      lastOverBowlerTeamPlayerId = bowler.teamPlayerId;
    }
    state = state.copyWith(liveState: liveState);
  }

  void _onErrorEvent(Map<String, dynamic> json) {
    state = state.copyWith(errorMessage: json['message'] as String? ?? 'Something went wrong');
  }

  /// Clears a surfaced `scoring.error` once the UI has shown it, so it
  /// doesn't reappear on unrelated rebuilds.
  void dismissError() {
    state = state.copyWith(clearError: true);
  }

  /// Emits `scoring.recordBall`. Success arrives as a room-wide
  /// `scoring.ballRecorded` broadcast (handled above, plus
  /// `inningsCompleted`/`matchCompleted` as applicable); failure arrives as
  /// a `scoring.error` sent only to this socket — never assume success
  /// here, same fire-and-forget convention as
  /// `AuctionRoomController.placeBid`.
  void recordBall({
    required int runs,
    String? extraType,
    bool isWicket = false,
    String? dismissalType,
    String? dismissedTeamPlayerId,
    String? fielderTeamPlayerId,
    String? nextBatterTeamPlayerId,
  }) {
    _socket?.emit('scoring.recordBall', {
      'organizationId': organizationId,
      'matchId': matchId,
      'runs': runs,
      if (extraType != null) 'extraType': extraType,
      'isWicket': isWicket,
      if (dismissalType != null) 'dismissalType': dismissalType,
      if (dismissedTeamPlayerId != null) 'dismissedTeamPlayerId': dismissedTeamPlayerId,
      if (fielderTeamPlayerId != null) 'fielderTeamPlayerId': fielderTeamPlayerId,
      if (nextBatterTeamPlayerId != null) 'nextBatterTeamPlayerId': nextBatterTeamPlayerId,
    });
  }

  void undoLastBall() {
    _socket?.emit('scoring.undoLastBall', {'organizationId': organizationId, 'matchId': matchId});
  }

  void newBowler(String bowlerTeamPlayerId) {
    _socket?.emit('scoring.newBowler', {
      'organizationId': organizationId,
      'matchId': matchId,
      'bowlerTeamPlayerId': bowlerTeamPlayerId,
    });
  }

  @override
  void dispose() {
    _socket?.dispose();
    _socket = null;
    super.dispose();
  }
}

typedef ScoringRoomKey = ({String organizationId, String matchId});

final scoringRoomControllerProvider = StateNotifierProvider.autoDispose
    .family<ScoringRoomController, ScoringRoomState, ScoringRoomKey>((ref, key) {
  return ScoringRoomController(ref, organizationId: key.organizationId, matchId: key.matchId);
});
