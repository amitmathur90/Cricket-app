import '../../../core/network/api_client.dart';
import 'models/sponsor.dart';

/// Talks to `SponsorsController` (apps/backend/src/modules/sponsors) —
/// org-level sponsor CRUD under `/organizations/:organizationId/sponsors`,
/// including the 5 display-surface visibility flags.
///
/// [update] always sends every editable field, even ones left unchanged —
/// same "single form covers create and edit" convention as
/// CoachesRepository.update. A `null` for logoUrl/packageName/amount/
/// contract dates explicitly clears it server-side (`@IsOptional()` on
/// `UpdateSponsorDto` treats `null` the same as "not provided" for
/// validation, then `SponsorsService.update`'s `Object.assign(sponsor, dto)`
/// stores that null).
class SponsorsRepository {
  SponsorsRepository(this._apiClient);

  final ApiClient _apiClient;

  String _base(String organizationId) => '/organizations/$organizationId/sponsors';

  Future<List<Sponsor>> list(String organizationId) async {
    final response = await _apiClient.get(_base(organizationId));
    return (response.data as List<dynamic>)
        .map((e) => Sponsor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Sponsor> get(String organizationId, String sponsorId) async {
    final response = await _apiClient.get('${_base(organizationId)}/$sponsorId');
    return Sponsor.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Sponsor> create(
    String organizationId, {
    required String companyName,
    String? logoUrl,
    String? packageName,
    String? amount,
    String? contractStartDate,
    String? contractEndDate,
    bool visibleOnWebsite = false,
    bool visibleOnApp = false,
    bool visibleOnMatchScreen = false,
    bool visibleOnScoreboard = false,
    bool visibleOnSocialMedia = false,
  }) async {
    final response = await _apiClient.post(
      _base(organizationId),
      data: {
        'companyName': companyName,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (packageName != null) 'packageName': packageName,
        if (amount != null) 'amount': amount,
        if (contractStartDate != null) 'contractStartDate': contractStartDate,
        if (contractEndDate != null) 'contractEndDate': contractEndDate,
        'visibleOnWebsite': visibleOnWebsite,
        'visibleOnApp': visibleOnApp,
        'visibleOnMatchScreen': visibleOnMatchScreen,
        'visibleOnScoreboard': visibleOnScoreboard,
        'visibleOnSocialMedia': visibleOnSocialMedia,
      },
    );
    return Sponsor.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Sponsor> update(
    String organizationId,
    String sponsorId, {
    required String companyName,
    String? logoUrl,
    String? packageName,
    String? amount,
    String? contractStartDate,
    String? contractEndDate,
    bool visibleOnWebsite = false,
    bool visibleOnApp = false,
    bool visibleOnMatchScreen = false,
    bool visibleOnScoreboard = false,
    bool visibleOnSocialMedia = false,
  }) async {
    final response = await _apiClient.patch(
      '${_base(organizationId)}/$sponsorId',
      data: {
        'companyName': companyName,
        'logoUrl': logoUrl,
        'packageName': packageName,
        'amount': amount,
        'contractStartDate': contractStartDate,
        'contractEndDate': contractEndDate,
        'visibleOnWebsite': visibleOnWebsite,
        'visibleOnApp': visibleOnApp,
        'visibleOnMatchScreen': visibleOnMatchScreen,
        'visibleOnScoreboard': visibleOnScoreboard,
        'visibleOnSocialMedia': visibleOnSocialMedia,
      },
    );
    return Sponsor.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String organizationId, String sponsorId) async {
    await _apiClient.delete('${_base(organizationId)}/$sponsorId');
  }
}
