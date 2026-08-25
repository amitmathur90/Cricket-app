import 'package:flutter/material.dart';

/// Honest stand-in for a paid/unpaid checkbox on the Team fees / Player
/// fees screens — the backend's `paid`/`paidAt` fields are permanent
/// placeholders (`paid: false, paidAt: null` on every row; see
/// `TeamFeeRow`/`PlayerFeeRow`'s doc comments), since no payment-tracking
/// data exists anywhere in this codebase yet. Rendered as a neutral,
/// muted badge — same visual language as AdminDrawer's "Soon" badge — so
/// it reads as "not applicable" rather than "unpaid".
class NotTrackedChip extends StatelessWidget {
  const NotTrackedChip({super.key});

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).disabledColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: mutedColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Not tracked',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: mutedColor),
      ),
    );
  }
}
