import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../organizations/application/organizations_providers.dart';
import '../../application/tournaments_providers.dart';
import '../../data/models/tournament_awards.dart';
import '../certificate_screen.dart';
import 'certificate_widget.dart';

/// One award category's static display metadata (title + icon) paired with
/// its computed [AwardResult] — built fresh in [AwardsTab.build] from the
/// 7 non-Man-of-the-Match fields on [TournamentAwardsResponse].
class _AwardCategory {
  const _AwardCategory({required this.title, required this.icon, required this.result});

  final String title;
  final IconData icon;
  final AwardResult result;
}

/// Awards tab within TournamentDetailScreen — `GET
/// .../tournaments/:tournamentId/awards` rendered as one card per award
/// category (icon, winner or an honest "Not awarded" state with the
/// backend's `reasoning`), plus a Man of the Match section listing every
/// completed match's award. Each awarded (non-null) category gets a "View
/// certificate" action — see `CertificateScreen` for the export approach.
/// Same computed/never-persisted, no-role-restriction shape as
/// [PointsTableTab] (see that widget's doc comment), so this reads the
/// backend response the same simple way.
class AwardsTab extends ConsumerWidget {
  const AwardsTab({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final awardsAsync = ref.watch(tournamentAwardsProvider(tournamentId));
    final tournamentAsync = ref.watch(tournamentDetailProvider(tournamentId));
    final organizationAsync = ref.watch(activeOrganizationProvider);

    return awardsAsync.when(
      data: (awards) {
        if (awards == null) {
          return const Center(child: Text('No active organization'));
        }
        final tournamentName = tournamentAsync.asData?.value.name ?? 'Tournament';
        final organizationName = organizationAsync.asData?.value?.name;
        final dateLabel = DateFormat.yMMMd().format(DateTime.now());

        final categories = <_AwardCategory>[
          _AwardCategory(
            title: 'Player of the Tournament',
            icon: Icons.emoji_events,
            result: awards.playerOfTheTournament,
          ),
          _AwardCategory(title: 'Best Batsman', icon: Icons.sports_cricket, result: awards.bestBatsman),
          _AwardCategory(title: 'Best Bowler', icon: Icons.sports_baseball, result: awards.bestBowler),
          _AwardCategory(title: 'Best Fielder', icon: Icons.shield, result: awards.bestFielder),
          _AwardCategory(
            title: 'Best All-Rounder',
            icon: Icons.workspace_premium,
            result: awards.bestAllRounder,
          ),
          _AwardCategory(title: 'Emerging Player', icon: Icons.bolt, result: awards.emergingPlayer),
          _AwardCategory(title: 'Best Captain', icon: Icons.groups, result: awards.bestCaptain),
        ];

        return RefreshIndicator(
          onRefresh: () => ref.refresh(tournamentAwardsProvider(tournamentId).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              for (final category in categories) ...[
                _AwardCard(
                  category: category,
                  tournamentName: tournamentName,
                  organizationName: organizationName,
                  dateLabel: dateLabel,
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.military_tech, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Man of the Match', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 8),
                child: Text(
                  awards.manOfTheMatch.reasoning,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
              if (awards.manOfTheMatch.matches.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 32),
                  child: Text('No completed matches yet.'),
                )
              else
                for (final entry in awards.manOfTheMatch.matches)
                  _MomCard(
                    entry: entry,
                    tournamentName: tournamentName,
                    organizationName: organizationName,
                    dateLabel: dateLabel,
                  ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(error is ApiException ? error.message : 'Failed to load awards'),
      ),
    );
  }
}

class _AwardCard extends StatelessWidget {
  const _AwardCard({
    required this.category,
    required this.tournamentName,
    required this.organizationName,
    required this.dateLabel,
  });

  final _AwardCategory category;
  final String tournamentName;
  final String? organizationName;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final winner = category.result.winner;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(category.icon, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (winner == null)
              _NotAwarded(reasoning: category.result.reasoning)
            else ...[
              Text(
                winner.playerName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(winner.teamName, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(winner.value, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(
                category.result.reasoning,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                  label: const Text('View certificate'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => CertificateScreen(
                        data: CertificateData(
                          tournamentName: tournamentName,
                          awardTitle: category.title,
                          playerName: winner.playerName,
                          teamName: winner.teamName,
                          statLine: winner.value,
                          issuedDateLabel: dateLabel,
                          organizationName: organizationName,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The "not awarded" state — always shows `reasoning` explaining why, never
/// suppressed (see AwardsTab's doc comment).
class _NotAwarded extends StatelessWidget {
  const _NotAwarded({required this.reasoning});

  final String reasoning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: colorScheme.outline),
            const SizedBox(width: 6),
            Text(
              'Not awarded',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.outline),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          reasoning,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
        ),
      ],
    );
  }
}

/// One completed match's Man-of-the-Match card — same certificate action as
/// an [_AwardCard], since every entry here is always a determined winner
/// (a completed match's MoM composite always has an answer once ball data
/// exists).
class _MomCard extends StatelessWidget {
  const _MomCard({
    required this.entry,
    required this.tournamentName,
    required this.organizationName,
    required this.dateLabel,
  });

  final MatchAwardEntry entry;
  final String tournamentName;
  final String? organizationName;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.military_tech),
        title: Text(entry.playerName),
        subtitle: Text('${entry.teamName} · ${entry.value}'),
        trailing: IconButton(
          tooltip: 'View certificate',
          icon: const Icon(Icons.workspace_premium_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => CertificateScreen(
                data: CertificateData(
                  tournamentName: tournamentName,
                  awardTitle: 'Man of the Match',
                  playerName: entry.playerName,
                  teamName: entry.teamName,
                  statLine: entry.value,
                  issuedDateLabel: dateLabel,
                  organizationName: organizationName,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
