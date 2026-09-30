import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../auction/presentation/widgets/player_purchase_history_dialog.dart';
import '../../application/players_providers.dart';
import '../../data/models/player.dart';

/// Lists the caller's org-level players (not a tournament-team roster —
/// see players_providers.dart) with a button to open the 5-step player
/// registration wizard (`CreatePlayerScreen`), plus per-player
/// verification/rating/availability actions. The backend enforces who's
/// actually allowed to call these (org_admin/tournament_admin only) — this
/// M1 UI doesn't hide the actions per-role, it just surfaces whatever error
/// the API returns if the caller isn't permitted.
class PlayerListTab extends ConsumerWidget {
  const PlayerListTab({super.key, required this.organizationId});

  final String organizationId;

  Future<void> _showError(BuildContext context, Object error) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error is ApiException ? error.message : 'Something went wrong')));
  }

  /// Prompts for an optional note (the backend's `VerifyPlayerDto.note`
  /// accepts one on any transition) then calls `PATCH .../verification`.
  /// [status] must be a legal next status for [player]'s current
  /// verification status per the 4-stage flow — the popup menu's
  /// `itemBuilder` below only ever offers a legal next status (mirroring
  /// `PlayersService.ALLOWED_VERIFICATION_TRANSITIONS` server-side, which
  /// would reject an illegal transition anyway).
  Future<void> _setVerification(
    BuildContext context,
    WidgetRef ref,
    Player player,
    PlayerVerificationStatus status,
  ) async {
    final actionLabel = switch (status) {
      PlayerVerificationStatus.verified => 'Verify player',
      PlayerVerificationStatus.approved => 'Approve player',
      PlayerVerificationStatus.rejected => 'Reject player',
      PlayerVerificationStatus.pending => 'Update player', // unreachable: never a valid target
    };
    final note = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(actionLabel),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
    if (note == null) return; // dialog cancelled
    try {
      await ref
          .read(playersRepositoryProvider)
          .setVerification(organizationId, player.id, status: status, note: note);
      ref.invalidate(playersListProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      await _showError(context, e);
    }
  }

  Future<void> _setRating(BuildContext context, WidgetRef ref, Player player) async {
    final controller = TextEditingController(text: player.rating ?? '');
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate player'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Rating (0-5)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              Navigator.of(context).pop(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result < 0 || result > 5) return;
    try {
      await ref.read(playersRepositoryProvider).setRating(organizationId, player.id, result);
      ref.invalidate(playersListProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      await _showError(context, e);
    }
  }

  Future<void> _toggleAvailability(BuildContext context, WidgetRef ref, Player player) async {
    String? reason;
    if (player.isAvailable) {
      reason = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Mark unavailable'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Mark unavailable'),
              ),
            ],
          );
        },
      );
      if (reason == null) return; // dialog cancelled
    }
    try {
      await ref.read(playersRepositoryProvider).setAvailability(
            organizationId,
            player.id,
            isAvailable: !player.isAvailable,
            unavailabilityReason: reason,
          );
      ref.invalidate(playersListProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      await _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Expanded(
                child: Text('Org-level players', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push(createPlayerPath),
                icon: const Icon(Icons.add),
                label: const Text('Add player'),
              ),
            ],
          ),
        ),
        Expanded(
          child: playersAsync.when(
            data: (players) {
              if (players.isEmpty) {
                return const Center(child: Text('No players yet.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: players.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final player = players[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: player.photoUrl != null
                          ? NetworkImage(Env.mediaUrl(player.photoUrl!))
                          : null,
                      child: player.photoUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Row(
                      children: [
                        Flexible(child: Text(player.fullName, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        _VerificationChip(status: player.verificationStatus),
                        if (!player.isAvailable) ...[
                          const SizedBox(width: 4),
                          const Tooltip(message: 'Unavailable', child: Icon(Icons.event_busy, size: 16)),
                        ],
                      ],
                    ),
                    subtitle: Text([
                      player.role.label,
                      if (player.ageCategory != null) player.ageCategory!,
                      if (player.battingStyle != null) player.battingStyle!,
                      if (player.bowlingStyle != null) player.bowlingStyle!,
                      if (player.rating != null) '★ ${player.rating}',
                    ].join(' · ')),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        switch (action) {
                          case 'verify':
                            _setVerification(context, ref, player, PlayerVerificationStatus.verified);
                          case 'approve':
                            _setVerification(context, ref, player, PlayerVerificationStatus.approved);
                          case 'reject':
                            _setVerification(context, ref, player, PlayerVerificationStatus.rejected);
                          case 'rate':
                            _setRating(context, ref, player);
                          case 'availability':
                            _toggleAvailability(context, ref, player);
                          case 'history':
                            showPlayerPurchaseHistoryDialog(
                              context,
                              playerId: player.id,
                              playerName: player.fullName,
                            );
                          case 'statistics':
                            context.push(playerStatisticsPath(player.id), extra: player);
                        }
                      },
                      itemBuilder: (context) => [
                        // Only offer the legal next verification transitions
                        // for the player's CURRENT status (mirrors
                        // PlayersService.ALLOWED_VERIFICATION_TRANSITIONS):
                        // pending -> verified/rejected, verified ->
                        // approved/rejected, approved/rejected are terminal.
                        ...switch (player.verificationStatus) {
                          PlayerVerificationStatus.pending => const [
                              PopupMenuItem(value: 'verify', child: Text('Verify')),
                              PopupMenuItem(value: 'reject', child: Text('Reject')),
                            ],
                          PlayerVerificationStatus.verified => const [
                              PopupMenuItem(value: 'approve', child: Text('Approve')),
                              PopupMenuItem(value: 'reject', child: Text('Reject')),
                            ],
                          PlayerVerificationStatus.approved ||
                          PlayerVerificationStatus.rejected =>
                            const <PopupMenuEntry<String>>[],
                          // Defensive fallback — every real
                          // PlayerVerificationStatus value is already
                          // handled above; this only exists so the switch
                          // expression is provably exhaustive to the compiler.
                          _ => const <PopupMenuEntry<String>>[],
                        },
                        const PopupMenuItem(value: 'rate', child: Text('Set rating')),
                        PopupMenuItem(
                          value: 'availability',
                          child: Text(player.isAvailable ? 'Mark unavailable' : 'Mark available'),
                        ),
                        const PopupMenuItem(value: 'history', child: Text('Auction history')),
                        const PopupMenuItem(value: 'statistics', child: Text('View statistics')),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text(error is ApiException ? error.message : 'Failed to load players'),
            ),
          ),
        ),
      ],
    );
  }
}

class _VerificationChip extends StatelessWidget {
  const _VerificationChip({required this.status});

  final PlayerVerificationStatus status;

  @override
  Widget build(BuildContext context) {
    // verified = "docs checked but not fully cleared" (blue), approved =
    // "fully cleared" (green) — kept visually distinct per the 4-stage flow.
    final (color, icon) = switch (status) {
      PlayerVerificationStatus.pending => (Colors.orange, Icons.hourglass_top),
      PlayerVerificationStatus.verified => (Colors.blue, Icons.verified_outlined),
      PlayerVerificationStatus.approved => (Colors.green, Icons.check_circle),
      PlayerVerificationStatus.rejected => (Colors.red, Icons.cancel),
    };
    return Tooltip(
      message: status.label,
      child: Icon(icon, size: 16, color: color),
    );
  }
}
