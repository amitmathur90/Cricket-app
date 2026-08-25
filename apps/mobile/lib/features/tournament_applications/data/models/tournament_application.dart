import '../../../players/data/models/player.dart';
import '../../../tournaments/data/models/tournament.dart';

/// Mirrors `TournamentApplicationStatus` in
/// apps/backend/src/database/entities/tournament-application.entity.ts.
enum TournamentApplicationStatus { pending, approved, rejected }

extension TournamentApplicationStatusX on TournamentApplicationStatus {
  String get apiValue => switch (this) {
        TournamentApplicationStatus.pending => 'pending',
        TournamentApplicationStatus.approved => 'approved',
        TournamentApplicationStatus.rejected => 'rejected',
      };

  String get label => switch (this) {
        TournamentApplicationStatus.pending => 'Pending',
        TournamentApplicationStatus.approved => 'Approved',
        TournamentApplicationStatus.rejected => 'Rejected',
      };

  static TournamentApplicationStatus fromApi(String value) =>
      TournamentApplicationStatus.values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => TournamentApplicationStatus.pending,
      );
}

/// Mirrors apps/backend/src/database/entities/tournament-application.entity.ts
/// — a player-role user's self-service application to a specific
/// tournament. `player`/`tournament` are only populated when the backend
/// query loaded that relation:
///  - `POST .../applications` (apply): neither relation loaded.
///  - `GET .../tournaments/:id/applications` (admin list): `player` loaded,
///    `tournament` not (already known from the route).
///  - `GET .../applications/mine`: both `tournament` and `player` loaded.
class TournamentApplication {
  const TournamentApplication({
    required this.id,
    required this.tournamentId,
    required this.userId,
    this.playerId,
    required this.status,
    this.reviewNote,
    this.reviewedByUserId,
    required this.createdAt,
    this.reviewedAt,
    this.player,
    this.tournament,
  });

  factory TournamentApplication.fromJson(Map<String, dynamic> json) => TournamentApplication(
        id: json['id'] as String,
        tournamentId: json['tournamentId'] as String,
        userId: json['userId'] as String,
        playerId: json['playerId'] as String?,
        status: TournamentApplicationStatusX.fromApi(json['status'] as String),
        reviewNote: json['reviewNote'] as String?,
        reviewedByUserId: json['reviewedByUserId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        reviewedAt:
            json['reviewedAt'] != null ? DateTime.parse(json['reviewedAt'] as String) : null,
        player: json['player'] != null
            ? Player.fromJson(json['player'] as Map<String, dynamic>)
            : null,
        tournament: json['tournament'] != null
            ? Tournament.fromJson(json['tournament'] as Map<String, dynamic>)
            : null,
      );

  final String id;
  final String tournamentId;
  final String userId;
  final String? playerId;
  final TournamentApplicationStatus status;
  final String? reviewNote;
  final String? reviewedByUserId;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final Player? player;
  final Tournament? tournament;
}
