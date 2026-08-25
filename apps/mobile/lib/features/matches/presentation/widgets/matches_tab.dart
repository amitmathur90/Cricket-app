import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/matches_providers.dart';
import '../../data/models/match.dart';
import 'match_card.dart';

enum _MatchFilterTab { upcoming, past, all }

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// The Sunday on/before [d] (Dart's `weekday` is Mon=1..Sun=7).
DateTime _startOfWeek(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday % 7));
}

/// Matches tab within TournamentDetailScreen — a "Schedule" panel: a month
/// navigator, a Sun-Sat week strip (tap a date to filter the list to that
/// exact day), the existing Upcoming/Past/All segmented filter, and a
/// chronological, date-grouped list of this tournament's fixtures, plus an
/// "Add match" action.
///
/// Calendar-vs-list decision: a full hand-rolled month grid (per-day
/// match-count dots, a day-detail sheet, arbitrary month paging synced to
/// list data) is a lot of extra surface area for uncertain payoff on a
/// phone screen, and this app deliberately avoids pulling in a calendar
/// package for it. The week strip below gives genuine date-picking — it
/// really filters the list — while staying within a plain-widgets, no-new-
/// package restyle; the month chevrons move the strip a month at a time
/// without needing a full grid. The Upcoming/Past/All filter is kept
/// alongside it (selecting a date clears the tab filter and vice versa) so
/// no existing filtering capability is lost.
class MatchesTab extends ConsumerStatefulWidget {
  const MatchesTab({super.key, required this.organizationId, required this.tournamentId});

  final String organizationId;
  final String tournamentId;

  @override
  ConsumerState<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends ConsumerState<MatchesTab> {
  _MatchFilterTab _filter = _MatchFilterTab.upcoming;

  /// Anchors both the month label and the displayed week (the week
  /// containing this date). Defaults to today; the month chevrons jump it
  /// to the 1st of the previous/next month.
  DateTime _weekAnchor = DateTime.now();

  /// Set when the user taps a date in the week strip — filters the list to
  /// that exact day, overriding [_filter]. Tapping the same date again, or
  /// changing [_filter], clears it.
  DateTime? _selectedDate;

  void _openCreate(BuildContext context) {
    context.push(matchFormPath(widget.tournamentId));
  }

  void _openMatch(BuildContext context, Match match) {
    context.push(matchDetailPath(widget.tournamentId, match.id), extra: match);
  }

  void _changeMonth(int delta) {
    setState(() {
      _weekAnchor = DateTime(_weekAnchor.year, _weekAnchor.month + delta, 1);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = (_selectedDate != null && _isSameDay(_selectedDate!, date)) ? null : date;
    });
  }

  List<_MatchGroup> _groupByDate(List<Match> matches, {required bool descending}) {
    final sorted = [...matches]
      ..sort((a, b) {
        final aDate = a.scheduledAt;
        final bDate = b.scheduledAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return descending ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
      });

    final dateFormat = DateFormat('d MMMM yyyy');
    final groups = <_MatchGroup>[];
    for (final match in sorted) {
      final label =
          match.scheduledAt == null ? 'Date TBD' : dateFormat.format(match.scheduledAt!.toLocal());
      if (groups.isNotEmpty && groups.last.label == label) {
        groups.last.matches.add(match);
      } else {
        groups.add(_MatchGroup(label: label, matches: [match]));
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final MatchesListKey providerKey = (tournamentId: widget.tournamentId, filter: null);
    final matchesAsync = ref.watch(matchesListProvider(providerKey));
    final monthLabel = DateFormat.yMMMM().format(_weekAnchor);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Schedule', style: Theme.of(context).textTheme.headlineSmall),
              ),
              IconButton.filledTonal(
                tooltip: 'Add match',
                onPressed: () => _openCreate(context),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left),
                color: AppColors.textSecondary,
              ),
              Text(
                monthLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        _WeekStrip(
          weekStart: _startOfWeek(_weekAnchor),
          selectedDate: _selectedDate,
          onSelect: _selectDate,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SegmentedButton<_MatchFilterTab>(
            segments: const [
              ButtonSegment(value: _MatchFilterTab.upcoming, label: Text('Upcoming')),
              ButtonSegment(value: _MatchFilterTab.past, label: Text('Past')),
              ButtonSegment(value: _MatchFilterTab.all, label: Text('All')),
            ],
            selected: {_filter},
            onSelectionChanged: (selection) => setState(() {
              _filter = selection.first;
              _selectedDate = null;
            }),
          ),
        ),
        Expanded(
          child: matchesAsync.when(
            data: (matches) {
              final now = DateTime.now();
              final selectedDate = _selectedDate;
              final filtered = selectedDate != null
                  ? matches
                      .where((m) =>
                          m.scheduledAt != null && _isSameDay(m.scheduledAt!.toLocal(), selectedDate))
                      .toList()
                  : switch (_filter) {
                      _MatchFilterTab.upcoming => matches
                          .where((m) => m.scheduledAt == null || !m.scheduledAt!.isBefore(now))
                          .toList(),
                      _MatchFilterTab.past => matches
                          .where((m) => m.scheduledAt != null && m.scheduledAt!.isBefore(now))
                          .toList(),
                      _MatchFilterTab.all => matches,
                    };
              if (filtered.isEmpty) {
                final message = selectedDate != null
                    ? 'No matches on ${DateFormat('d MMM yyyy').format(selectedDate)}.'
                    : (matches.isEmpty ? 'No matches scheduled yet.' : 'No matches in this view.');
                return Center(child: Text(message));
              }
              final groups = _groupByDate(
                filtered,
                descending: selectedDate == null && _filter == _MatchFilterTab.past,
              );
              return RefreshIndicator(
                onRefresh: () => ref.refresh(matchesListProvider(providerKey).future),
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
                                  color: AppColors.primary,
                                ),
                          ),
                        ),
                        for (final match in group.matches)
                          MatchCard(match: match, onTap: () => _openMatch(context, match)),
                      ],
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text(error is ApiException ? error.message : 'Failed to load matches'),
            ),
          ),
        ),
      ],
    );
  }
}

class _MatchGroup {
  _MatchGroup({required this.label, required this.matches});
  final String label;
  final List<Match> matches;
}

/// Sun-Sat horizontal date strip. Highlights [selectedDate] — or today, when
/// nothing is explicitly selected and today falls within the displayed
/// week — with a filled green circle; tapping a date calls [onSelect] to
/// filter the list below to that day (tapping the highlighted date again
/// clears the filter).
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.weekStart, required this.selectedDate, required this.onSelect});

  final DateTime weekStart;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelect;

  static const _dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: List.generate(7, (i) {
          final date = weekStart.add(Duration(days: i));
          final isToday = _isSameDay(date, today);
          final isSelected = selectedDate != null && _isSameDay(date, selectedDate!);
          final highlighted = isSelected || (selectedDate == null && isToday);
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(date),
              child: Column(
                children: [
                  Text(
                    _dayLabels[i],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: highlighted ? AppColors.primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: highlighted ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
