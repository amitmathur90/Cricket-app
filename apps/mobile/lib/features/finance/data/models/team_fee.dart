/// Mirrors `TeamFeeRow` in
/// apps/backend/src/modules/finance/finance.service.ts.
///
/// `paid`/`paidAt` are HONEST PLACEHOLDERS from the backend — always
/// `false`/`null`, because nothing in this codebase tracks whether a team's
/// registration fee was actually paid. This app renders that state as "Not
/// tracked" (see FinanceTeamFeesScreen) rather than a fake paid/unpaid
/// checkbox, so it never implies functionality that doesn't exist.
class TeamFeeRow {
  const TeamFeeRow({
    required this.tournamentTeamId,
    required this.teamId,
    required this.teamName,
    required this.feeAmount,
  });

  factory TeamFeeRow.fromJson(Map<String, dynamic> json) => TeamFeeRow(
        tournamentTeamId: json['tournamentTeamId'] as String,
        teamId: json['teamId'] as String,
        teamName: json['teamName'] as String,
        feeAmount: json['feeAmount'] as String,
      );

  final String tournamentTeamId;
  final String teamId;
  final String teamName;

  /// Decimal-as-string.
  final String feeAmount;
}
