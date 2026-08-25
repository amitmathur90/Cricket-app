import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/models/app_notification.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

/// The caller's own notifications for the active org, newest first. Empty
/// (rather than an error) when there's no active org yet, same convention
/// as `tournamentsListProvider`.
final notificationsListProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(notificationsRepositoryProvider).list(organizationId);
});

/// Unread count for the bell icon's badge. `autoDispose` (not `keepAlive`)
/// deliberately — see [NotificationBell]'s doc comment for why polling is
/// scoped to that widget's lifetime rather than kept alive app-wide.
final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return 0;
  return ref.watch(notificationsRepositoryProvider).unreadCount(organizationId);
});
