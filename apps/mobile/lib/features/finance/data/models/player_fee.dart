/// Mirrors `PlayerFeeRow` in
/// apps/backend/src/modules/finance/finance.service.ts. Same honest
/// `paid: false, paidAt: null` placeholder rationale as [TeamFeeRow] — see
/// its doc comment.
class PlayerFeeRow {
  const PlayerFeeRow({
    required this.teamPlayerId,
    required this.playerId,
    required this.playerName,
    required this.tournamentTeamId,
    required this.teamName,
    required this.feeAmount,
  });

  factory PlayerFeeRow.fromJson(Map<String, dynamic> json) => PlayerFeeRow(
        teamPlayerId: json['teamPlayerId'] as String,
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String,
        tournamentTeamId: json['tournamentTeamId'] as String,
        teamName: json['teamName'] as String,
        feeAmount: json['feeAmount'] as String,
      );

  final String teamPlayerId;
  final String playerId;
  final String playerName;
  final String tournamentTeamId;
  final String teamName;

  /// Decimal-as-string.
  final String feeAmount;
}
