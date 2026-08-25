/// Mirrors apps/backend/src/database/entities/team.entity.ts — an org-level
/// team "brand", reused across tournaments via `tournament_teams`.
class Team {
  const Team({
    required this.id,
    required this.organizationId,
    required this.name,
    this.shortCode,
    this.logoUrl,
    this.ownerUserId,
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        organizationId: json['organizationId'] as String,
        name: json['name'] as String,
        shortCode: json['shortCode'] as String?,
        logoUrl: json['logoUrl'] as String?,
        ownerUserId: json['ownerUserId'] as String?,
      );

  final String id;
  final String organizationId;
  final String name;
  final String? shortCode;
  final String? logoUrl;
  final String? ownerUserId;
}
