import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../auth/application/session_controller.dart';
import '../../players/application/players_providers.dart';
import '../application/practice_providers.dart';
import '../data/models/practice_attendance.dart';
import '../data/models/practice_session.dart';
import 'widgets/practice_session_card.dart';

/// Practice session detail — full session info plus admin actions: Edit
/// (pushes PracticeSessionFormScreen pre-filled), "View Attendance" (pushes
/// PracticeAttendanceScreen), "Cancel session" (soft `PATCH { status:
/// 'cancelled' }`), and "Delete session" (hard delete — see
/// PracticeSessionsRepository.delete's doc comment for why, unlike
/// MatchDetailScreen, this exposes both).
///
/// Restyled to the card-based "CricLeague" visual language (see AppTheme):
/// a photo-style header — practice sessions have no image field in the data
/// model, so this is a colored placeholder graphic with a type-appropriate
/// icon, not a fabricated photo — followed by a details card and an
/// attendance-summary card with a custom-painted progress ring.
class PracticeSessionDetailScreen extends ConsumerWidget {
  const PracticeSessionDetailScreen({
    super.key,
    required this.teamId,
    required this.sessionId,
    this.initialSession,
  });

  final String teamId;
  final String sessionId;

  /// Passed via go_router `extra` by callers that already have the session
  /// loaded (PracticeSessionsTab) — shown immediately while
  /// [practiceSessionDetailProvider] refetches in the background. Null on a
  /// cold deep-link.
  final PracticeSession? initialSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (teamId: teamId, sessionId: sessionId);
    final sessionAsync = ref.watch(practiceSessionDetailProvider(key));
    final session = sessionAsync.value ?? initialSession;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice session'),
        actions: [
          if (session != null)
            IconButton(
              tooltip: 'Edit session',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push(practiceSessionFormPath(teamId), extra: session).then((_) {
                ref.invalidate(practiceSessionDetailProvider(key));
              }),
            ),
        ],
      ),
      body: session != null
          ? _DetailBody(teamId: teamId, session: session)
          : sessionAsync.when(
              data: (_) => const SizedBox.shrink(),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(error is ApiException ? error.message : 'Failed to load session'),
              ),
            ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.teamId, required this.session});

  final String teamId;
  final PracticeSession session;

  Future<void> _cancelSession(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel session?'),
        content: const Text(
          'This marks the session as cancelled. It stays visible in the schedule for history — '
          'this does not delete it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep session'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel session'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return;
    try {
      await ref.read(practiceSessionsRepositoryProvider).cancel(organizationId, teamId, session.id);
      ref.invalidate(practiceSessionDetailProvider((teamId: teamId, sessionId: session.id)));
      ref.invalidate(practiceSessionsListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Session cancelled')));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteSession(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text(
          'This permanently deletes this practice session and its attendance records. This '
          'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return;
    try {
      await ref.read(practiceSessionsRepositoryProvider).delete(organizationId, teamId, session.id);
      ref.invalidate(practiceSessionsListProvider);
      if (!context.mounted) return;
      context.pop();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoRows = <MapEntry<String, String>>[
      MapEntry('Coach', session.coachName ?? 'Not assigned'),
      MapEntry('Type', session.practiceType.label),
      if (session.durationMinutes != null)
        MapEntry('Duration', '${session.durationMinutes} minutes'),
      if ((session.notes ?? '').trim().isNotEmpty) MapEntry('Notes', session.notes!.trim()),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SessionHeader(session: session),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Details',
            child: Column(
              children: [
                for (var i = 0; i < infoRows.length; i++)
                  _InfoRow(
                    label: infoRows[i].key,
                    value: infoRows[i].value,
                    showDivider: i != infoRows.length - 1,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AttendanceSummaryCard(teamId: teamId, session: session),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () =>
                  context.push(practiceAttendancePath(teamId, session.id), extra: session),
              icon: const Icon(Icons.checklist_outlined),
              label: const Text('View Attendance'),
            ),
          ),
          const SizedBox(height: 24),
          if (session.status != PracticeSessionStatus.cancelled) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => _cancelSession(context, ref),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel session'),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => _deleteSession(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete session'),
          ),
        ],
      ),
    );
  }
}

/// Photo-style header. Practice sessions have no image field in the data
/// model (see [PracticeSession] — only `coachPhotoUrl` exists, for the coach
/// relation, not the session itself), so this renders an honest placeholder:
/// a colored gradient card with a type-appropriate icon, the practice type
/// as a title overlay, and the status pill — instead of fabricating a photo.
/// Date/time/venue render below the card as plain rows, per the mockup.
class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session});

  final PracticeSession session;

  static const _icons = {
    PracticeType.batting: Icons.sports_cricket,
    PracticeType.bowling: Icons.sports_baseball_outlined,
    PracticeType.fielding: Icons.sports_handball_outlined,
    PracticeType.fitness: Icons.fitness_center,
    PracticeType.netPractice: Icons.sports_cricket,
    PracticeType.strategySession: Icons.psychology_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final scheduledAt = session.scheduledAt.toLocal();
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');
    final timeFormat = DateFormat.jm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryLight, AppColors.primaryDark],
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    _icons[session.practiceType] ?? Icons.sports_cricket,
                    size: 76,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: StatusPill(
                    label: session.status.label,
                    color: practiceStatusColor(session.status),
                    filled: true,
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Text(
                    session.practiceType.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(dateFormat.format(scheduledAt), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 14),
            const Icon(Icons.access_time, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(timeFormat.format(scheduledAt), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.stadium_outlined, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                session.venueName ?? 'Venue TBD',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// White rounded card with an optional title — the section container shared
/// by the details card and the attendance card.
class _SectionCard extends StatelessWidget {
  const _SectionCard({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// One label/value row inside the details card — label left in muted gray,
/// value right in bold dark text, with a thin divider between rows.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.showDivider = true});

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

/// Attendance summary card: a custom-painted progress ring (green = present,
/// red = absent, gray track = pending) with "marked/total Players" centered,
/// plus a Present/Absent/Pending legend. Counts come from
/// [practiceAttendanceProvider] (marked rows) diffed against
/// [playersListProvider] (the org's full player list) — the same source
/// PracticeAttendanceScreen uses, since a player with no attendance row is
/// "pending", not synthesized as absent (see [PracticeAttendance]'s doc
/// comment).
class _AttendanceSummaryCard extends ConsumerWidget {
  const _AttendanceSummaryCard({required this.teamId, required this.session});

  final String teamId;
  final PracticeSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (teamId: teamId, sessionId: session.id);
    final attendanceAsync = ref.watch(practiceAttendanceProvider(key));
    final playersAsync = ref.watch(playersListProvider);

    Widget content;
    if (attendanceAsync.isLoading || playersAsync.isLoading) {
      content = const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (attendanceAsync.hasError || playersAsync.hasError) {
      content = const SizedBox(
        height: 140,
        child: Center(
          child: Text('Attendance unavailable', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    } else {
      final attendance = attendanceAsync.value ?? const <PracticeAttendance>[];
      final players = playersAsync.value ?? const [];
      final total = players.length;
      final present =
          attendance.where((a) => a.status == PracticeAttendanceStatus.present).length;
      final absent = attendance.where((a) => a.status == PracticeAttendanceStatus.absent).length;
      final pending = (total - present - absent).clamp(0, total);

      content = Column(
        children: [
          Center(child: _AttendanceRing(total: total, present: present, absent: absent)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttendanceLegendItem(color: AppColors.positive, label: 'Present', count: present),
              _AttendanceLegendItem(color: AppColors.negative, label: 'Absent', count: absent),
              _AttendanceLegendItem(color: AppColors.textMuted, label: 'Pending', count: pending),
            ],
          ),
        ],
      );
    }

    return _SectionCard(title: 'Attendance', child: content);
  }
}

class _AttendanceRing extends StatelessWidget {
  const _AttendanceRing({required this.total, required this.present, required this.absent});

  final int total;
  final int present;
  final int absent;

  @override
  Widget build(BuildContext context) {
    final marked = present + absent;
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(140, 140),
            painter: _AttendanceRingPainter(total: total, present: present, absent: absent),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$marked/$total',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              const Text('Players', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceRingPainter extends CustomPainter {
  _AttendanceRingPainter({required this.total, required this.present, required this.absent});

  final int total;
  final int present;
  final int absent;

  static const _strokeWidth = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (total <= 0) return;
    const start = -math.pi / 2;
    final presentSweep = 2 * math.pi * (present / total);
    final absentSweep = 2 * math.pi * (absent / total);

    if (presentSweep > 0) {
      canvas.drawArc(
        rect,
        start,
        presentSweep,
        false,
        Paint()
          ..color = AppColors.positive
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
    if (absentSweep > 0) {
      canvas.drawArc(
        rect,
        start + presentSweep,
        absentSweep,
        false,
        Paint()
          ..color = AppColors.negative
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AttendanceRingPainter oldDelegate) =>
      oldDelegate.total != total || oldDelegate.present != present || oldDelegate.absent != absent;
}

class _AttendanceLegendItem extends StatelessWidget {
  const _AttendanceLegendItem({required this.color, required this.label, required this.count});

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
