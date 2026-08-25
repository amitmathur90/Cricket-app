import 'package:flutter/material.dart';

/// Centered icon + message placeholder for a Team Detail tab that has no
/// backing data or endpoint yet — the same visual treatment as
/// AdminDrawer's "Soon"-badged items, translated into a full tab body
/// instead of a disabled list tile. Used both for tabs that are simply not
/// built yet (Coach, Matches, Statistics, Finance — explicitly out of this
/// project's MVP scope) and for tabs whose data would be real but the
/// backend currently has no GET endpoint to fetch it (Squad, Captain — see
/// team_detail_screen.dart's doc comment for the gap this reflects).
class TeamPlaceholderTab extends StatelessWidget {
  const TeamPlaceholderTab({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).disabledColor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: mutedColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: mutedColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: mutedColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
