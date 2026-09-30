import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../auth/application/session_controller.dart';
import '../../organizations/application/organizations_providers.dart';
import '../../tournament_applications/application/tournament_applications_providers.dart';
import '../../tournament_applications/presentation/widgets/apply_to_tournament_dialog.dart';
import '../../tournaments/data/models/tournament.dart' show TournamentFormatX;
import '../application/public_providers.dart';

/// `GET public/organizations/:organizationId/tournaments/:tournamentId`
/// (basic info) plus jump-in tiles for this tournament's Teams/Fixtures &
/// Results/Points Table — the public-section equivalent of
/// `TournamentDetailScreen`'s tab bar, but as separate pushed screens rather
/// than tabs (this section has far fewer per-tournament sub-views than the
/// admin one — no Players/Applications/Auction/Finance tabs, all of which
/// are admin-only concerns).
///
/// Also the entry point for "Register as Player" — reachable whether or not
/// the caller already belongs to this tournament's organization (this
/// screen itself is reachable logged-out too; see `_isPublicFanRoute` in
/// app_router.dart). Registering is a 3-step hand-off across existing,
/// otherwise-unchanged pieces: join the org via `joinViaTournament` (creates
/// an ACTIVE player-role membership if the caller doesn't have one yet;
/// idempotent if they do), `SessionController.selectOrg` to mint a token
/// actually scoped to that org (needed before the org-scoped upload/apply
/// endpoints below will accept the caller), then the *existing*
/// `showApplyToTournamentDialog` + `TournamentApplicationsRepository.apply`
/// flow already used by `PlayerTournamentsScreen` for in-org applications.
class PublicTournamentDetailScreen extends ConsumerWidget {
  const PublicTournamentDetailScreen({
    super.key,
    required this.organizationId,
    required this.tournamentId,
  });

  final String organizationId;
  final String tournamentId;

  Future<void> _registerAsPlayer(
    BuildContext context,
    WidgetRef ref,
    String tournamentName,
  ) async {
    final session = ref.read(sessionControllerProvider);
    if (session.status != AuthStatus.authenticated) {
      context.push(loginPath);
      return;
    }

    try {
      await ref.read(organizationsRepositoryProvider).joinViaTournament(tournamentId);
      await ref.read(sessionControllerProvider.notifier).selectOrg(organizationId);
      final afterSelect = ref.read(sessionControllerProvider);
      if (afterSelect.activeOrgId != organizationId) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(afterSelect.errorMessage ?? 'Could not register for this tournament'),
          ));
        return;
      }
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    if (!context.mounted) return;
    final result = await showApplyToTournamentDialog(
      context,
      organizationId: organizationId,
      tournamentName: tournamentName,
    );
    if (result == null) return;

    try {
      await ref.read(tournamentApplicationsRepositoryProvider).apply(
            organizationId,
            tournamentId,
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Applied to $tournamentName')));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = (organizationId: organizationId, tournamentId: tournamentId);
    final tournamentAsync = ref.watch(publicTournamentProvider(scope));

    return Scaffold(
      appBar: AppBar(title: const Text('Tournament')),
      body: tournamentAsync.when(
        data: (tournament) {
          final start = DateTime.tryParse(tournament.startDate);
          final end = DateTime.tryParse(tournament.endDate);
          final dateFormat = DateFormat.yMMMd();
          final dateRange = (start != null && end != null)
              ? '${dateFormat.format(start)} – ${dateFormat.format(end)}'
              : '${tournament.startDate} to ${tournament.endDate}';

          return RefreshIndicator(
            onRefresh: () => ref.refresh(publicTournamentProvider(scope).future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: tournament.logoUrl != null
                          ? NetworkImage(Env.mediaUrl(tournament.logoUrl!))
                          : null,
                      child: tournament.logoUrl == null ? const Icon(Icons.emoji_events, size: 28) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tournament.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text('${tournament.format.label} · $dateRange'),
                        ],
                      ),
                    ),
                  ],
                ),
                if ((tournament.location ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 6),
                      Expanded(child: Text(tournament.location!)),
                    ],
                  ),
                ],
                if ((tournament.organizerName ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Organized by ${tournament.organizerName}')),
                    ],
                  ),
                ],
                if ((tournament.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(tournament.description!),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _registerAsPlayer(context, ref, tournament.name),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Register as Player'),
                ),
                const SizedBox(height: 16),
                _NavTile(
                  icon: Icons.groups_outlined,
                  label: 'Teams',
                  onTap: () => context.push(publicTeamsPath(organizationId, tournamentId)),
                ),
                _NavTile(
                  icon: Icons.sports_outlined,
                  label: 'Fixtures & Results',
                  onTap: () => context.push(publicFixturesPath(organizationId, tournamentId)),
                ),
                _NavTile(
                  icon: Icons.leaderboard_outlined,
                  label: 'Points Table',
                  onTap: () => context.push(publicPointsTablePath(organizationId, tournamentId)),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load tournament'),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
