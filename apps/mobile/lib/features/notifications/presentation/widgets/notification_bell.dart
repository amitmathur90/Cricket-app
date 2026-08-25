import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../application/notifications_providers.dart';

/// The AppBar bell icon — real unread-count badge (standard Material
/// [Badge]) that opens [NotificationCenterScreen] on tap. Used by both
/// AdminHomeScreen and PlayerHomeScreen's AppBars.
///
/// Refresh approach: this app has no WebSocket/push channel for
/// notifications (confirmed — `notifications.module.ts` only exposes REST
/// routes), so some form of polling or manual refresh is unavoidable to
/// keep the badge honest. Rather than a persistent background service, this
/// widget runs a simple `Timer.periodic` (45s) that just invalidates
/// [unreadNotificationCountProvider] while the bell itself is mounted (i.e.
/// while the user is on a home screen) — the timer is created in
/// [initState] and cancelled in [dispose], so it never runs when no home
/// screen is on-screen. The count is also refreshed immediately when the
/// user returns from the notification list (where they may have just read
/// things), so the badge never has to wait a full interval to catch up
/// after the one action that's guaranteed to change it.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) ref.invalidate(unreadNotificationCountProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _openNotificationCenter() async {
    await context.push(notificationsPath);
    if (!mounted) return;
    ref.invalidate(unreadNotificationCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final countAsync = ref.watch(unreadNotificationCountProvider);
    final count = countAsync.asData?.value ?? 0;

    return IconButton(
      tooltip: 'Notifications',
      icon: Badge(
        label: Text(count > 99 ? '99+' : '$count'),
        isLabelVisible: count > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: _openNotificationCenter,
    );
  }
}
