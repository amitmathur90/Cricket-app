/// Mirrors `PUBLIC_SPONSOR_SELECT` in
/// apps/backend/src/modules/public/public-sponsors.controller.ts —
/// deliberately excludes `amount`, `contractStartDate`/`contractEndDate`
/// (financial/contract terms) and every `visibleOn*` flag (internal
/// display-surface configuration), unlike the authenticated `Sponsor` model
/// (features/sponsors/data/models/sponsor.dart). Only sponsors with
/// `visibleOnApp: true` are ever included — filtered server-side.
class PublicSponsor {
  const PublicSponsor({
    required this.id,
    required this.companyName,
    this.logoUrl,
    this.packageName,
  });

  factory PublicSponsor.fromJson(Map<String, dynamic> json) => PublicSponsor(
        id: json['id'] as String,
        companyName: json['companyName'] as String,
        logoUrl: json['logoUrl'] as String?,
        packageName: json['packageName'] as String?,
      );

  final String id;
  final String companyName;
  final String? logoUrl;

  /// Free text, e.g. "Title Sponsor", "Gold", "Silver".
  final String? packageName;
}
