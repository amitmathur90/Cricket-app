/// Mirrors the row shape returned by
/// `GET public/organizations/:organizationId/tournaments/:tournamentId/teams`
/// (apps/backend/src/modules/public/public-tournaments.controller.ts#getTeams)
/// — name/logo only, no purse/financial data, withdrawn teams excluded
/// server-side.
class PublicTeam {
  const PublicTeam({
    required this.tournamentTeamId,
    required this.teamId,
    required this.name,
    this.shortCode,
    this.logoUrl,
  });

  factory PublicTeam.fromJson(Map<String, dynamic> json) => PublicTeam(
        tournamentTeamId: json['tournamentTeamId'] as String,
        teamId: json['teamId'] as String,
        name: json['name'] as String,
        shortCode: json['shortCode'] as String?,
        logoUrl: json['logoUrl'] as String?,
      );

  final String tournamentTeamId;
  final String teamId;
  final String name;
  final String? shortCode;
  final String? logoUrl;
}
