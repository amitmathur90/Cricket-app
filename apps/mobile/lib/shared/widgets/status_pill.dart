import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A small rounded-pill label used for statuses everywhere (match/practice
/// status, verification stage, upcoming/completed, etc). Replaces the
/// separate near-duplicate `_Badge`/`MatchStatusBadge`/`PracticeStatusBadge`
/// implementations each screen previously defined.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// `true` renders a solid-color pill with white text (e.g. the red LIVE
  /// badge); `false` (default) renders a tinted-background pill with
  /// colored text (e.g. status tags in list rows).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    final bg = filled ? color : color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// The pulsing-dot "LIVE" pill specifically, since it recurs identically
/// across the dashboard, match centre, and live-scoring mockups.
class LivePill extends StatelessWidget {
  const LivePill({super.key, this.label = 'LIVE'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.live, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
