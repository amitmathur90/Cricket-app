import 'organization.dart';

/// Mirrors apps/backend/src/database/entities/org-membership.entity.ts, as
/// returned by `GET /users/me/memberships` (with `organization` relation
/// eager-loaded — see UsersService.getMemberships).
class OrgMembership {
  const OrgMembership({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.role,
    required this.status,
    this.organization,
  });

  factory OrgMembership.fromJson(Map<String, dynamic> json) => OrgMembership(
        id: json['id'] as String,
        organizationId: json['organizationId'] as String,
        userId: json['userId'] as String,
        role: json['role'] as String,
        status: json['status'] as String,
        organization: json['organization'] != null
            ? Organization.fromJson(json['organization'] as Map<String, dynamic>)
            : null,
      );

  final String id;
  final String organizationId;
  final String userId;
  final String role;
  /// One of `invited` | `active` | `removed` (OrgMembershipStatus).
  final String status;
  final Organization? organization;

  bool get isActive => status == 'active';
}
