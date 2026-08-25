/// Mirrors `SponsorStatus` in apps/backend/src/database/entities/sponsor.entity.ts.
enum SponsorStatus {
  active('active', 'Active'),
  inactive('inactive', 'Inactive');

  const SponsorStatus(this.value, this.label);

  final String value;
  final String label;

  static SponsorStatus fromValue(String value) => SponsorStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => SponsorStatus.active,
      );
}

/// Mirrors apps/backend/src/database/entities/sponsor.entity.ts — a
/// lightweight org-level sponsor profile, same shape as `Coach`/`Venue`/
/// `Official`. The `visibleOn*` flags are honest configuration metadata for
/// display surfaces this app doesn't render yet (tournament website, social
/// media, scoreboard overlay) — see the entity's doc comment; this feature
/// only stores/edits the flags, it does not build any of that display
/// wiring.
class Sponsor {
  const Sponsor({
    required this.id,
    required this.organizationId,
    required this.companyName,
    this.logoUrl,
    this.packageName,
    this.amount,
    this.contractStartDate,
    this.contractEndDate,
    this.status = SponsorStatus.active,
    this.visibleOnWebsite = false,
    this.visibleOnApp = false,
    this.visibleOnMatchScreen = false,
    this.visibleOnScoreboard = false,
    this.visibleOnSocialMedia = false,
    required this.createdAt,
  });

  factory Sponsor.fromJson(Map<String, dynamic> json) => Sponsor(
        id: json['id'] as String,
        organizationId: json['organizationId'] as String,
        companyName: json['companyName'] as String,
        logoUrl: json['logoUrl'] as String?,
        packageName: json['packageName'] as String?,
        amount: json['amount'] as String?,
        contractStartDate: json['contractStartDate'] as String?,
        contractEndDate: json['contractEndDate'] as String?,
        status: SponsorStatus.fromValue(json['status'] as String? ?? 'active'),
        visibleOnWebsite: json['visibleOnWebsite'] as bool? ?? false,
        visibleOnApp: json['visibleOnApp'] as bool? ?? false,
        visibleOnMatchScreen: json['visibleOnMatchScreen'] as bool? ?? false,
        visibleOnScoreboard: json['visibleOnScoreboard'] as bool? ?? false,
        visibleOnSocialMedia: json['visibleOnSocialMedia'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String organizationId;
  final String companyName;
  final String? logoUrl;

  /// Free text, e.g. "Title Sponsor", "Gold", "Silver" — deliberately not a
  /// fixed enum on the backend, so not one here either.
  final String? packageName;

  /// Decimal amount as a string (backend `NUMERIC` column, e.g. "500000.00")
  /// — kept as a string rather than parsed to `double` to avoid float
  /// rounding on a monetary value the client never does arithmetic on.
  final String? amount;

  /// ISO date, `YYYY-MM-DD`.
  final String? contractStartDate;

  /// ISO date, `YYYY-MM-DD`.
  final String? contractEndDate;

  final SponsorStatus status;

  final bool visibleOnWebsite;
  final bool visibleOnApp;
  final bool visibleOnMatchScreen;
  final bool visibleOnScoreboard;
  final bool visibleOnSocialMedia;

  final DateTime createdAt;
}
