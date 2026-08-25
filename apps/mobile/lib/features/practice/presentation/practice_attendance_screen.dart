import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../players/application/players_providers.dart';
import '../../players/data/models/player.dart';
import '../application/practice_providers.dart';
import '../data/models/practice_attendance.dart';
import '../data/models/practice_session.dart';

/// Attendance for one practice session — a roster of the org's players (the
/// same source PlayerListTab uses; the backend accepts any org-level player
/// with no roster/tournament-membership check, see
/// PracticeAttendanceService's doc comment) with a Present/Absent toggle per
/// row, plus a distinct "Not marked" state for players with no existing
/// attendance row.
///
/// Local edits accumulate in [_statuses] and are only sent to the server
/// when "Save attendance" is tapped — a bulk `PUT` with one entry per player
/// currently in Present/Absent state. Players left "Not marked" are simply
/// omitted from that submission (the backend only ever stores rows for
/// players who've been explicitly marked — there is no "unmark" call needed
/// here since an omitted player just never gets a row).
class PracticeAttendanceScreen extends ConsumerStatefulWidget {
  const PracticeAttendanceScreen({
    super.key,
    required this.teamId,
    required this.sessionId,
    this.initialSession,
  });

  final String teamId;
  final String sessionId;

  /// Passed via go_router `extra` for the app-bar subtitle; purely
  /// cosmetic, not required for the screen to function.
  final PracticeSession? initialSession;

  @override
  ConsumerState<PracticeAttendanceScreen> createState() => _PracticeAttendanceScreenState();
}

class _PracticeAttendanceScreenState extends ConsumerState<PracticeAttendanceScreen> {
  final Map<String, PracticeAttendanceStatus?> _statuses = {};
  bool _initialized = false;
  bool _saving = false;

  /// Seeds [_statuses] from the server's marked rows the first time
  /// attendance data arrives. Guarded by [_initialized] so a later refetch
  /// (e.g. after Save invalidates the provider) doesn't clobber in-progress
  /// local edits mid-session.
  void _seedFromAttendance(List<PracticeAttendance> attendance) {
    if (_initialized) return;
    for (final row in attendance) {
      _statuses[row.playerId] = row.status;
    }
    _initialized = true;
  }

  Future<void> _save(String organizationId) async {
    final entries = <String, PracticeAttendanceStatus>{
      for (final entry in _statuses.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Mark at least one player before saving.')));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(practiceAttendanceRepositoryProvider).markAttendance(
            organizationId,
            widget.teamId,
            widget.sessionId,
            entries,
          );
      ref.invalidate(
        practiceAttendanceProvider((teamId: widget.teamId, sessionId: widget.sessionId)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Attendance saved')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
    final key = (teamId: widget.teamId, sessionId: widget.sessionId);
    final attendanceAsync = ref.watch(practiceAttendanceProvider(key));
    final playersAsync = ref.watch(playersListProvider);
    final sessionLabel = widget.initialSession?.practiceType.label;

    return Scaffold(
      appBar: AppBar(
        title: Text(sessionLabel != null ? 'Attendance · $sessionLabel' : 'Attendance'),
      ),
      body: organizationId == null
          ? const Center(child: Text('No active organization'))
          : attendanceAsync.when(
              data: (attendance) {
                _seedFromAttendance(attendance);
                return playersAsync.when(
                  data: (players) {
                    if (players.isEmpty) {
                      return const Center(child: Text('No players in this organization yet.'));
                    }
                    return Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: players.length,
                            itemBuilder: (context, index) {
                              final player = players[index];
                              return _AttendanceRow(
                                player: player,
                                status: _statuses[player.id],
                                onChanged: (value) => setState(() => _statuses[player.id] = value),
                              );
                            },
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: FilledButton.icon(
                              onPressed: _saving ? null : () => _save(organizationId),
                              icon: _saving
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Save attendance'),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Center(
                    child: Text(error is ApiException ? error.message : 'Failed to load players'),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(error is ApiException ? error.message : 'Failed to load attendance'),
              ),
            ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.player, required this.status, required this.onChanged});

  final Player player;
  final PracticeAttendanceStatus? status;
  final ValueChanged<PracticeAttendanceStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).disabledColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage:
                  player.photoUrl != null ? NetworkImage(Env.mediaUrl(player.photoUrl!)) : null,
              child: player.photoUrl == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    player.fullName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Distinct "not yet marked" visual state — a muted label
                  // shown only when neither Present nor Absent is selected
                  // below, instead of defaulting to (and thereby hiding
                  // behind) either option.
                  Text(
                    status == null ? 'Not marked' : status!.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: status == null ? mutedColor : _statusColor(context, status!),
                          fontWeight: status == null ? FontWeight.normal : FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<PracticeAttendanceStatus>(
              segments: const [
                ButtonSegment(
                  value: PracticeAttendanceStatus.present,
                  label: Text('Present'),
                  icon: Icon(Icons.check),
                ),
                ButtonSegment(
                  value: PracticeAttendanceStatus.absent,
                  label: Text('Absent'),
                  icon: Icon(Icons.close),
                ),
              ],
              selected: status == null ? const {} : {status!},
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (selection) =>
                  onChanged(selection.isEmpty ? null : selection.first),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, PracticeAttendanceStatus status) => switch (status) {
        PracticeAttendanceStatus.present => Colors.green,
        PracticeAttendanceStatus.absent => Colors.red,
      };
}
