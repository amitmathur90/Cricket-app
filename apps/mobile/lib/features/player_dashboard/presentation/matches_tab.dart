import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../matches/data/models/match.dart';
import '../../matches/presentation/widgets/match_card.dart';
import '../application/player_dashboard_providers.dart';
import 'widgets/match_info_sheet.dart';

enum _MatchFilterTab { upcoming, past, all }

/// Bottom-nav Matches tab — the caller's relevant matches (see
/// [playerRelevantMatchesProvider]), grouped by date with an Upcoming/Past/
/// All filter. Mirrors the admin `MatchesTab`'s list pattern
/// (features/matches/presentation/widgets/matches_tab.dart) minus the
/// admin-only "Add match" action: this is a read-only player view, so
/// tapping a match opens [showMatchInfoSheet] instead of pushing
/// `MatchDetailScreen`.
///
/// When [PlayerMatches.teamScoped] is false, a banner makes clear this is
/// the tournament's whole schedule, not specifically the caller's team — see
/// [playerRelevantMatchesProvider]'s doc comment for why that fallback
/// exists.
class PlayerMatchesTab extends ConsumerStatefulWidget {
  const PlayerMatchesTab({super.key});

  @override
  ConsumerState<PlayerMatchesTab> createState() => _PlayerMatchesTabState();
}

class _PlayerMatchesTabState extends ConsumerState<PlayerMatchesTab> {
  _MatchFilterTab _filter = _MatchFilterTab.upcoming;

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

    final dateFormat = DateFormat.yMMMEd();
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
    final matchesAsync = ref.watch(playerRelevantMatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Matches'), automaticallyImplyLeading: false),
      body: matchesAsync.when(
        data: (result) {
          if (result.tournamentId == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "You haven't applied to a tournament yet — your matches will show up here "
                  'once you do.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final now = DateTime.now();
          final filtered = switch (_filter) {
            _MatchFilterTab.upcoming => result.matches
                .where((m) => m.scheduledAt == null || !m.scheduledAt!.isBefore(now))
                .toList(),
            _MatchFilterTab.past => result.matches
                .where((m) => m.scheduledAt != null && m.scheduledAt!.isBefore(now))
                .toList(),
            _MatchFilterTab.all => result.matches,
          };
          final groups = _groupByDate(filtered, descending: _filter == _MatchFilterTab.past);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(playerRelevantMatchesProvider.future),
            child: Column(
              children: [
                if (!result.teamScoped)
                  Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      "Showing your tournament's full schedule — we couldn't confirm your "
                      'team roster yet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: SegmentedButton<_MatchFilterTab>(
                    segments: const [
                      ButtonSegment(value: _MatchFilterTab.upcoming, label: Text('Upcoming')),
                      ButtonSegment(value: _MatchFilterTab.past, label: Text('Past')),
                      ButtonSegment(value: _MatchFilterTab.all, label: Text('All')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (selection) => setState(() => _filter = selection.first),
                  ),
                ),
                Expanded(
                  child: groups.isEmpty
                      ? Center(
                          child: Text(
                            result.matches.isEmpty
                                ? 'No matches scheduled yet.'
                                : 'No matches in this view.',
                          ),
                        )
                      : ListView.builder(
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
                                for (final match in group.matches)
                                  MatchCard(match: match, onTap: () => showMatchInfoSheet(context, match)),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load matches'),
        ),
      ),
    );
  }
}

class _MatchGroup {
  _MatchGroup({required this.label, required this.matches});
  final String label;
  final List<Match> matches;
}
