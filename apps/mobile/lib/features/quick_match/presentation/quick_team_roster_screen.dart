import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../players/application/players_providers.dart';
import '../../players/data/models/player.dart';
import '../../teams/application/teams_providers.dart';

/// Roster-building screen for a freshly created (or selected) Quick Match
/// team — "Add via phone number" (find-or-create a player by phone, see
/// PlayersRepository.quickAddByPhone) or "Add existing player" (pick from
/// the org's player list). Reached right after creating a team in
/// QuickTeamPickerScreen; "Done" just pops back — there's no roster-size
/// requirement (MatchLineupService deliberately doesn't enforce exactly 11,
/// see lineup_selection_screen.dart's same note), so any number of players
/// added here is fine, including zero (the Playing XI screen can still add
/// more org players to the roster later if needed).
class QuickTeamRosterScreen extends ConsumerWidget {
  const QuickTeamRosterScreen({
    super.key,
    required this.tournamentId,
    required this.teamId,
    required this.tournamentTeamId,
    required this.teamName,
  });

  final String tournamentId;
  final String teamId;
  final String tournamentTeamId;
  final String teamName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rosterKey = (teamId: teamId, tournamentId: tournamentId);
    final rosterAsync = ref.watch(rosterProvider(rosterKey));

    return Scaffold(
      appBar: AppBar(
        title: Text(teamName),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Done'),
          ),
        ],
      ),
      body: rosterAsync.when(
        data: (roster) => roster.isEmpty
            ? const Center(child: Text('No players added yet'))
            : ListView.builder(
                itemCount: roster.length,
                itemBuilder: (context, index) {
                  final entry = roster[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(entry.player.fullName),
                    subtitle: Text(entry.player.role.label),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load roster'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPlayerSheet(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Add player'),
      ),
    );
  }

  Future<void> _showAddPlayerSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddPlayerSheet(
        tournamentId: tournamentId,
        teamId: teamId,
        tournamentTeamId: tournamentTeamId,
      ),
    );
  }
}

class _AddPlayerSheet extends ConsumerStatefulWidget {
  const _AddPlayerSheet({
    required this.tournamentId,
    required this.teamId,
    required this.tournamentTeamId,
  });

  final String tournamentId;
  final String teamId;
  final String tournamentTeamId;

  @override
  ConsumerState<_AddPlayerSheet> createState() => _AddPlayerSheetState();
}

class _AddPlayerSheetState extends ConsumerState<_AddPlayerSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  RosterKey get _rosterKey => (teamId: widget.teamId, tournamentId: widget.tournamentId);

  Future<void> _addByPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter a mobile number');
      return;
    }
    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(playersRepositoryProvider).quickAddByPhone(
            organizationId,
            widget.tournamentTeamId,
            phone: phone,
            fullName: _nameController.text,
          );
      ref.invalidate(rosterProvider(_rosterKey));
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addExisting(String playerId) async {
    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(playersRepositoryProvider).addToRoster(organizationId, playerId, widget.tournamentTeamId);
      ref.invalidate(rosterProvider(_rosterKey));
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(rosterProvider(_rosterKey));
    final playersAsync = ref.watch(playersListProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Add via phone number'),
                  Tab(text: 'Add existing player'),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _phoneController,
                            decoration: const InputDecoration(labelText: 'Mobile number'),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Name (optional)'),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy ? null : _addByPhone,
                            child: _busy
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Add player'),
                          ),
                        ],
                      ),
                    ),
                    playersAsync.when(
                      data: (players) {
                        final rosterPlayerIds = rosterAsync.value?.map((r) => r.playerId).toSet() ?? {};
                        final available = players.where((p) => !rosterPlayerIds.contains(p.id)).toList();
                        if (available.isEmpty) {
                          return const Center(child: Text('No other org players available'));
                        }
                        return ListView.builder(
                          itemCount: available.length,
                          itemBuilder: (context, index) {
                            final player = available[index];
                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(player.fullName),
                              subtitle: Text(player.role.label),
                              trailing: _busy ? null : const Icon(Icons.add),
                              onTap: _busy ? null : () => _addExisting(player.id),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stackTrace) => Center(
                        child: Text(error is ApiException ? error.message : 'Failed to load players'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
