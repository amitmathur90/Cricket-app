/// Mirrors `OfficialRole` in apps/backend/src/database/entities/official.entity.ts.
enum OfficialRole {
  umpire('umpire', 'Umpire'),
  scorer('scorer', 'Scorer'),
  matchReferee('match_referee', 'Match Referee');

  const OfficialRole(this.value, this.label);

  final String value;
  final String label;

  static OfficialRole fromValue(String value) => OfficialRole.values.firstWhere(
        (role) => role.value == value,
        orElse: () => OfficialRole.umpire,
      );
}

/// Mirrors `OfficialStatus` in apps/backend/src/database/entities/official.entity.ts.
enum OfficialStatus {
  active('active', 'Active'),
  inactive('inactive', 'Inactive');

  const OfficialStatus(this.value, this.label);

  final String value;
  final String label;

  static OfficialStatus fromValue(String value) => OfficialStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => OfficialStatus.active,
      );
}

/// Mirrors apps/backend/src/database/entities/official.entity.ts — a single
/// org-level table covering umpires, scorers, and match referees via [role],
/// same lightweight "identity only" shape as `Coach`/`Venue`.
class Official {
  const Official({
    required this.id,
    required this.organizationId,
    required this.fullName,
    required this.role,
    this.phone,
    this.email,
    this.photoUrl,
    this.status = OfficialStatus.active,
    required this.createdAt,
  });

  factory Official.fromJson(Map<String, dynamic> json) => Official(
        id: json['id'] as String,
        organizationId: json['organizationId'] as String,
        fullName: json['fullName'] as String,
        role: OfficialRole.fromValue(json['role'] as String),
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        photoUrl: json['photoUrl'] as String?,
        status: OfficialStatus.fromValue(json['status'] as String? ?? 'active'),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String organizationId;
  final String fullName;
  final OfficialRole role;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final OfficialStatus status;
  final DateTime createdAt;
}
