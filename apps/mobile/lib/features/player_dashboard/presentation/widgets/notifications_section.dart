import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../notifications/application/notifications_providers.dart';

/// Home tab's Notifications section — a compact entry point into the real
/// Notification Center (see features/notifications, which now exists: a
/// bell-icon pattern reused here as a summary tile rather than an AppBar
/// icon, since this dashboard's Home tab doesn't have its own bell slot).
/// Shows the caller's current unread count and opens the full list
/// (`NotificationCenterScreen`) on tap; the count is re-fetched on return
/// in case the visit changed it. Deliberately thin — no list-fetching logic
/// duplicated here, same "summary tile pushes into the full feature" shape
/// as the dashboard's other cards.
class NotificationsSection extends ConsumerWidget {
  const NotificationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadNotificationCountProvider);
    final count = countAsync.asData?.value ?? 0;

    return Card(
      child: ListTile(
        leading: Badge(
          label: Text(count > 99 ? '99+' : '$count'),
          isLabelVisible: count > 0,
          child: const Icon(Icons.notifications_outlined),
        ),
        title: const Text('Notifications'),
        subtitle: Text(count > 0 ? '$count unread' : "You're all caught up"),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await context.push(notificationsPath);
          ref.invalidate(unreadNotificationCountProvider);
        },
      ),
    );
  }
}
