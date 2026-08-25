/// Mirrors `CoachStatus` in apps/backend/src/database/entities/coach.entity.ts.
enum CoachStatus {
  active('active', 'Active'),
  inactive('inactive', 'Inactive');

  const CoachStatus(this.value, this.label);

  final String value;
  final String label;

  static CoachStatus fromValue(String value) => CoachStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => CoachStatus.active,
      );
}

/// Mirrors apps/backend/src/database/entities/coach.entity.ts — a
/// lightweight org-level coach profile (no login/user account, same
/// "identity only" shape as a org-level `Player` without a user). Just
/// enough (name, contact, specialization, photo) to assign a named coach to
/// a practice session; not a staff/HR module.
class Coach {
  const Coach({
    required this.id,
    required this.organizationId,
    required this.fullName,
    this.phone,
    this.email,
    this.specialization,
    this.photoUrl,
    this.status = CoachStatus.active,
    required this.createdAt,
  });

  factory Coach.fromJson(Map<String, dynamic> json) => Coach(
        id: json['id'] as String,
        organizationId: json['organizationId'] as String,
        fullName: json['fullName'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        specialization: json['specialization'] as String?,
        photoUrl: json['photoUrl'] as String?,
        status: CoachStatus.fromValue(json['status'] as String? ?? 'active'),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String organizationId;
  final String fullName;
  final String? phone;
  final String? email;

  /// Free text, e.g. "Batting coach", "Fitness trainer" — deliberately not
  /// a fixed enum on the backend, so not one here either.
  final String? specialization;

  final String? photoUrl;
  final CoachStatus status;
  final DateTime createdAt;
}
