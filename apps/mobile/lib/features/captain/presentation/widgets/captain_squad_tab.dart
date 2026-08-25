import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../players/data/models/player.dart';
import '../../../teams/application/teams_providers.dart';
import '../../../teams/data/models/roster_entry.dart';
import '../../../teams/data/models/team.dart';
import '../../../tournaments/data/models/tournament.dart';
import '../../application/captain_providers.dart';

/// Squad tab for the Captain App — this team's roster, read-only.
///
/// Reuses the same data (`rosterProvider`) and visual pattern
/// (`TeamSquadTab`/`TeamCaptainTab` in features/teams/presentation/widgets)
/// as the admin-side Team detail screen, but deliberately does NOT reuse
/// those widgets' per-row popup menu (make captain/vice-captain, jersey
/// number, wicketkeeper): `TeamsController.updateRosterEntry` is
/// `@Roles(ORG_ADMIN, TOURNAMENT_ADMIN)`-only server-side, so a `team_owner`
/// calling it would just get a 403 — those edit actions genuinely aren't
/// this role's to use, not merely hidden by convention. "Check player
/// availability" is satisfied by the existing read-only
/// `isAvailableFor*` badges, same as `TeamSquadTab`'s.
///
/// A team can be registered to more than one tournament at once (roster is
/// scoped per tournament-team, not per team — see
/// `captainTeamTournamentsProvider`'s doc comment), so this shows a
/// tournament picker when there's more than one, defaulting to
/// [pickPrimaryTournament]'s pick.
class CaptainSquadTab extends ConsumerStatefulWidget {
  const CaptainSquadTab({super.key, required this.team});

  final Team team;

  @override
  ConsumerState<CaptainSquadTab> createState() => _CaptainSquadTabState();
}

class _CaptainSquadTabState extends ConsumerState<CaptainSquadTab> {
  String? _selectedTournamentId;

  @override
  Widget build(BuildContext context) {
    final tournamentsAsync = ref.watch(captainTeamTournamentsProvider(widget.team.id));

    return tournamentsAsync.when(
      data: (tournaments) {
        if (tournaments.isEmpty) {
          return _EmptyState(
            message: '${widget.team.name} isn\'t registered to any tournament yet.',
          );
        }
        final selected = tournaments.firstWhere(
          (t) => t.id == _selectedTournamentId,
          orElse: () => pickPrimaryTournament(tournaments)!,
        );
        return Column(
          children: [
            if (tournaments.length > 1)
              _TournamentPicker(
                tournaments: tournaments,
                selectedId: selected.id,
                onChanged: (id) => setState(() => _selectedTournamentId = id),
              ),
            Expanded(child: _RosterView(team: widget.team, tournamentId: selected.id)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(error is ApiException ? error.message : 'Failed to load tournaments'),
      ),
    );
  }
}

class _TournamentPicker extends StatelessWidget {
  const _TournamentPicker({
    required this.tournaments,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Tournament> tournaments;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<String>(
        initialValue: selectedId,
        decoration: const InputDecoration(
          labelText: 'Tournament',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final tournament in tournaments)
            DropdownMenuItem(value: tournament.id, child: Text(tournament.name)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _RosterView extends ConsumerWidget {
  const _RosterView({required this.team, required this.tournamentId});

  final Team team;
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rosterAsync = ref.watch(rosterProvider((teamId: team.id, tournamentId: tournamentId)));

    return rosterAsync.when(
      data: (roster) {
        if (roster.isEmpty) {
          return _EmptyState(message: '${team.name} has no roster entries in this tournament yet.');
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: roster.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) => _RosterTile(entry: roster[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(error is ApiException ? error.message : 'Failed to load roster'),
      ),
    );
  }
}

class _RosterTile extends StatelessWidget {
  const _RosterTile({required this.entry});

  final RosterEntry entry;

  @override
  Widget build(BuildContext context) {
    final player = entry.player;
    return ListTile(
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
            _Badge(label: '#${entry.jerseyNumber}', color: Colors.blueGrey),
          ],
          if (entry.isCaptain) ...[
            const SizedBox(width: 6),
            const _Badge(label: 'C', color: Colors.amber),
          ],
          if (entry.isViceCaptain) ...[
            const SizedBox(width: 6),
            const _Badge(label: 'VC', color: Colors.teal),
          ],
          if (entry.isWicketkeeper) ...[
            const SizedBox(width: 6),
            const _Badge(label: 'WK', color: Colors.deepPurple),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          Flexible(child: Text(player.role.label, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          _AvailabilityBadges(player: player),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

/// "Check player availability" — read-only display of the same
/// `isAvailableFor{Tournaments,Matches,Practice}` flags `TeamSquadTab`
/// already surfaces; the toggle-setting UI itself stays admin-side
/// (PlayerListTab), unchanged by this feature.
class _AvailabilityBadges extends StatelessWidget {
  const _AvailabilityBadges({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    if (player.isAvailable) {
      return const SizedBox.shrink();
    }
    return const Tooltip(
      message: 'Marked unavailable',
      child: Icon(Icons.event_busy, size: 16, color: Colors.redAccent),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).disabledColor),
        ),
      ),
    );
  }
}
