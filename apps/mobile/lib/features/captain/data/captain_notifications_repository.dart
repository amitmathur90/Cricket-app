import '../../../core/network/api_client.dart';

/// Talks to `NotificationsController.create` (`POST
/// /organizations/:organizationId/notifications`) — the manual notification
/// endpoint the backend already opens up to `team_owner` alongside
/// org_admin/tournament_admin specifically for "the future Captain-App 'team
/// announcement' feature" (see NotificationsController.create's own doc
/// comment and `NotificationType.ANNOUNCEMENT`'s doc comment on the entity).
///
/// This is a deliberately minimal, write-only client: the full Notification
/// Center (inbox list, unread badge, mark-as-read) has not landed on mobile
/// yet (no `features/notifications` directory exists in this app as of this
/// feature's build), so rather than block "Captain announcements" on that
/// landing, this repository talks to the one endpoint the Captain App
/// actually needs — `POST /notifications` — directly. If/when a full
/// Notification Center feature lands, this can be deleted in favor of that
/// feature's own repository; nothing else in the app depends on this class.
class CaptainNotificationsRepository {
  CaptainNotificationsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Sends a `type: 'announcement'` notification to every id in
  /// [recipientUserIds] (one row per recipient — see
  /// `NotificationsService.notify`'s doc comment). Callers should filter to
  /// squad members that actually have a linked `Player.userId` first — a
  /// player with no linked account has nothing to notify.
  Future<void> sendAnnouncement(
    String organizationId, {
    required List<String> recipientUserIds,
    required String title,
    required String message,
  }) async {
    await _apiClient.post(
      '/organizations/$organizationId/notifications',
      data: {
        'recipientUserIds': recipientUserIds,
        'type': 'announcement',
        'title': title,
        'message': message,
      },
    );
  }
}
