/// Mirrors `TournamentsService.PointsTableRow`
/// (apps/backend/src/modules/tournaments/tournaments.service.ts) — one row
/// of the computed (never persisted) standings table returned by
/// `GET /organizations/:organizationId/tournaments/:tournamentId/points-table`.
///
/// The backend already sorts the array by `position` ascending (points desc,
/// net run rate desc as the tiebreak — see `getPointsTable`'s final `.sort`),
/// so this model does no client-side re-sorting.
class PointsTableRow {
  const PointsTableRow({
    required this.tournamentTeamId,
    required this.teamName,
    required this.position,
    required this.played,
    required this.won,
    required this.lost,
    required this.tied,
    required this.noResult,
    required this.points,
    required this.netRunRate,
  });

  factory PointsTableRow.fromJson(Map<String, dynamic> json) => PointsTableRow(
        tournamentTeamId: json['tournamentTeamId'] as String,
        teamName: json['teamName'] as String,
        position: json['position'] as int,
        played: json['played'] as int? ?? 0,
        won: json['won'] as int? ?? 0,
        lost: json['lost'] as int? ?? 0,
        tied: json['tied'] as int? ?? 0,
        noResult: json['noResult'] as int? ?? 0,
        points: json['points'] as int? ?? 0,
        netRunRate: (json['netRunRate'] as num?)?.toDouble() ?? 0,
      );

  final String tournamentTeamId;
  final String teamName;
  final int position;
  final int played;
  final int won;
  final int lost;
  final int tied;
  final int noResult;
  final int points;
  final double netRunRate;
}
