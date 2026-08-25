import '../../../core/network/api_client.dart';
import 'models/app_notification.dart';

/// Talks to `NotificationsController`
/// (apps/backend/src/modules/notifications) — all routes are nested under
/// `/organizations/:organizationId/notifications` and are always scoped to
/// the calling user's own notifications server-side (see that controller's
/// doc comment).
class NotificationsRepository {
  NotificationsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// `GET .../notifications` — the caller's own notifications, newest
  /// first (backend does the sorting; this does no client-side re-sort,
  /// same convention as `TournamentsRepository.getPointsTable`).
  Future<List<AppNotification>> list(
    String organizationId, {
    bool unreadOnly = false,
    int? limit,
    int? offset,
  }) async {
    final response = await _apiClient.get(
      '/organizations/$organizationId/notifications',
      queryParameters: {
        if (unreadOnly) 'unreadOnly': 'true',
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET .../notifications/unread-count` — for the bell icon's badge.
  Future<int> unreadCount(String organizationId) async {
    final response = await _apiClient.get('/organizations/$organizationId/notifications/unread-count');
    final data = response.data as Map<String, dynamic>;
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  /// `PATCH .../notifications/:notificationId/read`.
  Future<AppNotification> markAsRead(String organizationId, String notificationId) async {
    final response =
        await _apiClient.patch('/organizations/$organizationId/notifications/$notificationId/read');
    return AppNotification.fromJson(response.data as Map<String, dynamic>);
  }

  /// `PATCH .../notifications/read-all` — returns the number of rows
  /// updated.
  Future<int> markAllAsRead(String organizationId) async {
    final response = await _apiClient.patch('/organizations/$organizationId/notifications/read-all');
    final data = response.data as Map<String, dynamic>;
    return (data['updated'] as num?)?.toInt() ?? 0;
  }
}
