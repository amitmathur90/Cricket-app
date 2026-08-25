import '../../../players/data/models/player.dart';

/// Mirrors `AuctionPoolStatus` in
/// apps/backend/src/database/entities/auction-player-pool.entity.ts.
enum AuctionPoolStatus { pending, inProgress, sold, unsold }

extension AuctionPoolStatusX on AuctionPoolStatus {
  String get apiValue => switch (this) {
        AuctionPoolStatus.pending => 'pending',
        AuctionPoolStatus.inProgress => 'in_progress',
        AuctionPoolStatus.sold => 'sold',
        AuctionPoolStatus.unsold => 'unsold',
      };

  String get label => switch (this) {
        AuctionPoolStatus.pending => 'Pending',
        AuctionPoolStatus.inProgress => 'Under the hammer',
        AuctionPoolStatus.sold => 'Sold',
        AuctionPoolStatus.unsold => 'Unsold',
      };

  static AuctionPoolStatus fromApi(String value) => AuctionPoolStatus.values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => AuctionPoolStatus.pending,
      );
}

/// A minimal player snapshot as embedded in pool entries / lot payloads
/// (a subset of the fields on `Player` — see player.entity.ts /
/// player.dart — that the auction module actually selects).
///
/// `rating` is a special case: the realtime WS payloads
/// (`auction.stateSync`/`auction.playerUp` — see
/// AuctionRealtimeService.buildStateSyncPayload) only ever project
/// id/fullName/role/photoUrl, so it comes back null there. The REST
/// `GET .../pool` endpoint (`AuctionService.listPool`), by contrast, loads
/// the full `player` relation with no column restriction, so its
/// `AuctionPlayerPoolEntry.player.rating` is populated whenever the player
/// has one set. Parsed opportunistically here so callers that do have pool
/// data (e.g. cross-referencing by poolEntryId) can show it.
class AuctionLotPlayer {
  const AuctionLotPlayer({
    required this.id,
    required this.fullName,
    required this.role,
    this.photoUrl,
    this.rating,
  });

  factory AuctionLotPlayer.fromJson(Map<String, dynamic> json) => AuctionLotPlayer(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        role: PlayerRoleX.fromApi(json['role'] as String? ?? 'batsman'),
        photoUrl: json['photoUrl'] as String?,
        rating: json['rating'] as String?,
      );

  final String id;
  final String fullName;
  final PlayerRole role;
  final String? photoUrl;

  /// Decimal-as-string (0-5 scale, same as Player.rating) — null when
  /// unset, or when this snapshot came from a WS payload that doesn't
  /// carry it (see class doc).
  final String? rating;
}

/// Mirrors apps/backend/src/database/entities/auction-player-pool.entity.ts
/// (`AuctionService.listPool` response — relations: player, soldToTeam,
/// soldToTeam.team).
class AuctionPlayerPoolEntry {
  const AuctionPlayerPoolEntry({
    required this.id,
    required this.auctionSessionId,
    required this.playerId,
    required this.basePrice,
    required this.status,
    required this.lotOrder,
    this.finalPrice,
    this.soldToTeamId,
    this.soldToTeamName,
    this.player,
  });

  factory AuctionPlayerPoolEntry.fromJson(Map<String, dynamic> json) {
    final soldToTeam = json['soldToTeam'] as Map<String, dynamic>?;
    final soldToTeamBrand = soldToTeam?['team'] as Map<String, dynamic>?;
    final playerJson = json['player'] as Map<String, dynamic>?;
    return AuctionPlayerPoolEntry(
      id: json['id'] as String,
      auctionSessionId: json['auctionSessionId'] as String,
      playerId: json['playerId'] as String,
      basePrice: json['basePrice'] as String,
      status: AuctionPoolStatusX.fromApi(json['status'] as String? ?? 'pending'),
      lotOrder: json['lotOrder'] as int,
      finalPrice: json['finalPrice'] as String?,
      soldToTeamId: json['soldToTeamId'] as String?,
      soldToTeamName: soldToTeamBrand?['name'] as String?,
      player: playerJson != null ? AuctionLotPlayer.fromJson(playerJson) : null,
    );
  }

  final String id;
  final String auctionSessionId;
  final String playerId;

  /// Decimal-as-string.
  final String basePrice;
  final AuctionPoolStatus status;
  final int lotOrder;
  final String? finalPrice;
  final String? soldToTeamId;
  final String? soldToTeamName;
  final AuctionLotPlayer? player;
}
