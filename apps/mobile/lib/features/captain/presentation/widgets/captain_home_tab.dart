import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/application/session_controller.dart';
import '../../../matches/data/models/match.dart';
import '../../../matches/presentation/widgets/match_card.dart';
import '../../../practice/application/practice_providers.dart';
import '../../../practice/data/models/practice_session.dart';
import '../../../teams/data/models/team.dart';
import '../../application/captain_providers.dart';

/// Home tab for the Captain App — greeting, next match summary ("View
/// opponent"/"View match details" is satisfied by tapping through to the
/// existing match detail/Match Center screens), next practice summary, and
/// quick links into the Squad/Matches tabs. [onOpenSquad]/[onOpenMatches]
/// switch this screen's own bottom-nav tab rather than pushing a new route,
/// same "quick link jumps to a sibling tab" pattern the rest of this app
/// doesn't otherwise need since only this screen has a bottom nav.
class CaptainHomeTab extends ConsumerWidget {
  const CaptainHomeTab({
    super.key,
    required this.team,
    required this.onOpenSquad,
    required this.onOpenMatches,
  });

  final Team team;
  final VoidCallback onOpenSquad;
  final VoidCallback onOpenMatches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final displayName = session.user?.fullName ?? session.user?.email ?? 'Captain';

    final matchesKey = (teamId: team.id, teamName: team.name);
    final matchesAsync = ref.watch(captainMatchesProvider(matchesKey));

    final practiceKey = (teamId: team.id, status: null);
    final practiceAsync = ref.watch(practiceSessionsListProvider(practiceKey));

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        ref.refresh(captainMatchesProvider(matchesKey).future),
        ref.refresh(practiceSessionsListProvider(practiceKey).future),
      ]),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Welcome, $displayName',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            team.name,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 20),
          Text('Next match', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          matchesAsync.when(
            data: (matches) {
              final now = DateTime.now();
              final upcoming = matches
                  .where((m) =>
                      m.status != MatchStatus.cancelled &&
                      (m.scheduledAt == null || !m.scheduledAt!.isBefore(now)))
                  .toList();
              if (upcoming.isEmpty) {
                return _EmptyCard(message: 'No upcoming matches scheduled.');
              }
              final next = upcoming.first;
              return MatchCard(
                match: next,
                onTap: () =>
                    context.push(matchDetailPath(next.tournamentId, next.id), extra: next),
              );
            },
            loading: () => const _LoadingCard(),
            error: (error, stackTrace) => _ErrorCard(
              message: error is ApiException ? error.message : 'Failed to load matches',
            ),
          ),
          const SizedBox(height: 20),
          Text('Next practice', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          practiceAsync.when(
            data: (sessions) {
              final now = DateTime.now();
              final upcoming = sessions.where((s) => !s.scheduledAt.isBefore(now)).toList()
                ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
              if (upcoming.isEmpty) {
                return _EmptyCard(message: 'No upcoming practice sessions scheduled.');
              }
              return _PracticeSummaryCard(session: upcoming.first);
            },
            loading: () => const _LoadingCard(),
            error: (error, stackTrace) => _ErrorCard(
              message: error is ApiException ? error.message : 'Failed to load practice sessions',
            ),
          ),
          const SizedBox(height: 24),
          Text('Quick links', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenSquad,
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Squad'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenMatches,
                  icon: const Icon(Icons.sports_cricket_outlined),
                  label: const Text('Matches'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PracticeSummaryCard extends StatelessWidget {
  const _PracticeSummaryCard({required this.session});

  final PracticeSession session;

  @override
  Widget build(BuildContext context) {
    final scheduledAt = session.scheduledAt.toLocal();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.fitness_center_outlined),
        title: Text(session.practiceType.label),
        subtitle: Text(
          '${DateFormat.yMMMEd().format(scheduledAt)} · ${DateFormat.jm().format(scheduledAt)}'
          '${(session.venueName ?? '').trim().isEmpty ? '' : ' · ${session.venueName}'}',
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: Theme.of(context).disabledColor)),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
    );
  }
}
