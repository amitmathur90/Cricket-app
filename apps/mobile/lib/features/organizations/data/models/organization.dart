/// Mirrors apps/backend/src/database/entities/organization.entity.ts.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    required this.subscriptionTier,
    required this.status,
    this.joinCode,
  });

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        logoUrl: json['logoUrl'] as String?,
        subscriptionTier: json['subscriptionTier'] as String? ?? 'free',
        status: json['status'] as String? ?? 'active',
        joinCode: json['joinCode'] as String?,
      );

  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
  final String subscriptionTier;
  final String status;

  /// Shareable self-join code (see OrganizationsController.join /
  /// regenerateJoinCode). Present on `GET /organizations/:id` and on the
  /// regenerate response; null on the partial `organization` object
  /// embedded in `POST /organizations/join`'s response (that endpoint only
  /// returns `id`/`name`/`slug` for the org — see
  /// OrganizationsService.join).
  final String? joinCode;
}
