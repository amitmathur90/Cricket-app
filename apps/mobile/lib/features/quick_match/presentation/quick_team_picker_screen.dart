import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../auth/application/session_controller.dart';
import '../../matches/application/matches_providers.dart';
import '../../teams/application/teams_providers.dart';
import '../../teams/presentation/widgets/add_team_dialog.dart';

/// "Select playing teams" -> team slot picker: pick one of the org's
/// existing Quick Match teams, or create a brand-new one (which then opens
/// straight into [QuickTeamRosterScreen] to add players, since a new team
/// has nobody on it yet). Pops with the chosen [TournamentTeamOption], or
/// null if the user backs out.
class QuickTeamPickerScreen extends ConsumerWidget {
  const QuickTeamPickerScreen({super.key, required this.tournamentId, this.excludeTournamentTeamId});

  final String tournamentId;

  /// The other slot's already-picked team, if any — excluded from this
  /// list so the same team can't be selected for both sides.
  final String? excludeTournamentTeamId;

  Future<void> _createTeam(BuildContext context, WidgetRef ref) async {
    final result = await showAddTeamDialog(context);
    if (result == null || !context.mounted) return;

    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return;

    try {
      final team = await ref.read(teamsRepositoryProvider).create(
            organizationId,
            name: result.name,
            shortCode: result.shortCode,
          );
      final tournamentTeamId =
          await ref.read(teamsRepositoryProvider).registerToTournament(organizationId, team.id, tournamentId);
      ref.invalidate(tournamentTeamsProvider(tournamentId));

      if (!context.mounted) return;
      await context.push(
        quickMatchRosterPath(tournamentId, team.id, tournamentTeamId),
        extra: team.name,
      );
      if (!context.mounted) return;
      context.pop((tournamentTeamId: tournamentTeamId, teamId: team.id, teamName: team.name));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(tournamentTeamsProvider(tournamentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Select team')),
      body: teamsAsync.when(
        data: (teams) {
          final selectable = teams.where((t) => t.tournamentTeamId != excludeTournamentTeamId).toList();
          return ListView(
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.add)),
                title: const Text('Create new team'),
                onTap: () => _createTeam(context, ref),
              ),
              if (selectable.isNotEmpty) const Divider(height: 1),
              for (final team in selectable)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.shield)),
                  title: Text(team.teamName),
                  onTap: () => context.pop(team),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load teams'),
        ),
      ),
    );
  }
}
