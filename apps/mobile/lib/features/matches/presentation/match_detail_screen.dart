import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../auth/application/session_controller.dart';
import '../../scoring/presentation/scoring_setup_screen.dart';
import '../application/matches_providers.dart';
import '../data/models/match.dart';
import 'widgets/match_card.dart';

/// Match detail — full fixture info plus the admin actions the spec calls
/// out: Edit (pushes MatchFormScreen pre-filled) and "Cancel match" (soft
/// `PATCH { status: 'cancelled' }`, confirmed first).
///
/// Deliberately does NOT expose the backend's hard `DELETE` endpoint — see
/// `MatchesController.remove`'s own doc comment: hard delete is
/// administrative cleanup only, separate from the spec's user-facing
/// "Cancel match" action. [MatchesRepository.delete] exists for API
/// completeness but nothing in this UI calls it.
class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({
    super.key,
    required this.tournamentId,
    required this.matchId,
    this.initialMatch,
  });

  final String tournamentId;
  final String matchId;

  /// Passed via go_router `extra` by callers that already have the match
  /// loaded (MatchesTab, TeamMatchesTab) — shown immediately while
  /// [matchDetailProvider] refetches in the background so the screen never
  /// has to show a bare spinner on a warm navigation. Null on a cold
  /// deep-link, in which case the screen waits on the fetch.
  final Match? initialMatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (tournamentId: tournamentId, matchId: matchId);
    final matchAsync = ref.watch(matchDetailProvider(key));
    final match = matchAsync.value ?? initialMatch;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match'),
        actions: [
          if (match != null)
            IconButton(
              tooltip: 'Edit match',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push(matchFormPath(tournamentId), extra: match).then((_) {
                ref.invalidate(matchDetailProvider(key));
              }),
            ),
        ],
      ),
      body: match != null
          ? _MatchDetailBody(tournamentId: tournamentId, match: match)
          : matchAsync.when(
              data: (_) => const SizedBox.shrink(),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(error is ApiException ? error.message : 'Failed to load match'),
              ),
            ),
    );
  }
}

class _MatchDetailBody extends ConsumerWidget {
  const _MatchDetailBody({required this.tournamentId, required this.match});

  final String tournamentId;
  final Match match;

  Future<void> _cancelMatch(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel match?'),
        content: const Text(
          'This marks the match as cancelled. It stays visible in the schedule for history — '
          'this does not delete it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep match'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel match'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return;
    try {
      await ref.read(matchesRepositoryProvider).cancel(organizationId, tournamentId, match.id);
      ref.invalidate(matchDetailProvider((tournamentId: tournamentId, matchId: match.id)));
      ref.invalidate(matchesListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Match cancelled')));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduledAt = match.scheduledAt?.toLocal();
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');
    final timeFormat = DateFormat.jm();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '${match.homeTeamName ?? 'TBD'} vs ${match.awayTeamName ?? 'TBD'}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            MatchStatusBadge(status: match.status),
          ],
        ),
        const SizedBox(height: 20),
        _DetailRow(
          icon: Icons.calendar_today,
          label: 'Date',
          value: scheduledAt != null ? dateFormat.format(scheduledAt) : 'TBD',
        ),
        _DetailRow(
          icon: Icons.access_time,
          label: 'Time',
          value: scheduledAt != null ? timeFormat.format(scheduledAt) : 'TBD',
        ),
        _DetailRow(
          icon: Icons.stadium_outlined,
          label: 'Venue',
          // Dual-field approach (see Match entity's doc comment): prefer
          // the free-text field when set, fall back to the server-resolved
          // display name for a structured venueId, then "TBD".
          value: match.venueName ?? match.venueDisplayName ?? 'TBD',
        ),
        _DetailRow(
          icon: Icons.sports_outlined,
          label: 'Umpire',
          value: match.umpireName ?? match.umpireOfficialDisplayName ?? 'TBD',
        ),
        _DetailRow(
          icon: Icons.edit_note_outlined,
          label: 'Scorer',
          value: match.scorerName ?? match.scorerOfficialDisplayName ?? 'TBD',
        ),
        if (match.matchRefereeOfficialDisplayName != null)
          _DetailRow(
            icon: Icons.gavel_outlined,
            label: 'Referee',
            value: match.matchRefereeOfficialDisplayName!,
          ),
        if (match.winnerTeamName != null)
          _DetailRow(
            icon: Icons.emoji_events_outlined,
            label: 'Winner',
            value: match.winnerTeamName!,
          ),
        if ((match.resultSummary ?? '').trim().isNotEmpty)
          _DetailRow(icon: Icons.summarize_outlined, label: 'Result', value: match.resultSummary!),
        if (match.status != MatchStatus.cancelled &&
            (match.homeTournamentTeamId != null || match.awayTournamentTeamId != null)) ...[
          const SizedBox(height: 24),
          Text('Playing XI', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (match.homeTournamentTeamId != null)
            OutlinedButton.icon(
              onPressed: () => context.push(
                lineupSelectionPath(tournamentId, match.id, match.homeTournamentTeamId!),
              ),
              icon: const Icon(Icons.checklist_outlined),
              label: Text('Set Playing XI — ${match.homeTeamName ?? 'Home team'}'),
            ),
          if (match.awayTournamentTeamId != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push(
                lineupSelectionPath(tournamentId, match.id, match.awayTournamentTeamId!),
              ),
              icon: const Icon(Icons.checklist_outlined),
              label: Text('Set Playing XI — ${match.awayTeamName ?? 'Away team'}'),
            ),
          ],
        ],
        if (match.status == MatchStatus.live || match.status == MatchStatus.completed) ...[
          const SizedBox(height: 24),
          Text('Match Center', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => context.push(matchCenterPath(tournamentId, match.id)),
              icon: const Icon(Icons.bar_chart_outlined),
              label: const Text('Scorecard & stats'),
            ),
          ),
        ],
        if (match.status == MatchStatus.scheduled || match.status == MatchStatus.live) ...[
          const SizedBox(height: 24),
          Text('Scoring', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (match.status == MatchStatus.live)
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () => context.push(liveScoringPath(tournamentId, match.id)),
                icon: const Icon(Icons.sports_cricket),
                label: const Text('Live score'),
              ),
            )
          else if (match.homeTournamentTeamId != null && match.awayTournamentTeamId != null)
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () => context.push(
                  scoringSetupPath(tournamentId, match.id),
                  extra: ScoringSetupArgs(match: match, isFirstInnings: true),
                ),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Start scoring'),
              ),
            )
          else
            Text(
              'Assign both home and away teams to enable scoring.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
        ],
        const SizedBox(height: 28),
        if (match.status != MatchStatus.cancelled)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => _cancelMatch(context, ref),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel match'),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }
}
