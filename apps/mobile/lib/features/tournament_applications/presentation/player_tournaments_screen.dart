import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../tournaments/application/tournaments_providers.dart';
import '../../tournaments/data/models/tournament.dart';
import '../application/tournament_applications_providers.dart';
import '../data/models/tournament_application.dart';
import 'widgets/apply_to_tournament_dialog.dart';

/// Tournament browse/apply screen for a `player`-role user — lists
/// tournaments in the active org (reusing TournamentsRepository.list, same
/// as AdminHomeScreen; that endpoint has no `@Roles()` guard so it's
/// readable by any org member) with the caller's application status for
/// each, cross-referenced against `GET .../applications/mine`, and an
/// "Apply" action when they haven't applied yet.
///
/// Was `PlayerHomeScreen` (the entire `/player` route) before the
/// bottom-nav redesign — see `PlayerShellScreen`
/// (features/player_dashboard) for the new home shell. This screen's
/// functionality is unchanged, just re-homed: it's now a sub-screen pushed
/// from the Home tab's "Tournaments" section (see [playerTournamentsPath]
/// in app_router.dart) rather than the entire player-facing app. Sign-out
/// moved to the Profile tab (`PlayerProfileTab`), so the app-bar logout
/// action that used to live here is gone.
class PlayerTournamentsScreen extends ConsumerWidget {
  const PlayerTournamentsScreen({super.key});

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    String organizationId,
    Tournament tournament,
  ) async {
    final result = await showApplyToTournamentDialog(
      context,
      organizationId: organizationId,
      tournamentName: tournament.name,
    );
    if (result == null) return;
    try {
      await ref.read(tournamentApplicationsRepositoryProvider).apply(
            organizationId,
            tournament.id,
            fullName: result.fullName,
            role: result.role,
            ageCategory: result.ageCategory,
            previousStatsNotes: result.previousStatsNotes,
            photoUrl: result.photoUrl,
            idDocumentUrl: result.idDocumentUrl,
            battingStyle: result.battingStyle,
            bowlingStyle: result.bowlingStyle,
            basePrice: result.basePrice,
          );
      ref.invalidate(myApplicationsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Applied to ${tournament.name}')));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final organizationId = session.activeOrgId;
    final tournamentsAsync = ref.watch(tournamentsListProvider);
    final myApplicationsAsync = ref.watch(myApplicationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(tournamentsListProvider.future),
            ref.refresh(myApplicationsProvider.future),
          ]);
        },
        child: tournamentsAsync.when(
          data: (tournaments) {
            if (tournaments.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No tournaments available yet.')),
                ],
              );
            }
            final applicationsByTournamentId = <String, TournamentApplication>{
              for (final app in myApplicationsAsync.asData?.value ?? const <TournamentApplication>[])
                app.tournamentId: app,
            };
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tournaments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final tournament = tournaments[index];
                final application = applicationsByTournamentId[tournament.id];
                return _TournamentTile(
                  tournament: tournament,
                  application: application,
                  onApply: organizationId == null
                      ? null
                      : () => _apply(context, ref, organizationId, tournament),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(
                child: Text(
                  error is ApiException ? error.message : 'Failed to load tournaments',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TournamentTile extends StatelessWidget {
  const _TournamentTile({required this.tournament, required this.application, this.onApply});

  final Tournament tournament;
  final TournamentApplication? application;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(tournament.name),
        subtitle: Text(
          '${tournament.format.label} · ${tournament.startDate} to ${tournament.endDate} · '
          '${tournament.status}',
        ),
        trailing: application == null
            ? (onApply == null
                ? null
                : OutlinedButton(onPressed: onApply, child: const Text('Apply')))
            : _ApplicationStatusChip(status: application!.status),
      ),
    );
  }
}

class _ApplicationStatusChip extends StatelessWidget {
  const _ApplicationStatusChip({required this.status});

  final TournamentApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      TournamentApplicationStatus.approved => (Colors.green, Icons.check_circle),
      TournamentApplicationStatus.rejected => (Colors.red, Icons.cancel),
      TournamentApplicationStatus.pending => (Colors.orange, Icons.hourglass_top),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(status.label),
    );
  }
}
