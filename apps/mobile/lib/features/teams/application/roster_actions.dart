import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import 'teams_providers.dart';

/// Shared roster-entry mutation helper for the Squad and Captain tabs. Both
/// call `TeamsRepository.updateRosterEntry` and both need the same
/// invalidate-on-success / snackbar-on-error handling, so it lives here once
/// instead of being duplicated in each tab widget.
class RosterActions {
  RosterActions(
    this.ref, {
    required this.organizationId,
    required this.teamId,
    required this.tournamentId,
  });

  final WidgetRef ref;
  final String organizationId;
  final String teamId;
  final String tournamentId;

  /// Returns true on success (caller may want to show a confirmation), false
  /// if the call failed (a snackbar with the server's error message has
  /// already been shown).
  Future<bool> update(
    BuildContext context,
    String teamPlayerId, {
    bool? isCaptain,
    bool? isViceCaptain,
    int? jerseyNumber,
    bool? isWicketkeeper,
  }) async {
    try {
      await ref.read(teamsRepositoryProvider).updateRosterEntry(
            organizationId,
            teamId,
            tournamentId,
            teamPlayerId,
            isCaptain: isCaptain,
            isViceCaptain: isViceCaptain,
            jerseyNumber: jerseyNumber,
            isWicketkeeper: isWicketkeeper,
          );
      ref.invalidate(rosterProvider((teamId: teamId, tournamentId: tournamentId)));
      return true;
    } on ApiException catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
      return false;
    }
  }
}
