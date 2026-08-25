/// Mirrors `VenueStatus` in apps/backend/src/database/entities/venue.entity.ts.
enum VenueStatus {
  active('active', 'Active'),
  inactive('inactive', 'Inactive');

  const VenueStatus(this.value, this.label);

  final String value;
  final String label;

  static VenueStatus fromValue(String value) => VenueStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => VenueStatus.active,
      );
}

/// Mirrors apps/backend/src/database/entities/venue.entity.ts — a
/// lightweight org-level venue/ground profile (no login/user account, same
/// "identity only" shape as `Coach`). Just enough (name, location, capacity,
/// pitch type, facilities, photo) to assign a real venue to a match instead
/// of (or in addition to) the free-text `Match.venueName` fallback.
class Venue {
  const Venue({
    required this.id,
    required this.organizationId,
    required this.name,
    this.location,
    this.capacity,
    this.pitchType,
    this.facilities,
    this.photoUrl,
    this.status = VenueStatus.active,
    required this.createdAt,
  });

  factory Venue.fromJson(Map<String, dynamic> json) => Venue(
        id: json['id'] as String,
        organizationId: json['organizationId'] as String,
        name: json['name'] as String,
        location: json['location'] as String?,
        capacity: json['capacity'] as int?,
        pitchType: json['pitchType'] as String?,
        facilities: json['facilities'] as String?,
        photoUrl: json['photoUrl'] as String?,
        status: VenueStatus.fromValue(json['status'] as String? ?? 'active'),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String organizationId;
  final String name;
  final String? location;
  final int? capacity;

  /// Free text, e.g. "Grass", "Turf", "Matting" — deliberately not a fixed
  /// enum on the backend, so not one here either.
  final String? pitchType;

  /// Free text list/description, e.g. "Parking, Floodlights, Pavilion".
  final String? facilities;

  final String? photoUrl;
  final VenueStatus status;
  final DateTime createdAt;
}

/// Mirrors `VenueDayStatus` in
/// apps/backend/src/modules/venues/venues.service.ts.
enum VenueDayStatus {
  available('available', 'Available'),
  booked('booked', 'Booked'),
  maintenance('maintenance', 'Maintenance');

  const VenueDayStatus(this.value, this.label);

  final String value;
  final String label;

  static VenueDayStatus fromValue(String value) => VenueDayStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => VenueDayStatus.available,
      );
}

/// Mirrors `VenueAvailabilityDay` — one day of the day-by-day availability
/// calendar returned by `GET .../venues/:venueId/availability`.
class VenueAvailabilityDay {
  const VenueAvailabilityDay({required this.date, required this.status});

  factory VenueAvailabilityDay.fromJson(Map<String, dynamic> json) => VenueAvailabilityDay(
        date: json['date'] as String,
        status: VenueDayStatus.fromValue(json['status'] as String),
      );

  /// ISO date, `YYYY-MM-DD`.
  final String date;
  final VenueDayStatus status;
}

/// Mirrors apps/backend/src/database/entities/venue-unavailability.entity.ts
/// — an explicit "this venue is unavailable on this date" record (the
/// "Maintenance" side of the availability calendar).
class VenueUnavailability {
  const VenueUnavailability({
    required this.id,
    required this.venueId,
    required this.date,
    this.reason,
    required this.createdAt,
  });

  factory VenueUnavailability.fromJson(Map<String, dynamic> json) => VenueUnavailability(
        id: json['id'] as String,
        venueId: json['venueId'] as String,
        date: json['date'] as String,
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String venueId;

  /// ISO date, `YYYY-MM-DD`.
  final String date;
  final String? reason;
  final DateTime createdAt;
}
