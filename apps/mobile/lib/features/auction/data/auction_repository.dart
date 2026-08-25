import '../../../core/network/api_client.dart';
import 'models/auction_bid.dart';
import 'models/auction_pool_entry.dart';
import 'models/auction_report.dart';
import 'models/auction_session.dart';
import 'models/player_purchase_history.dart';

/// One player entry to submit via [AuctionRepository.addToPool], matching
/// `AddPoolEntryDto` in apps/backend/src/modules/auction/dto/add-to-pool.dto.ts.
class AddPoolEntryInput {
  const AddPoolEntryInput({required this.playerId, required this.basePrice, required this.lotOrder});

  final String playerId;
  final num basePrice;
  final int lotOrder;

  Map<String, dynamic> toJson() => {'playerId': playerId, 'basePrice': basePrice, 'lotOrder': lotOrder};
}

/// Talks to `AuctionController` / `PlayerPurchaseHistoryController`
/// (apps/backend/src/modules/auction/auction.controller.ts). Session-scoped
/// routes are nested under both organization AND tournament — the
/// controller's route prefix is
/// `organizations/:organizationId/tournaments/:tournamentId/auction-sessions`
/// — so every call below needs both ids even where the backend handler
/// itself only extracts a subset of them.
///
/// Placing a bid and joining a session's live room are NOT REST calls —
/// those go over the `/auction` Socket.IO namespace, owned by
/// `AuctionRoomController` (see ../application/auction_room_controller.dart).
/// Everything else — session CRUD-lite, pool management, the admin
/// start/pause/resume/next-lot actions, bid history, and reports — is plain
/// REST and lives here.
class AuctionRepository {
  AuctionRepository(this._apiClient);

  final ApiClient _apiClient;

  String _sessionsBase(String organizationId, String tournamentId) =>
      '/organizations/$organizationId/tournaments/$tournamentId/auction-sessions';

  Future<List<AuctionSession>> listSessions(String organizationId, String tournamentId) async {
    final response = await _apiClient.get(_sessionsBase(organizationId, tournamentId));
    return (response.data as List<dynamic>)
        .map((e) => AuctionSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AuctionSession> createSession(
    String organizationId,
    String tournamentId, {
    required String name,
  }) async {
    final response = await _apiClient.post(
      _sessionsBase(organizationId, tournamentId),
      data: {'name': name},
    );
    return AuctionSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuctionSession> getSession(
    String organizationId,
    String tournamentId,
    String sessionId,
  ) async {
    final response = await _apiClient.get('${_sessionsBase(organizationId, tournamentId)}/$sessionId');
    return AuctionSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<AuctionPlayerPoolEntry>> listPool(
    String organizationId,
    String tournamentId,
    String sessionId,
  ) async {
    final response =
        await _apiClient.get('${_sessionsBase(organizationId, tournamentId)}/$sessionId/pool');
    return (response.data as List<dynamic>)
        .map((e) => AuctionPlayerPoolEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AuctionPlayerPoolEntry>> addToPool(
    String organizationId,
    String tournamentId,
    String sessionId,
    List<AddPoolEntryInput> entries,
  ) async {
    final response = await _apiClient.post(
      '${_sessionsBase(organizationId, tournamentId)}/$sessionId/pool',
      data: {'entries': entries.map((e) => e.toJson()).toList()},
    );
    return (response.data as List<dynamic>)
        .map((e) => AuctionPlayerPoolEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AuctionSession> startSession(
    String organizationId,
    String tournamentId,
    String sessionId,
  ) async {
    final response =
        await _apiClient.post('${_sessionsBase(organizationId, tournamentId)}/$sessionId/start');
    return AuctionSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuctionSession> pauseSession(
    String organizationId,
    String tournamentId,
    String sessionId,
  ) async {
    final response =
        await _apiClient.post('${_sessionsBase(organizationId, tournamentId)}/$sessionId/pause');
    return AuctionSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuctionSession> resumeSession(
    String organizationId,
    String tournamentId,
    String sessionId,
  ) async {
    final response =
        await _apiClient.post('${_sessionsBase(organizationId, tournamentId)}/$sessionId/resume');
    return AuctionSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuctionSession> nextLot(
    String organizationId,
    String tournamentId,
    String sessionId,
  ) async {
    final response =
        await _apiClient.post('${_sessionsBase(organizationId, tournamentId)}/$sessionId/next-lot');
    return AuctionSession.fromJson(response.data as Map<String, dynamic>);
  }

  /// Admin-only escape hatch: voids the most recent bid on the session's
  /// current lot (`POST .../undo-last-bid`, org_admin/tournament_admin
  /// only — enforced server-side, not hidden client-side, per this app's
  /// established RBAC-via-backend-rejection pattern). The REST response is
  /// just the updated session row; the live room's state actually updates
  /// from the `auction.bidUndone` broadcast on the `/auction` socket (see
  /// AuctionRoomController._onBidUndone) — same division of labor as
  /// pause/resume, which broadcast `auction.stateSync` rather than relying
  /// on their REST responses.
  Future<AuctionSession> undoLastBid(
    String organizationId,
    String tournamentId,
    String sessionId,
  ) async {
    final response = await _apiClient
        .post('${_sessionsBase(organizationId, tournamentId)}/$sessionId/undo-last-bid');
    return AuctionSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<AuctionBidRecord>> listBids(
    String organizationId,
    String tournamentId,
    String sessionId, {
    String? playerId,
  }) async {
    final response = await _apiClient.get(
      '${_sessionsBase(organizationId, tournamentId)}/$sessionId/bids',
      queryParameters: playerId != null ? {'playerId': playerId} : null,
    );
    return (response.data as List<dynamic>)
        .map((e) => AuctionBidRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AuctionReport> getReport(
    String organizationId,
    String tournamentId,
    String sessionId,
  ) async {
    final response =
        await _apiClient.get('${_sessionsBase(organizationId, tournamentId)}/$sessionId/report');
    return AuctionReport.fromJson(response.data as Map<String, dynamic>);
  }

  /// This one route does NOT nest under a tournament — see
  /// `PlayerPurchaseHistoryController` (a player can have history across
  /// multiple tournaments/sessions).
  Future<PlayerPurchaseHistory> getPlayerPurchaseHistory(
    String organizationId,
    String playerId,
  ) async {
    final response =
        await _apiClient.get('/organizations/$organizationId/players/$playerId/purchase-history');
    return PlayerPurchaseHistory.fromJson(response.data as Map<String, dynamic>);
  }
}
