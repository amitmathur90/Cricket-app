import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../matches/data/models/match.dart' show MatchStatus;
import '../application/public_providers.dart';
import '../data/models/public_match.dart';
import 'widgets/public_match_card.dart';

/// `GET public/organizations/:organizationId/tournaments/:tournamentId/matches`
/// — two tabs (Upcoming / Results), client-side filtered by [MatchStatus]
/// from the one fetched list, same "one fetch, filter client-side" shape as
/// `MatchesTab` on the authenticated side. Live matches surface under
/// "Upcoming" (they're neither strictly upcoming nor a result, but there's
/// no third tab here — tapping one is enough to reach the live score via the
/// card itself... actually routed via the underlying tournament's LIVE NOW
/// card, not from here) — tapping any card just opens Fixtures & Results
/// again is a no-op, so live/scheduled matches route back into this screen,
/// while completed ones show their result summary inline (see
/// `PublicMatchCard`).
class PublicFixturesScreen extends ConsumerStatefulWidget {
  const PublicFixturesScreen({
    super.key,
    required this.organizationId,
    required this.tournamentId,
  });

  final String organizationId;
  final String tournamentId;

  @override
  ConsumerState<PublicFixturesScreen> createState() => _PublicFixturesScreenState();
}

class _PublicFixturesScreenState extends ConsumerState<PublicFixturesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = (organizationId: widget.organizationId, tournamentId: widget.tournamentId);
    final matchesAsync = ref.watch(publicMatchesProvider(scope));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fixtures & Results'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Results')],
        ),
      ),
      body: matchesAsync.when(
        data: (matches) {
          final upcoming = matches
              .where((m) => m.status == MatchStatus.scheduled || m.status == MatchStatus.live)
              .toList()
            ..sort((a, b) {
              final at = a.scheduledAt;
              final bt = b.scheduledAt;
              if (at == null && bt == null) return 0;
              if (at == null) return 1;
              if (bt == null) return -1;
              return at.compareTo(bt);
            });
          final results = matches.where((m) => m.status == MatchStatus.completed).toList()
            ..sort((a, b) {
              final at = a.scheduledAt;
              final bt = b.scheduledAt;
              if (at == null || bt == null) return 0;
              return bt.compareTo(at);
            });

          return TabBarView(
            controller: _tabController,
            children: [
              _MatchList(
                matches: upcoming,
                emptyMessage: 'No upcoming fixtures.',
                onRefresh: () => ref.refresh(publicMatchesProvider(scope).future),
                onTapMatch: (match) => match.status == MatchStatus.live
                    ? context.push(
                        publicLiveMatchPath(widget.organizationId, widget.tournamentId, match.id),
                      )
                    : null,
              ),
              _MatchList(
                matches: results,
                emptyMessage: 'No completed matches yet.',
                onRefresh: () => ref.refresh(publicMatchesProvider(scope).future),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(error is ApiException ? error.message : 'Failed to load matches')),
      ),
    );
  }
}

class _MatchList extends StatelessWidget {
  const _MatchList({
    required this.matches,
    required this.emptyMessage,
    required this.onRefresh,
    this.onTapMatch,
  });

  final List<PublicMatch> matches;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final void Function(PublicMatch match)? onTapMatch;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Center(child: Text(emptyMessage));
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final match = matches[index];
          return PublicMatchCard(
            match: match,
            onTap: () => onTapMatch?.call(match),
          );
        },
      ),
    );
  }
}
