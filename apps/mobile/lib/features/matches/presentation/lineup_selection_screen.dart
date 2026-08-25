import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../players/data/models/player.dart';
import '../../teams/application/teams_providers.dart';
import '../../teams/data/models/roster_entry.dart';
import '../application/matches_providers.dart';
import '../data/models/match.dart';
import '../data/models/match_lineup.dart';

/// "Select Playing XI" — reached from MatchDetailScreen, once per side
/// (home/away) of a match. Requires the requested [tournamentTeamId] to be
/// this match's home or away team (the backend enforces the same, see
/// `MatchLineupService.setLineup`).
///
/// Resolving the roster to show needs an org-level `teamId`
/// (`TeamsController.getRoster` is keyed by team id, not
/// `tournamentTeamId`), which `Match` doesn't carry directly. This screen
/// resolves it the same way `TeamAuctionTab`/`TeamMatchesTab` already do for
/// an equivalent gap: match `homeTeamName`/`awayTeamName` (which the backend
/// resolves server-side) against the org's teams list by name — there is no
/// direct `tournamentTeamId -> teamId` lookup exposed anywhere in the
/// backend today. This is a real, documented gap, not a one-off shortcut.
class LineupSelectionScreen extends ConsumerWidget {
  const LineupSelectionScreen({
    super.key,
    required this.tournamentId,
    required this.matchId,
    required this.tournamentTeamId,
  });

  final String tournamentId;
  final String matchId;
  final String tournamentTeamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
    final matchKey = (tournamentId: tournamentId, matchId: matchId);
    final matchAsync = ref.watch(matchDetailProvider(matchKey));

    return Scaffold(
      appBar: AppBar(title: const Text('Select Playing XI')),
      body: organizationId == null
          ? const Center(child: Text('No active organization'))
          : matchAsync.when(
              data: (match) => _ResolveTeam(
                organizationId: organizationId,
                tournamentId: tournamentId,
                matchId: matchId,
                tournamentTeamId: tournamentTeamId,
                match: match,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(error is ApiException ? error.message : 'Failed to load match'),
              ),
            ),
    );
  }
}

String? _teamNameFor(Match match, String tournamentTeamId) {
  if (match.homeTournamentTeamId == tournamentTeamId) return match.homeTeamName ?? 'Home team';
  if (match.awayTournamentTeamId == tournamentTeamId) return match.awayTeamName ?? 'Away team';
  return null;
}

class _ResolveTeam extends ConsumerWidget {
  const _ResolveTeam({
    required this.organizationId,
    required this.tournamentId,
    required this.matchId,
    required this.tournamentTeamId,
    required this.match,
  });

  final String organizationId;
  final String tournamentId;
  final String matchId;
  final String tournamentTeamId;
  final Match match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamName = _teamNameFor(match, tournamentTeamId);
    if (teamName == null) {
      return const Center(child: Text("This team isn't part of this match."));
    }

    final teamsAsync = ref.watch(teamsListProvider);
    return teamsAsync.when(
      data: (teams) {
        final normalized = teamName.trim().toLowerCase();
        String? teamId;
        for (final team in teams) {
          if (team.name.trim().toLowerCase() == normalized) {
            teamId = team.id;
            break;
          }
        }
        if (teamId == null) {
          return Center(child: Text('Could not find a team record for "$teamName".'));
        }
        return _LoadRosterAndLineup(
          organizationId: organizationId,
          tournamentId: tournamentId,
          matchId: matchId,
          tournamentTeamId: tournamentTeamId,
          teamId: teamId,
          teamName: teamName,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(error is ApiException ? error.message : 'Failed to load teams'),
      ),
    );
  }
}

class _LoadRosterAndLineup extends ConsumerWidget {
  const _LoadRosterAndLineup({
    required this.organizationId,
    required this.tournamentId,
    required this.matchId,
    required this.tournamentTeamId,
    required this.teamId,
    required this.teamName,
  });

  final String organizationId;
  final String tournamentId;
  final String matchId;
  final String tournamentTeamId;
  final String teamId;
  final String teamName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rosterAsync = ref.watch(rosterProvider((teamId: teamId, tournamentId: tournamentId)));
    final lineupAsync =
        ref.watch(matchLineupProvider((tournamentId: tournamentId, matchId: matchId)));

    if (rosterAsync.isLoading || lineupAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rosterAsync.hasError) {
      final error = rosterAsync.error;
      return Center(child: Text(error is ApiException ? error.message : 'Failed to load roster'));
    }
    if (lineupAsync.hasError) {
      final error = lineupAsync.error;
      return Center(child: Text(error is ApiException ? error.message : 'Failed to load lineup'));
    }

    final roster = rosterAsync.value ?? const <RosterEntry>[];
    if (roster.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '$teamName has no roster entries in this tournament yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).disabledColor),
          ),
        ),
      );
    }

    return _LineupEditor(
      organizationId: organizationId,
      tournamentId: tournamentId,
      matchId: matchId,
      tournamentTeamId: tournamentTeamId,
      teamName: teamName,
      roster: roster,
      existing: lineupAsync.value?.forTeam(tournamentTeamId),
    );
  }
}

enum _Selection { none, playing, substitute }

/// Owns the in-progress checklist state locally: [_selections] starts from
/// the existing lineup GET (or entirely "none" for a fresh selection, per
/// the spec's "default to empty if none exists yet"), and is only submitted
/// to the backend when "Save lineup" is tapped — the whole screen's state is
/// sent in one `PUT` (see MatchLineupRepository.setLineup's doc comment).
class _LineupEditor extends ConsumerStatefulWidget {
  const _LineupEditor({
    required this.organizationId,
    required this.tournamentId,
    required this.matchId,
    required this.tournamentTeamId,
    required this.teamName,
    required this.roster,
    required this.existing,
  });

  final String organizationId;
  final String tournamentId;
  final String matchId;
  final String tournamentTeamId;
  final String teamName;
  final List<RosterEntry> roster;
  final TeamLineup? existing;

  @override
  ConsumerState<_LineupEditor> createState() => _LineupEditorState();
}

class _LineupEditorState extends ConsumerState<_LineupEditor> {
  late Map<String, _Selection> _selections;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selections = {for (final entry in widget.roster) entry.id: _Selection.none};
    final existing = widget.existing;
    if (existing != null) {
      for (final id in existing.playingTeamPlayerIds) {
        if (_selections.containsKey(id)) _selections[id] = _Selection.playing;
      }
      for (final id in existing.substituteTeamPlayerIds) {
        if (_selections.containsKey(id)) _selections[id] = _Selection.substitute;
      }
    }
  }

  int get _playingCount => _selections.values.where((s) => s == _Selection.playing).length;

  Future<void> _save() async {
    final playing = <String>[];
    final subs = <String>[];
    for (final entry in _selections.entries) {
      if (entry.value == _Selection.playing) playing.add(entry.key);
      if (entry.value == _Selection.substitute) subs.add(entry.key);
    }

    setState(() => _saving = true);
    try {
      await ref.read(matchLineupRepositoryProvider).setLineup(
            widget.organizationId,
            widget.tournamentId,
            widget.matchId,
            widget.tournamentTeamId,
            playingTeamPlayerIds: playing,
            substituteTeamPlayerIds: subs,
          );
      ref.invalidate(
        matchLineupProvider((tournamentId: widget.tournamentId, matchId: widget.matchId)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Playing XI saved')));
      Navigator.of(context).maybePop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setSelection(String teamPlayerId, _Selection selection) {
    setState(() => _selections[teamPlayerId] = selection);
  }

  @override
  Widget build(BuildContext context) {
    final playingCount = _playingCount;
    final canSave = playingCount == 11 && !_saving;

    final playingEntries =
        widget.roster.where((e) => _selections[e.id] == _Selection.playing).toList();
    final subEntries =
        widget.roster.where((e) => _selections[e.id] == _Selection.substitute).toList();
    final unselectedEntries =
        widget.roster.where((e) => _selections[e.id] == _Selection.none).toList();

    return Column(
      children: [
        _CountHeader(teamName: widget.teamName, playingCount: playingCount),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            children: [
              _SectionHeader('Playing XI ($playingCount/11)'),
              if (playingEntries.isEmpty)
                const _EmptySection('No players selected yet.')
              else
                for (final entry in playingEntries)
                  _PlayerRow(entry: entry, selection: _Selection.playing, onChanged: _setSelection),
              const SizedBox(height: 16),
              _SectionHeader('Substitutes (${subEntries.length})'),
              if (subEntries.isEmpty)
                const _EmptySection('No substitutes selected.')
              else
                for (final entry in subEntries)
                  _PlayerRow(
                    entry: entry,
                    selection: _Selection.substitute,
                    onChanged: _setSelection,
                  ),
              const SizedBox(height: 16),
              _SectionHeader('Squad (${unselectedEntries.length})'),
              if (unselectedEntries.isEmpty)
                const _EmptySection('Every squad player has been placed.')
              else
                for (final entry in unselectedEntries)
                  _PlayerRow(entry: entry, selection: _Selection.none, onChanged: _setSelection),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSave ? _save : null,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        playingCount == 11
                            ? 'Save lineup'
                            : 'Select exactly 11 to save ($playingCount/11)',
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountHeader extends StatelessWidget {
  const _CountHeader({required this.teamName, required this.playingCount});

  final String teamName;
  final int playingCount;

  @override
  Widget build(BuildContext context) {
    final complete = playingCount == 11;
    final over = playingCount > 11;
    final color = complete ? Colors.green : Theme.of(context).colorScheme.error;
    final remaining = (playingCount - 11).abs();
    final message = complete
        ? 'Playing XI complete.'
        : over
            ? 'Remove $remaining player${remaining == 1 ? '' : 's'} from the Playing XI.'
            : 'Select $remaining more player${remaining == 1 ? '' : 's'} for the Playing XI.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teamName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(complete ? Icons.check_circle : Icons.info_outline, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(message, style: TextStyle(color: color, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(message, style: TextStyle(color: Theme.of(context).disabledColor)),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.entry, required this.selection, required this.onChanged});

  final RosterEntry entry;
  final _Selection selection;
  final void Function(String teamPlayerId, _Selection selection) onChanged;

  @override
  Widget build(BuildContext context) {
    final player = entry.player;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              player.photoUrl != null ? NetworkImage(Env.mediaUrl(player.photoUrl!)) : null,
          child: player.photoUrl == null ? const Icon(Icons.person) : null,
        ),
        title: Row(
          children: [
            Flexible(child: Text(player.fullName, overflow: TextOverflow.ellipsis)),
            if (entry.jerseyNumber != null) ...[
              const SizedBox(width: 6),
              Text('#${entry.jerseyNumber}', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (entry.isCaptain) ...[
              const SizedBox(width: 6),
              const Text('C', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
            ],
            if (entry.isViceCaptain) ...[
              const SizedBox(width: 6),
              const Text('VC', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
            ],
          ],
        ),
        subtitle: Text(player.role.label),
        trailing: SegmentedButton<_Selection>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: _Selection.none, label: Text('—')),
            ButtonSegment(value: _Selection.playing, icon: Icon(Icons.check, size: 16)),
            ButtonSegment(value: _Selection.substitute, icon: Icon(Icons.swap_horiz, size: 16)),
          ],
          selected: {selection},
          onSelectionChanged: (selected) => onChanged(entry.id, selected.first),
        ),
      ),
    );
  }
}
