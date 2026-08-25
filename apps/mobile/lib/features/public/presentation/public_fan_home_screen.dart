import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../matches/data/models/match.dart' show MatchStatus;
import '../application/public_providers.dart';
import '../data/models/public_player_ranking.dart';
import '../data/models/public_post.dart';
import '../data/models/public_tournament.dart';
import 'widgets/public_live_score_card.dart';
import 'widgets/public_match_card.dart';

/// Entry screen for the app's unauthenticated "browse as a fan" section —
/// see `AdminDrawer`'s "Preview as Fan" item (the phase-1 entry point,
/// reached from an already-known org context; see this feature's top-level
/// doc comment in `core/router/app_router.dart` for why there's no public
/// "discover organizations" flow yet) and `PublicRepository` for the backend
/// contract.
///
/// Layout follows the spec's rough mockup: a LIVE NOW card (only shown when
/// a match in the leading tournament is `live`), Upcoming Matches, a Points
/// Table summary, Top Performers, Latest News, then a grid of section
/// shortcuts (Tournaments/Teams/Fixtures/Results/Points Table/Rankings/
/// Photos/Videos/Sponsors).
class PublicFanHomeScreen extends ConsumerWidget {
  const PublicFanHomeScreen({super.key, required this.organizationId, this.organizationName});

  final String organizationId;

  /// Display-only — passed by whatever screen pushed this route (e.g.
  /// `AdminDrawer`, which already has the org name loaded). Never used in
  /// any API call; the public endpoints don't return an org name at all
  /// (there's no public org-detail endpoint), so this falls back to a
  /// generic label when absent (e.g. a cold deep link).
  final String? organizationName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryTournamentAsync = ref.watch(publicPrimaryTournamentProvider(organizationId));
    final rankingsScope = (
      organizationId: organizationId,
      metric: PublicRankingMetric.runs,
      limit: 5,
    );
    final rankingsAsync = ref.watch(publicRankingsProvider(rankingsScope));
    final newsAsync = ref.watch(
      publicPostsProvider((organizationId: organizationId, type: PublicPostType.news)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(organizationName ?? 'Fan View'),
        actions: [
          IconButton(
            tooltip: 'Sponsors',
            icon: const Icon(Icons.handshake_outlined),
            onPressed: () => context.push(publicSponsorsPath(organizationId)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(publicPrimaryTournamentProvider(organizationId));
          ref.invalidate(publicRankingsProvider(rankingsScope));
          ref.invalidate(
            publicPostsProvider((organizationId: organizationId, type: PublicPostType.news)),
          );
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Browsing as a fan — read only',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            primaryTournamentAsync.when(
              data: (tournament) => tournament == null
                  ? const _EmptyState()
                  : _TournamentSections(organizationId: organizationId, tournament: tournament),
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(error is ApiException ? error.message : 'Failed to load tournaments'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Top Performers',
              onViewAll: () => context.push(publicRankingsPath(organizationId)),
            ),
            const SizedBox(height: 8),
            rankingsAsync.when(
              data: (rows) => rows.isEmpty
                  ? const _EmptyHint('No player statistics yet.')
                  : Card(
                      child: Column(
                        children: [
                          for (final row in rows)
                            ListTile(
                              leading: CircleAvatar(child: Text('${row.position}')),
                              title: Text(row.playerName),
                              subtitle: Text('${row.runs} runs · ${row.wickets} wkts'),
                              trailing: row.average != null
                                  ? Text('Avg ${row.average!.toStringAsFixed(1)}')
                                  : null,
                            ),
                        ],
                      ),
                    ),
              loading: () => const _LoadingCard(),
              error: (error, stackTrace) =>
                  _ErrorHint(error is ApiException ? error.message : 'Failed to load rankings'),
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Latest News',
              onViewAll: () => context.push(publicPostsPath(organizationId)),
            ),
            const SizedBox(height: 8),
            newsAsync.when(
              data: (posts) => posts.isEmpty
                  ? const _EmptyHint('No news posted yet.')
                  : Column(
                      children: [
                        for (final post in posts.take(5)) _NewsTile(post: post),
                      ],
                    ),
              loading: () => const _LoadingCard(),
              error: (error, stackTrace) =>
                  _ErrorHint(error is ApiException ? error.message : 'Failed to load news'),
            ),
            const SizedBox(height: 24),
            Text('Explore', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _ExploreGrid(organizationId: organizationId),
          ],
        ),
      ),
    );
  }
}

/// Everything that depends on which tournament is "leading" the home
/// screen — matches (for LIVE NOW / Upcoming) and the points table summary.
/// Split out of [PublicFanHomeScreen.build] so those two provider watches
/// only start once a tournament id is known.
class _TournamentSections extends ConsumerWidget {
  const _TournamentSections({required this.organizationId, required this.tournament});

  final String organizationId;
  final PublicTournament tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = (organizationId: organizationId, tournamentId: tournament.id);
    final matchesAsync = ref.watch(publicMatchesProvider(scope));
    final pointsTableAsync = ref.watch(publicPointsTableProvider(scope));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.push(publicTournamentDetailPath(organizationId, tournament.id)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tournament.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: 12),
        matchesAsync.when(
          data: (matches) {
            final live = matches.where((m) => m.status == MatchStatus.live).toList();
            final upcoming = matches.where((m) => m.status == MatchStatus.scheduled).toList()
              ..sort((a, b) {
                final at = a.scheduledAt;
                final bt = b.scheduledAt;
                if (at == null && bt == null) return 0;
                if (at == null) return 1;
                if (bt == null) return -1;
                return at.compareTo(bt);
              });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (live.isNotEmpty) ...[
                  PublicLiveScoreCard(
                    organizationId: organizationId,
                    tournamentId: tournament.id,
                    match: live.first,
                    onTap: () => context.push(
                      publicLiveMatchPath(organizationId, tournament.id, live.first.id),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _SectionHeader(
                  title: 'Upcoming Matches',
                  onViewAll: () => context.push(publicFixturesPath(organizationId, tournament.id)),
                ),
                const SizedBox(height: 8),
                if (upcoming.isEmpty)
                  const _EmptyHint('No upcoming fixtures scheduled.')
                else
                  for (final match in upcoming.take(3))
                    PublicMatchCard(
                      match: match,
                      onTap: () => context.push(publicFixturesPath(organizationId, tournament.id)),
                    ),
              ],
            );
          },
          loading: () => const _LoadingCard(),
          error: (error, stackTrace) =>
              _ErrorHint(error is ApiException ? error.message : 'Failed to load matches'),
        ),
        const SizedBox(height: 20),
        _SectionHeader(
          title: 'Points Table',
          onViewAll: () => context.push(publicPointsTablePath(organizationId, tournament.id)),
        ),
        const SizedBox(height: 8),
        pointsTableAsync.when(
          data: (rows) => rows.isEmpty
              ? const _EmptyHint('Standings fill in once matches are completed.')
              : Card(
                  child: Column(
                    children: [
                      for (final row in rows.take(5))
                        ListTile(
                          leading: CircleAvatar(child: Text('${row.position}')),
                          title: Text(row.teamName),
                          trailing: Text(
                            '${row.points} pts',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
          loading: () => const _LoadingCard(),
          error: (error, stackTrace) =>
              _ErrorHint(error is ApiException ? error.message : 'Failed to load points table'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        TextButton(onPressed: onViewAll, child: const Text('View all')),
      ],
    );
  }
}

class _NewsTile extends StatelessWidget {
  const _NewsTile({required this.post});

  final PublicPost post;

  @override
  Widget build(BuildContext context) {
    final published = post.publishedAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: post.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  Env.mediaUrl(post.imageUrl!),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.article_outlined),
                ),
              )
            : const CircleAvatar(child: Icon(Icons.article_outlined)),
        title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: published != null ? Text(DateFormat.yMMMd().format(published.toLocal())) : null,
      ),
    );
  }
}

class _ExploreGrid extends StatelessWidget {
  const _ExploreGrid({required this.organizationId});

  final String organizationId;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.emoji_events_outlined, 'Tournaments', () => context.push(publicTournamentListPath(organizationId))),
      (Icons.bar_chart_outlined, 'Player Rankings', () => context.push(publicRankingsPath(organizationId))),
      (
        Icons.article_outlined,
        'News',
        () => context.push(publicPostsPath(organizationId), extra: PublicPostType.news),
      ),
      (
        Icons.photo_outlined,
        'Photos',
        () => context.push(publicPostsPath(organizationId), extra: PublicPostType.photo),
      ),
      (
        Icons.videocam_outlined,
        'Videos',
        () => context.push(publicPostsPath(organizationId), extra: PublicPostType.video),
      ),
      (Icons.handshake_outlined, 'Sponsors', () => context.push(publicSponsorsPath(organizationId))),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: [
        for (final (icon, label, onTap) in items)
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 26, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: Center(
        child: Text(
          'No tournaments published yet — check back soon.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _ErrorHint extends StatelessWidget {
  const _ErrorHint(this.message);

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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
