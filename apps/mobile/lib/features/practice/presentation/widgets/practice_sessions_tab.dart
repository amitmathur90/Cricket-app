import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../application/practice_providers.dart';
import '../../data/models/practice_session.dart';
import 'practice_session_card.dart';

enum _PracticeFilterTab { upcoming, past, all }

/// A team's practice sessions — a chronological, grouped list with an
/// Upcoming/Past/All filter plus an "Add session" action, mirroring
/// MatchesTab's list pattern (see that widget's doc comment for the
/// calendar-vs-list reasoning, which applies identically here).
///
/// Reused in two places: embedded as TeamDetailScreen's "Coach" tab content
/// (via TeamCoachTab, scoped to that team) and as the body of the standalone
/// PracticeSessionsScreen reached from the admin drawer's "Practice" item —
/// both just need a [teamId], since practice sessions are team-scoped, not
/// tournament-scoped (unlike matches).
class PracticeSessionsTab extends ConsumerStatefulWidget {
  const PracticeSessionsTab({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<PracticeSessionsTab> createState() => _PracticeSessionsTabState();
}

class _PracticeSessionsTabState extends ConsumerState<PracticeSessionsTab> {
  _PracticeFilterTab _filter = _PracticeFilterTab.upcoming;

  void _openCreate(BuildContext context) {
    context.push(practiceSessionFormPath(widget.teamId));
  }

  void _openSession(BuildContext context, PracticeSession session) {
    context.push(practiceSessionDetailPath(widget.teamId, session.id), extra: session);
  }

  List<_PracticeGroup> _groupByDate(List<PracticeSession> sessions, {required bool descending}) {
    final sorted = [...sessions]
      ..sort((a, b) =>
          descending ? b.scheduledAt.compareTo(a.scheduledAt) : a.scheduledAt.compareTo(b.scheduledAt));

    final dateFormat = DateFormat.yMMMEd();
    final groups = <_PracticeGroup>[];
    for (final session in sorted) {
      final label = dateFormat.format(session.scheduledAt.toLocal());
      if (groups.isNotEmpty && groups.last.label == label) {
        groups.last.sessions.add(session);
      } else {
        groups.add(_PracticeGroup(label: label, sessions: [session]));
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final PracticeSessionsListKey providerKey = (teamId: widget.teamId, status: null);
    final sessionsAsync = ref.watch(practiceSessionsListProvider(providerKey));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<_PracticeFilterTab>(
                  segments: const [
                    ButtonSegment(value: _PracticeFilterTab.upcoming, label: Text('Upcoming')),
                    ButtonSegment(value: _PracticeFilterTab.past, label: Text('Past')),
                    ButtonSegment(value: _PracticeFilterTab.all, label: Text('All')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (selection) => setState(() => _filter = selection.first),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Add practice session',
                onPressed: () => _openCreate(context),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: sessionsAsync.when(
            data: (sessions) {
              final now = DateTime.now();
              final filtered = switch (_filter) {
                _PracticeFilterTab.upcoming =>
                  sessions.where((s) => !s.scheduledAt.isBefore(now)).toList(),
                _PracticeFilterTab.past => sessions.where((s) => s.scheduledAt.isBefore(now)).toList(),
                _PracticeFilterTab.all => sessions,
              };
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    sessions.isEmpty
                        ? 'No practice sessions scheduled yet.'
                        : 'No sessions in this view.',
                  ),
                );
              }
              final groups = _groupByDate(filtered, descending: _filter == _PracticeFilterTab.past);
              return RefreshIndicator(
                onRefresh: () => ref.refresh(practiceSessionsListProvider(providerKey).future),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 6),
                          child: Text(
                            group.label,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        for (final session in group.sessions)
                          PracticeSessionCard(session: session, onTap: () => _openSession(context, session)),
                      ],
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text(error is ApiException ? error.message : 'Failed to load practice sessions'),
            ),
          ),
        ),
      ],
    );
  }
}

class _PracticeGroup {
  _PracticeGroup({required this.label, required this.sessions});
  final String label;
  final List<PracticeSession> sessions;
}
