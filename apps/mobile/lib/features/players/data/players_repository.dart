import '../../../core/network/api_client.dart';
import 'models/player.dart';
import 'models/player_statistics.dart';

/// Talks to `PlayersController` (apps/backend/src/modules/players) —
/// org-level player CRUD under `/organizations/:organizationId/players`.
/// Roster assignment (`POST .../:playerId/tournament-teams/:id/roster`) is
/// out of scope for M1's screens.
class PlayersRepository {
  PlayersRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Player>> list(String organizationId) async {
    final response = await _apiClient.get('/organizations/$organizationId/players');
    return (response.data as List<dynamic>)
        .map((e) => Player.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches one player's full org-level profile — `GET
  /// .../players/:playerId` (`PlayersController.findOne`). Used to enrich
  /// screens that only receive a trimmed player projection over another
  /// channel (e.g. the live auction room's WS payloads only carry
  /// `{id, fullName, role, photoUrl}` — see AuctionLotPlayer's doc comment
  /// in auction_pool_entry.dart) with fields like `battingStyle`/
  /// `bowlingStyle` that only this full-record endpoint returns.
  Future<Player> getOne(String organizationId, String playerId) async {
    final response = await _apiClient.get('/organizations/$organizationId/players/$playerId');
    return Player.fromJson(response.data as Map<String, dynamic>);
  }

  /// Matches `CreatePlayerDto` exactly (apps/backend/src/modules/players/dto/create-player.dto.ts):
  /// [fullName], [role], [photoUrl], [idDocumentUrl], [ageCategory] and
  /// [previousStatsNotes] are required there; everything else is optional.
  /// Note the granular `isAvailableFor*` flags are NOT part of the create
  /// payload (the DTO only exposes them via update) — set them afterwards
  /// with [updateAvailabilityFlags] if they need to differ from the
  /// server-side default of `true`.
  Future<Player> create(
    String organizationId, {
    required String fullName,
    required PlayerRole role,
    required String ageCategory,
    required String previousStatsNotes,
    required String photoUrl,
    required String idDocumentUrl,
    String? dob,
    String? gender,
    String? phone,
    String? email,
    String? address,
    String? battingStyle,
    String? bowlingStyle,
    String? experience,
    String? preferredPosition,
    String? addressProofUrl,
    List<String>? otherDocumentUrls,
    num? basePrice,
  }) async {
    final response = await _apiClient.post(
      '/organizations/$organizationId/players',
      data: {
        'fullName': fullName,
        'role': role.apiValue,
        'ageCategory': ageCategory,
        'previousStatsNotes': previousStatsNotes,
        'photoUrl': photoUrl,
        'idDocumentUrl': idDocumentUrl,
        if (dob != null && dob.trim().isNotEmpty) 'dob': dob,
        if (gender != null && gender.trim().isNotEmpty) 'gender': gender.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
        if (battingStyle != null && battingStyle.trim().isNotEmpty)
          'battingStyle': battingStyle.trim(),
        if (bowlingStyle != null && bowlingStyle.trim().isNotEmpty)
          'bowlingStyle': bowlingStyle.trim(),
        if (experience != null && experience.trim().isNotEmpty) 'experience': experience.trim(),
        if (preferredPosition != null && preferredPosition.trim().isNotEmpty)
          'preferredPosition': preferredPosition.trim(),
        if (addressProofUrl != null && addressProofUrl.trim().isNotEmpty)
          'addressProofUrl': addressProofUrl.trim(),
        if (otherDocumentUrls != null && otherDocumentUrls.isNotEmpty)
          'otherDocumentUrls': otherDocumentUrls,
        if (basePrice != null) 'basePrice': basePrice,
      },
    );
    return Player.fromJson(response.data as Map<String, dynamic>);
  }

  /// Sets the three granular availability flags via the generic `PATCH
  /// .../players/:id` endpoint (`UpdatePlayerDto`) — these aren't part of
  /// `CreatePlayerDto`, so the registration wizard calls this right after
  /// [create] whenever any flag needs to differ from the default `true`.
  /// Deliberately separate from [setAvailability], which drives the legacy
  /// single `isAvailable` toggle still used elsewhere in the UI.
  Future<Player> updateAvailabilityFlags(
    String organizationId,
    String playerId, {
    bool? isAvailableForTournaments,
    bool? isAvailableForMatches,
    bool? isAvailableForPractice,
  }) async {
    final response = await _apiClient.patch(
      '/organizations/$organizationId/players/$playerId',
      data: {
        if (isAvailableForTournaments != null)
          'isAvailableForTournaments': isAvailableForTournaments,
        if (isAvailableForMatches != null) 'isAvailableForMatches': isAvailableForMatches,
        if (isAvailableForPractice != null) 'isAvailableForPractice': isAvailableForPractice,
      },
    );
    return Player.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Player> setAvailability(
    String organizationId,
    String playerId, {
    required bool isAvailable,
    String? unavailabilityReason,
  }) async {
    final response = await _apiClient.patch(
      '/organizations/$organizationId/players/$playerId',
      data: {
        'isAvailable': isAvailable,
        if (!isAvailable && unavailabilityReason != null && unavailabilityReason.trim().isNotEmpty)
          'unavailabilityReason': unavailabilityReason.trim(),
      },
    );
    return Player.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Player> setVerification(
    String organizationId,
    String playerId, {
    required PlayerVerificationStatus status,
    String? note,
  }) async {
    final response = await _apiClient.patch(
      '/organizations/$organizationId/players/$playerId/verification',
      data: {
        'status': status.apiValue,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return Player.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Player> setRating(String organizationId, String playerId, double rating) async {
    final response = await _apiClient.patch(
      '/organizations/$organizationId/players/$playerId/rating',
      data: {'rating': rating},
    );
    return Player.fromJson(response.data as Map<String, dynamic>);
  }

  /// Career/cross-match statistics — `GET .../players/:playerId/statistics`
  /// (`PlayersController.getStatistics`). Backs `PlayerStatisticsScreen`.
  Future<PlayerStatistics> getStatistics(String organizationId, String playerId) async {
    final response = await _apiClient.get('/organizations/$organizationId/players/$playerId/statistics');
    return PlayerStatistics.fromJson(response.data as Map<String, dynamic>);
  }

  /// Adds an existing org-level player to a tournament-team's roster —
  /// `POST .../players/:playerId/tournament-teams/:tournamentTeamId/roster`
  /// (`AddToRosterDto`). Backs Quick Match's "Add existing player" flow.
  Future<void> addToRoster(
    String organizationId,
    String playerId,
    String tournamentTeamId,
  ) async {
    await _apiClient.post(
      '/organizations/$organizationId/players/$playerId/tournament-teams/$tournamentTeamId/roster',
      data: const {},
    );
  }

  /// Find-or-create a player by phone number and add them straight to a
  /// tournament-team roster in one call — `POST .../players/quick-add/
  /// tournament-teams/:tournamentTeamId/roster` (`QuickAddPlayerDto`).
  /// Backs Quick Match's "Add via phone number" flow.
  Future<void> quickAddByPhone(
    String organizationId,
    String tournamentTeamId, {
    required String phone,
    String? fullName,
  }) async {
    await _apiClient.post(
      '/organizations/$organizationId/players/quick-add/tournament-teams/$tournamentTeamId/roster',
      data: {
        'phone': phone,
        if (fullName != null && fullName.trim().isNotEmpty) 'fullName': fullName.trim(),
      },
    );
  }
}
