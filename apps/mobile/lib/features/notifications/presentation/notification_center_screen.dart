import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../application/notifications_providers.dart';
import '../data/models/app_notification.dart';

/// Chronological (newest-first, matching the backend's own sort) list of
/// the caller's own in-app notifications. Unread items are bold/highlighted;
/// tapping one marks it read (`PATCH .../notifications/:id/read`); an
/// AppBar action marks every unread notification read in one call
/// (`PATCH .../notifications/read-all`); pull-to-refresh reloads both the
/// list and the bell's unread count.
///
/// Refresh approach: this screen refreshes on entry and via
/// pull-to-refresh only — no `Timer.periodic` here. The bell icon
/// ([NotificationBell]) is the one place that polls (see its doc comment
/// for why), since it's the thing visible on every home-screen frame; once
/// the user has actually opened this list they're looking straight at it,
/// so a background timer re-fetching underneath them would only risk
/// disrupting scroll position/read taps for no real benefit.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  Future<void> _markAsRead(WidgetRef ref, String organizationId, AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await ref.read(notificationsRepositoryProvider).markAsRead(organizationId, notification.id);
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadNotificationCountProvider);
    } on ApiException {
      // Best-effort — the list will just show it as still-unread on next
      // refresh, no need for a blocking error surface for a read-receipt.
    }
  }

  Future<void> _markAllAsRead(BuildContext context, WidgetRef ref, String organizationId) async {
    try {
      await ref.read(notificationsRepositoryProvider).markAllAsRead(organizationId);
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadNotificationCountProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.refresh(notificationsListProvider.future),
      ref.refresh(unreadNotificationCountProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
    final notificationsAsync = ref.watch(notificationsListProvider);
    final hasUnread = notificationsAsync.asData?.value.any((n) => !n.isRead) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (organizationId != null)
            TextButton(
              onPressed: hasUnread ? () => _markAllAsRead(context, ref, organizationId) : null,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: organizationId == null
          ? const Center(child: Text('No active organization'))
          : RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: notificationsAsync.when(
                data: (notifications) {
                  if (notifications.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No notifications yet.')),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _NotificationTile(
                        notification: notification,
                        onTap: () => _markAsRead(ref, organizationId, notification),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Text(
                        error is ApiException ? error.message : 'Failed to load notifications',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.type) {
        NotificationType.matchReminder => Icons.sports_cricket,
        NotificationType.practiceReminder => Icons.fitness_center,
        NotificationType.auctionAnnouncement => Icons.gavel,
        NotificationType.playerApproval => Icons.how_to_reg,
        NotificationType.teamSelection => Icons.groups,
        NotificationType.matchResult => Icons.scoreboard,
        NotificationType.scheduleChange => Icons.event_busy,
        NotificationType.paymentReminder => Icons.payments,
        NotificationType.announcement => Icons.campaign,
      };

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unread = !notification.isRead;

    return Container(
      color: unread ? colorScheme.primaryContainer.withValues(alpha: 0.18) : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: unread
              ? colorScheme.primary.withValues(alpha: 0.15)
              : colorScheme.surfaceContainerHighest,
          child: Icon(_icon, color: unread ? colorScheme.primary : colorScheme.outline, size: 20),
        ),
        title: Text(
          notification.title,
          style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 2),
            Text(
              _relativeTime(notification.createdAt.toLocal()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: unread
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
              )
            : null,
      ),
    );
  }
}
