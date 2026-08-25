import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../matches/data/models/match.dart';
import '../../../matches/presentation/widgets/match_card.dart';
import '../../../teams/data/models/team.dart';
import '../../application/captain_providers.dart';

enum _MatchFilterTab { upcoming, past, all }

/// Matches tab for the Captain App — this team's matches across every
/// tournament it's registered to (see [captainMatchesProvider]'s doc
/// comment), each with a "Select Playing XI" action for scheduled/live
/// matches that pushes straight into the existing [LineupSelectionScreen]
/// (features/matches/presentation/lineup_selection_screen.dart) — the same
/// screen the admin-side Match detail screen uses, reused as-is per the
/// spec ("this is exactly 'Select Playing XI' from the spec, reuse it
/// directly"). Tapping the card itself opens the existing MatchDetailScreen,
/// satisfying "View opponent"/"View match details".
class CaptainMatchesTab extends ConsumerStatefulWidget {
  const CaptainMatchesTab({super.key, required this.team});

  final Team team;

  @override
  ConsumerState<CaptainMatchesTab> createState() => _CaptainMatchesTabState();
}

class _CaptainMatchesTabState extends ConsumerState<CaptainMatchesTab> {
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
    final key = (teamId: widget.team.id, teamName: widget.team.name);
    final matchesAsync = ref.watch(captainMatchesProvider(key));

    return Column(
      children: [
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
          child: matchesAsync.when(
            data: (matches) {
              final now = DateTime.now();
              final filtered = switch (_filter) {
                _MatchFilterTab.upcoming => matches
                    .where((m) => m.scheduledAt == null || !m.scheduledAt!.isBefore(now))
                    .toList(),
                _MatchFilterTab.past =>
                  matches.where((m) => m.scheduledAt != null && m.scheduledAt!.isBefore(now)).toList(),
                _MatchFilterTab.all => matches,
              };
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    matches.isEmpty
                        ? '${widget.team.name} has no matches scheduled yet.'
                        : 'No matches in this view.',
                  ),
                );
              }
              final groups = _groupByDate(filtered, descending: _filter == _MatchFilterTab.past);
              return RefreshIndicator(
                onRefresh: () => ref.refresh(captainMatchesProvider(key).future),
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
                        for (final match in group.matches)
                          _CaptainMatchCard(match: match, team: widget.team),
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

/// Wraps the shared [MatchCard] with a "Select Playing XI" action for this
/// team's own side of the match, when that side's `tournamentTeamId` is
/// known and the match hasn't been cancelled.
class _CaptainMatchCard extends StatelessWidget {
  const _CaptainMatchCard({required this.match, required this.team});

  final Match match;
  final Team team;

  @override
  Widget build(BuildContext context) {
    final isHome = matchIsHomeTeam(match, team.name);
    final ourTournamentTeamId = isHome ? match.homeTournamentTeamId : match.awayTournamentTeamId;
    final canSelectXi = ourTournamentTeamId != null &&
        match.status != MatchStatus.cancelled &&
        match.status != MatchStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MatchCard(
          match: match,
          onTap: () => context.push(matchDetailPath(match.tournamentId, match.id), extra: match),
        ),
        if (canSelectXi)
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  lineupSelectionPath(match.tournamentId, match.id, ourTournamentTeamId),
                ),
                icon: const Icon(Icons.checklist_outlined, size: 18),
                label: const Text('Select Playing XI'),
              ),
            ),
          ),
      ],
    );
  }
}
