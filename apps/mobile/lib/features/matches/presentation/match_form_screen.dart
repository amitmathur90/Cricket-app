import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../officials/application/officials_providers.dart';
import '../../officials/data/models/official.dart';
import '../../venues/application/venues_providers.dart';
import '../application/matches_providers.dart';
import '../data/models/match.dart';

/// Create/Edit match — a single form covering every field the backend's
/// `CreateMatchDto`/`UpdateMatchDto` accept (home/away team, date+time,
/// venue, umpire, scorer), used for both creating a new match and editing
/// an existing one when [existing] is supplied. Same "one route, `extra`
/// decides create-vs-edit" pattern as CreateTournamentScreen.
///
/// The backend documents "Create match", "Assign teams", "Assign venue",
/// "Assign umpire/scorer" and "Reschedule" as conceptually distinct admin
/// actions, but they're all the same PATCH endpoint under the hood (see
/// UpdateMatchDto's doc comment) — so one form covering all of them, used
/// for both create and edit, is the pragmatic translation rather than five
/// separate mini-dialogs.
///
/// Venue/umpire/scorer/match referee each have TWO independent ways to set
/// them, mirroring the backend's dual-field approach (see Match entity's
/// doc comment): the original free-text fields (`venueName`/`umpireName`/
/// `scorerName`), and an optional dropdown picking a real `Venue`/`Official`
/// record (`venueId`/`umpireOfficialId`/`scorerOfficialId`/
/// `matchRefereeOfficialId`, sourced from the venues/officials list
/// endpoints). Neither clears the other — an admin can fill in one, the
/// other, both, or neither, exactly as the backend allows. Match referee has
/// no free-text legacy field (there never was one — see the entity doc
/// comment), so its dropdown is the only way to assign one.
class MatchFormScreen extends ConsumerStatefulWidget {
  const MatchFormScreen({super.key, required this.tournamentId, this.existing});

  final String tournamentId;

  /// When non-null, the form opens pre-filled with this match's data and
  /// submits via PATCH instead of POST.
  final Match? existing;

  @override
  ConsumerState<MatchFormScreen> createState() => _MatchFormScreenState();
}

class _MatchFormScreenState extends ConsumerState<MatchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _venueController = TextEditingController();
  final _umpireController = TextEditingController();
  final _scorerController = TextEditingController();

  String? _homeTournamentTeamId;
  String? _awayTournamentTeamId;
  DateTime? _scheduledAt;
  bool _submitting = false;

  // --- Structured (FK) alternative/supplement to the free-text fields
  // above — see this class's doc comment.
  String? _venueId;
  String? _umpireOfficialId;
  String? _scorerOfficialId;
  String? _matchRefereeOfficialId;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _homeTournamentTeamId = existing.homeTournamentTeamId;
      _awayTournamentTeamId = existing.awayTournamentTeamId;
      _scheduledAt = existing.scheduledAt?.toLocal();
      _venueController.text = existing.venueName ?? '';
      _umpireController.text = existing.umpireName ?? '';
      _scorerController.text = existing.scorerName ?? '';
      _venueId = existing.venueId;
      _umpireOfficialId = existing.umpireOfficialId;
      _scorerOfficialId = existing.scorerOfficialId;
      _matchRefereeOfficialId = existing.matchRefereeOfficialId;
    }
  }

  @override
  void dispose() {
    _venueController.dispose();
    _umpireController.dispose();
    _scorerController.dispose();
    super.dispose();
  }

  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _scheduledAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    if (_homeTournamentTeamId != null &&
        _awayTournamentTeamId != null &&
        _homeTournamentTeamId == _awayTournamentTeamId) {
      _showSnack('Home and away team must be different');
      return;
    }

    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(matchesRepositoryProvider);
      if (_isEditing) {
        final matchId = widget.existing!.id;
        await repo.update(
          organizationId,
          widget.tournamentId,
          matchId,
          homeTournamentTeamId: _homeTournamentTeamId,
          awayTournamentTeamId: _awayTournamentTeamId,
          scheduledAt: _scheduledAt,
          venueName: _emptyToNull(_venueController.text),
          umpireName: _emptyToNull(_umpireController.text),
          scorerName: _emptyToNull(_scorerController.text),
          venueId: _venueId,
          umpireOfficialId: _umpireOfficialId,
          scorerOfficialId: _scorerOfficialId,
          matchRefereeOfficialId: _matchRefereeOfficialId,
        );
        ref.invalidate(
          matchDetailProvider((tournamentId: widget.tournamentId, matchId: matchId)),
        );
      } else {
        await repo.create(
          organizationId,
          widget.tournamentId,
          homeTournamentTeamId: _homeTournamentTeamId,
          awayTournamentTeamId: _awayTournamentTeamId,
          scheduledAt: _scheduledAt,
          venueName: _emptyToNull(_venueController.text),
          umpireName: _emptyToNull(_umpireController.text),
          scorerName: _emptyToNull(_scorerController.text),
          venueId: _venueId,
          umpireOfficialId: _umpireOfficialId,
          scorerOfficialId: _scorerOfficialId,
          matchRefereeOfficialId: _matchRefereeOfficialId,
        );
      }
      ref.invalidate(matchesListProvider);
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(tournamentTeamsProvider(widget.tournamentId));
    final dateTimeFormat = DateFormat('EEE, MMM d, yyyy · h:mm a');

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit match' : 'Add match')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              teamsAsync.when(
                data: (teams) => _TeamFields(
                  teams: teams,
                  home: _homeTournamentTeamId,
                  away: _awayTournamentTeamId,
                  onHomeChanged: (v) => setState(() => _homeTournamentTeamId = v),
                  onAwayChanged: (v) => setState(() => _awayTournamentTeamId = v),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    error is ApiException ? error.message : 'Failed to load registered teams',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date & time (optional)'),
                subtitle: Text(
                  _scheduledAt == null ? 'Not set — TBD' : dateTimeFormat.format(_scheduledAt!),
                ),
                trailing: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_scheduledAt != null)
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _scheduledAt = null),
                      ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
                onTap: _pickDateTime,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _venueController,
                decoration: const InputDecoration(labelText: 'Venue (optional)'),
              ),
              const SizedBox(height: 8),
              _VenuePickerField(
                value: _venueId,
                onChanged: (v) => setState(() => _venueId = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _umpireController,
                decoration: const InputDecoration(labelText: 'Umpire (optional)'),
              ),
              const SizedBox(height: 8),
              _OfficialPickerField(
                role: OfficialRole.umpire,
                label: 'Or select an umpire (optional)',
                value: _umpireOfficialId,
                onChanged: (v) => setState(() => _umpireOfficialId = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _scorerController,
                decoration: const InputDecoration(labelText: 'Scorer (optional)'),
              ),
              const SizedBox(height: 8),
              _OfficialPickerField(
                role: OfficialRole.scorer,
                label: 'Or select a scorer (optional)',
                value: _scorerOfficialId,
                onChanged: (v) => setState(() => _scorerOfficialId = v),
              ),
              const SizedBox(height: 16),
              _OfficialPickerField(
                role: OfficialRole.matchReferee,
                label: 'Match referee (optional)',
                value: _matchRefereeOfficialId,
                onChanged: (v) => setState(() => _matchRefereeOfficialId = v),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Create match'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamFields extends StatelessWidget {
  const _TeamFields({
    required this.teams,
    required this.home,
    required this.away,
    required this.onHomeChanged,
    required this.onAwayChanged,
  });

  final List<TournamentTeamOption> teams;
  final String? home;
  final String? away;
  final ValueChanged<String?> onHomeChanged;
  final ValueChanged<String?> onAwayChanged;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          "No teams are resolvable for this tournament yet (there's no backend endpoint to list "
          "a tournament's registered teams directly — this app reads them from the tournament's "
          "most recent auction session report, so at least one auction session needs to exist "
          'first). This match will be created as TBD vs TBD; venue/umpire/scorer/date can still '
          'be set below.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    // Guard against a stale selection whose id is no longer in the
    // resolved list (e.g. edited from a different auction session's data).
    final ids = teams.map((t) => t.tournamentTeamId).toSet();
    final homeValue = (home != null && ids.contains(home)) ? home : null;
    final awayValue = (away != null && ids.contains(away)) ? away : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: homeValue,
          decoration: const InputDecoration(labelText: 'Home team'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('TBD')),
            for (final team in teams)
              DropdownMenuItem<String?>(value: team.tournamentTeamId, child: Text(team.teamName)),
          ],
          onChanged: onHomeChanged,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          initialValue: awayValue,
          decoration: const InputDecoration(labelText: 'Away team'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('TBD')),
            for (final team in teams)
              DropdownMenuItem<String?>(value: team.tournamentTeamId, child: Text(team.teamName)),
          ],
          onChanged: onAwayChanged,
        ),
      ],
    );
  }
}

/// The structured "select a real venue" half of the venue dual-field
/// approach (see MatchFormScreen's doc comment) — a dropdown sourced from
/// [venuesListProvider], independent of the free-text venue field above it.
/// `null` (the default "None" item) means "don't set/clear `venueId`" —
/// unrelated to whether the free-text `venueName` is set.
class _VenuePickerField extends ConsumerWidget {
  const _VenuePickerField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venuesAsync = ref.watch(venuesListProvider);
    return venuesAsync.when(
      data: (venues) {
        // Guard against a stale selection whose id is no longer in the
        // resolved list, same defensive pattern as _TeamFields above.
        final ids = venues.map((v) => v.id).toSet();
        final selected = (value != null && ids.contains(value)) ? value : null;
        return DropdownButtonFormField<String?>(
          initialValue: selected,
          decoration: const InputDecoration(labelText: 'Or select an existing venue (optional)'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('None')),
            for (final venue in venues)
              DropdownMenuItem<String?>(value: venue.id, child: Text(venue.name)),
          ],
          onChanged: onChanged,
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (error, stackTrace) => Text(
        error is ApiException ? error.message : 'Failed to load venues',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

/// The structured "select a real official" half of the umpire/scorer/match
/// referee dual-field approach (see MatchFormScreen's doc comment) — a
/// dropdown sourced from [officialsListProvider] pre-filtered to [role], so
/// e.g. the umpire picker only ever lists officials with `role: umpire`.
/// `null` (the default "None" item) means "don't set/clear this FK" —
/// unrelated to whether a corresponding free-text field (where one exists)
/// is set.
class _OfficialPickerField extends ConsumerWidget {
  const _OfficialPickerField({
    required this.role,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final OfficialRole role;
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officialsAsync = ref.watch(officialsListProvider(role));
    return officialsAsync.when(
      data: (officials) {
        final ids = officials.map((o) => o.id).toSet();
        final selected = (value != null && ids.contains(value)) ? value : null;
        return DropdownButtonFormField<String?>(
          initialValue: selected,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('None')),
            for (final official in officials)
              DropdownMenuItem<String?>(value: official.id, child: Text(official.fullName)),
          ],
          onChanged: onChanged,
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (error, stackTrace) => Text(
        error is ApiException ? error.message : 'Failed to load officials',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
