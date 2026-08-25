/// Mirrors `PlayerRole` in apps/backend/src/database/entities/player.entity.ts.
enum PlayerRole { batsman, bowler, allRounder, wicketkeeper }

extension PlayerRoleX on PlayerRole {
  String get apiValue => switch (this) {
        PlayerRole.batsman => 'batsman',
        PlayerRole.bowler => 'bowler',
        PlayerRole.allRounder => 'all_rounder',
        PlayerRole.wicketkeeper => 'wicketkeeper',
      };

  String get label => switch (this) {
        PlayerRole.batsman => 'Batsman',
        PlayerRole.bowler => 'Bowler',
        PlayerRole.allRounder => 'All-rounder',
        PlayerRole.wicketkeeper => 'Wicketkeeper',
      };

  static PlayerRole fromApi(String value) => PlayerRole.values.firstWhere(
        (r) => r.apiValue == value,
        orElse: () => PlayerRole.batsman,
      );
}

/// Mirrors `PlayerVerificationStatus` in
/// apps/backend/src/database/entities/player.entity.ts — a 4-stage flow.
/// Legal transitions (enforced server-side in
/// `PlayersService.ALLOWED_VERIFICATION_TRANSITIONS`):
///   pending  -> verified or rejected
///   verified -> approved or rejected
///   approved -> (terminal)
///   rejected -> (terminal)
enum PlayerVerificationStatus { pending, verified, approved, rejected }

extension PlayerVerificationStatusX on PlayerVerificationStatus {
  String get apiValue => switch (this) {
        PlayerVerificationStatus.pending => 'pending',
        PlayerVerificationStatus.verified => 'verified',
        PlayerVerificationStatus.approved => 'approved',
        PlayerVerificationStatus.rejected => 'rejected',
      };

  String get label => switch (this) {
        PlayerVerificationStatus.pending => 'Pending',
        PlayerVerificationStatus.verified => 'Verified',
        PlayerVerificationStatus.approved => 'Approved',
        PlayerVerificationStatus.rejected => 'Rejected',
      };

  static PlayerVerificationStatus fromApi(String value) =>
      PlayerVerificationStatus.values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => PlayerVerificationStatus.pending,
      );
}

/// Mirrors apps/backend/src/database/entities/player.entity.ts — an
/// org-level player profile (not yet rostered to any tournament-team).
class Player {
  const Player({
    required this.id,
    required this.organizationId,
    required this.fullName,
    required this.role,
    this.userId,
    this.dob,
    this.gender,
    this.phone,
    this.email,
    this.address,
    this.battingStyle,
    this.bowlingStyle,
    this.experience,
    this.preferredPosition,
    this.basePrice,
    this.photoUrl,
    this.idDocumentUrl,
    this.addressProofUrl,
    this.otherDocumentUrls,
    this.ageCategory,
    this.previousStatsNotes,
    this.isAvailable = true,
    this.unavailabilityReason,
    this.isAvailableForTournaments = true,
    this.isAvailableForMatches = true,
    this.isAvailableForPractice = true,
    this.verificationStatus = PlayerVerificationStatus.pending,
    this.verificationNote,
    this.rating,
  });

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        organizationId: json['organizationId'] as String,
        fullName: json['fullName'] as String,
        role: PlayerRoleX.fromApi(json['role'] as String),
        userId: json['userId'] as String?,
        dob: json['dob'] as String?,
        gender: json['gender'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        battingStyle: json['battingStyle'] as String?,
        bowlingStyle: json['bowlingStyle'] as String?,
        experience: json['experience'] as String?,
        preferredPosition: json['preferredPosition'] as String?,
        basePrice: json['basePrice'] as String?,
        photoUrl: json['photoUrl'] as String?,
        idDocumentUrl: json['idDocumentUrl'] as String?,
        addressProofUrl: json['addressProofUrl'] as String?,
        otherDocumentUrls: (json['otherDocumentUrls'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        ageCategory: json['ageCategory'] as String?,
        previousStatsNotes: json['previousStatsNotes'] as String?,
        isAvailable: json['isAvailable'] as bool? ?? true,
        unavailabilityReason: json['unavailabilityReason'] as String?,
        isAvailableForTournaments: json['isAvailableForTournaments'] as bool? ?? true,
        isAvailableForMatches: json['isAvailableForMatches'] as bool? ?? true,
        isAvailableForPractice: json['isAvailableForPractice'] as bool? ?? true,
        verificationStatus:
            PlayerVerificationStatusX.fromApi(json['verificationStatus'] as String? ?? 'pending'),
        verificationNote: json['verificationNote'] as String?,
        rating: json['rating'] as String?,
      );

  final String id;
  final String organizationId;
  final String fullName;
  final PlayerRole role;

  /// The linked login account for this player, if any (nullable — many
  /// players, especially amateur/local ones, never create an account; see
  /// Player entity's doc comment). Used by the Captain App's "Captain
  /// announcements" feature to resolve which squad members are actually
  /// reachable via `POST .../notifications` (recipientUserIds), since a
  /// notification is always addressed to a `userId`, not a `playerId`.
  final String? userId;

  final String? dob;

  // --- Personal information (free-text, mirroring the entity) ---
  final String? gender;
  final String? phone;
  final String? email;
  final String? address;

  final String? battingStyle;
  final String? bowlingStyle;
  final String? experience;
  final String? preferredPosition;

  /// Decimal-as-string, matching the backend's `numeric` column
  /// serialization (see Player entity `basePrice`).
  final String? basePrice;

  final String? photoUrl;
  final String? idDocumentUrl;
  final String? addressProofUrl;
  final List<String>? otherDocumentUrls;
  final String? ageCategory;
  final String? previousStatsNotes;

  /// @deprecated Superseded by isAvailableFor{Tournaments,Matches,Practice}
  /// below — kept because PlayerListTab's single-toggle action still uses it.
  final bool isAvailable;
  final String? unavailabilityReason;

  final bool isAvailableForTournaments;
  final bool isAvailableForMatches;
  final bool isAvailableForPractice;

  final PlayerVerificationStatus verificationStatus;
  final String? verificationNote;

  /// Decimal-as-string (0.00-5.00), matching the backend's `numeric` column.
  final String? rating;
}
