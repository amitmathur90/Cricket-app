import '../../../players/data/models/player.dart';

/// Mirrors apps/backend/src/database/entities/team-player.entity.ts's
/// `TeamPlayer`, as returned by `TeamsService.getRoster` (`GET
/// .../teams/:teamId/tournaments/:tournamentId/roster`) with the `player`
/// relation eager-loaded — one row per `team_players` entry (a player's
/// membership on a specific tournament-team), plus that player's full
/// profile (including the `isAvailable*` flags PlayerListTab already
/// surfaces elsewhere — the roster GET's join brings those along for free,
/// so the Squad tab can show real availability rather than fabricating it).
class RosterEntry {
  const RosterEntry({
    required this.id,
    required this.tournamentTeamId,
    required this.playerId,
    required this.player,
    this.jerseyNumber,
    this.isCaptain = false,
    this.isViceCaptain = false,
    this.isWicketkeeper = false,
    this.status = 'active',
  });

  factory RosterEntry.fromJson(Map<String, dynamic> json) => RosterEntry(
        id: json['id'] as String,
        tournamentTeamId: json['tournamentTeamId'] as String,
        playerId: json['playerId'] as String,
        player: Player.fromJson(json['player'] as Map<String, dynamic>),
        jerseyNumber: json['jerseyNumber'] as int?,
        isCaptain: json['isCaptain'] as bool? ?? false,
        isViceCaptain: json['isViceCaptain'] as bool? ?? false,
        isWicketkeeper: json['isWicketkeeper'] as bool? ?? false,
        status: json['status'] as String? ?? 'active',
      );

  final String id;
  final String tournamentTeamId;
  final String playerId;
  final Player player;
  final int? jerseyNumber;
  final bool isCaptain;
  final bool isViceCaptain;
  final bool isWicketkeeper;

  /// Raw `TeamPlayerStatus` string ('active' | 'released') — no roster
  /// release flow is wired up in this app yet, so this is carried through
  /// for completeness rather than acted on.
  final String status;
}
