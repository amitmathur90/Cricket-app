import '../../../core/network/api_client.dart';
import 'models/venue.dart';

/// Talks to `VenuesController` (apps/backend/src/modules/venues) —
/// org-level venue CRUD under `/organizations/:organizationId/venues`, plus
/// the per-venue availability calendar and unavailability ("Maintenance")
/// records.
///
/// [update] always sends every editable field, even ones left unchanged —
/// same "single form covers create and edit" convention as
/// CoachesRepository.update. A `null` for location/capacity/pitchType/
/// facilities/photoUrl explicitly clears it server-side (`@IsOptional()` on
/// `UpdateVenueDto` treats `null` the same as "not provided" for validation,
/// then `VenuesService.update`'s `Object.assign(venue, dto)` stores that
/// null).
class VenuesRepository {
  VenuesRepository(this._apiClient);

  final ApiClient _apiClient;

  String _base(String organizationId) => '/organizations/$organizationId/venues';

  Future<List<Venue>> list(String organizationId) async {
    final response = await _apiClient.get(_base(organizationId));
    return (response.data as List<dynamic>)
        .map((e) => Venue.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Venue> get(String organizationId, String venueId) async {
    final response = await _apiClient.get('${_base(organizationId)}/$venueId');
    return Venue.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Venue> create(
    String organizationId, {
    required String name,
    String? location,
    int? capacity,
    String? pitchType,
    String? facilities,
    String? photoUrl,
  }) async {
    final response = await _apiClient.post(
      _base(organizationId),
      data: {
        'name': name,
        if (location != null) 'location': location,
        if (capacity != null) 'capacity': capacity,
        if (pitchType != null) 'pitchType': pitchType,
        if (facilities != null) 'facilities': facilities,
        if (photoUrl != null) 'photoUrl': photoUrl,
      },
    );
    return Venue.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Venue> update(
    String organizationId,
    String venueId, {
    required String name,
    String? location,
    int? capacity,
    String? pitchType,
    String? facilities,
    String? photoUrl,
  }) async {
    final response = await _apiClient.patch(
      '${_base(organizationId)}/$venueId',
      data: {
        'name': name,
        'location': location,
        'capacity': capacity,
        'pitchType': pitchType,
        'facilities': facilities,
        'photoUrl': photoUrl,
      },
    );
    return Venue.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String organizationId, String venueId) async {
    await _apiClient.delete('${_base(organizationId)}/$venueId');
  }

  /// Day-by-day availability calendar for `[from, to]` (inclusive) — see
  /// `VenuesService.getAvailability`'s doc comment for the
  /// booked/maintenance/available precedence rules.
  Future<List<VenueAvailabilityDay>> getAvailability(
    String organizationId,
    String venueId, {
    required DateTime from,
    required DateTime to,
  }) async {
    String dateKey(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final response = await _apiClient.get(
      '${_base(organizationId)}/$venueId/availability',
      queryParameters: {'from': dateKey(from), 'to': dateKey(to)},
    );
    return (response.data as List<dynamic>)
        .map((e) => VenueAvailabilityDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<VenueUnavailability>> listUnavailability(
    String organizationId,
    String venueId,
  ) async {
    final response = await _apiClient.get('${_base(organizationId)}/$venueId/unavailability');
    return (response.data as List<dynamic>)
        .map((e) => VenueUnavailability.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Marks a venue unavailable on [date] (`YYYY-MM-DD`), e.g. "Maintenance".
  Future<VenueUnavailability> addUnavailability(
    String organizationId,
    String venueId, {
    required String date,
    String? reason,
  }) async {
    final response = await _apiClient.post(
      '${_base(organizationId)}/$venueId/unavailability',
      data: {
        'date': date,
        if (reason != null) 'reason': reason,
      },
    );
    return VenueUnavailability.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> removeUnavailability(
    String organizationId,
    String venueId,
    String unavailabilityId,
  ) async {
    await _apiClient.delete('${_base(organizationId)}/$venueId/unavailability/$unavailabilityId');
  }
}
