import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/dashboard_stat_card.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../auth/application/session_controller.dart';
import '../../../matches/application/match_center_providers.dart';
import '../../../matches/application/matches_providers.dart';
import '../../../matches/data/models/match.dart';
import '../../../players/application/players_providers.dart';
import '../../../players/data/models/player.dart';
import '../../../teams/application/teams_providers.dart';
import '../../application/tournaments_providers.dart';
import '../../data/models/points_table_row.dart';
import '../../data/models/tournament.dart';
import '../../data/models/tournament_awards.dart';

/// One match paired with the tournament it belongs to — fan-out is needed
/// because [matchesRepositoryProvider]'s `list` is per-tournament (there's no
/// org-wide "all matches" endpoint), same technique [_orgMatchesProvider]
/// borrows from this file's former `_orgApplicationsProvider`.
class _OrgMatchEntry {
  const _OrgMatchEntry({required this.match, required this.tournamentId});
  final Match match;
  final String tournamentId;
}

/// All matches across every tournament in the active org — backs the
/// dashboard's "Matches" stat card plus its Live/Upcoming Matches sections.
/// Fans out over [tournamentsListProvider] and concatenates each
/// tournament's matches, same shape as the applications fan-out this
/// dashboard already did before this redesign.
final _orgMatchesProvider = FutureProvider.autoDispose<List<_OrgMatchEntry>>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  final tournaments = await ref.watch(tournamentsListProvider.future);
  if (tournaments.isEmpty) return const [];
  final repository = ref.watch(matchesRepositoryProvider);
  final perTournament = await Future.wait(
    tournaments.map((tournament) => repository.list(organizationId, tournament.id)),
  );
  final entries = <_OrgMatchEntry>[];
  for (var i = 0; i < tournaments.length; i++) {
    for (final match in perTournament[i]) {
      entries.add(_OrgMatchEntry(match: match, tournamentId: tournaments[i].id));
    }
  }
  return entries;
});

/// Picks the one tournament the org-wide dashboard's tournament-scoped
/// widgets (Points Table preview, Top Performers) lead with, when the org
/// has more than one: prefers a `live` tournament, else the soonest-starting
/// `upcoming` one, else the most recently-started other one, else just the
/// first in the list. Same live→upcoming→latest heuristic as
/// `publicPrimaryTournamentProvider` (features/public/application/
/// public_providers.dart) — computed locally here rather than imported since
/// that provider works off the separate `PublicTournament` model.
Tournament? _primaryTournament(List<Tournament> tournaments) {
  if (tournaments.isEmpty) return null;
  Tournament? live;
  Tournament? soonestUpcoming;
  Tournament? latestOther;
  for (final t in tournaments) {
    if (t.status == 'live') {
      live ??= t;
    } else if (t.status == 'upcoming') {
      if (soonestUpcoming == null || t.startDate.compareTo(soonestUpcoming.startDate) < 0) {
        soonestUpcoming = t;
      }
    } else {
      if (latestOther == null || t.startDate.compareTo(latestOther.startDate) > 0) {
        latestOther = t;
      }
    }
  }
  return live ?? soonestUpcoming ?? latestOther ?? tournaments.first;
}

int _byScheduledAt(_OrgMatchEntry a, _OrgMatchEntry b) {
  final aTime = a.match.scheduledAt;
  final bTime = b.match.scheduledAt;
  if (aTime == null && bTime == null) return 0;
  if (aTime == null) return 1;
  if (bTime == null) return -1;
  return aTime.compareTo(bTime);
}

/// `totalOversBowled` is a display string like `"15.2"` (whole overs + balls
/// in the current over, NOT a true decimal — see [ScoringInningsSnapshot]'s
/// doc comment) — this converts it to actual overs (e.g. 15.333) so a run
/// rate can be computed.
double _trueOvers(String raw) {
  final parts = raw.split('.');
  final wholeOvers = int.tryParse(parts[0]) ?? 0;
  final balls = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return wholeOvers + balls / 6.0;
}

/// Cross-references an award winner's `playerId` against the org's player
/// list (already fetched for the Players stat card) to find their
/// `photoUrl` — [AwardWinner] itself carries no photo field. Returns null
/// (generic avatar fallback) when there's no match, never fabricated.
String? _photoForPlayer(List<Player> players, String? playerId) {
  if (playerId == null) return null;
  for (final player in players) {
    if (player.id == playerId) return player.photoUrl;
  }
  return null;
}

/// The dashboard's content below the "Dashboard 🏆 / Welcome back" heading —
/// stat-cards row, Live Matches, Upcoming Matches, a Points Table preview,
/// and a Top Performers row. Mobile translation of the reference mockup's
/// dashboard panel (a Revenue "featured" card is deliberately omitted — see
/// the doc comment at the bottom of this file for why).
///
/// Every tournament-scoped section (Points Table preview, Top Performers)
/// leads with [_primaryTournament] — the org-wide picture (stat counts,
/// Live/Upcoming Matches) doesn't need one tournament chosen, but standings
/// and awards are computed per-tournament server-side, so one has to be
/// picked the same way the Fan Home screen already does.
class DashboardOverview extends ConsumerWidget {
  const DashboardOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentsAsync = ref.watch(tournamentsListProvider);
    final teamsAsync = ref.watch(teamsListProvider);
    final playersAsync = ref.watch(playersListProvider);
    final orgMatchesAsync = ref.watch(_orgMatchesProvider);

    final tournaments = tournamentsAsync.asData?.value ?? const <Tournament>[];
    final players = playersAsync.asData?.value ?? const <Player>[];
    final primaryTournament = _primaryTournament(tournaments);

    final pointsTableAsync =
        primaryTournament == null ? null : ref.watch(pointsTableProvider(primaryTournament.id));
    final awardsAsync =
        primaryTournament == null ? null : ref.watch(tournamentAwardsProvider(primaryTournament.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            DashboardStatCard(
              icon: Icons.emoji_events,
              value: tournamentsAsync.maybeWhen(data: (v) => '${v.length}', orElse: () => '—'),
              label: 'Tournaments',
              accentColor: AppColors.purple,
            ),
            DashboardStatCard(
              icon: Icons.groups,
              value: teamsAsync.maybeWhen(data: (v) => '${v.length}', orElse: () => '—'),
              label: 'Teams',
              accentColor: AppColors.info,
            ),
            DashboardStatCard(
              icon: Icons.person,
              value: playersAsync.maybeWhen(data: (v) => '${v.length}', orElse: () => '—'),
              label: 'Players',
              accentColor: AppColors.primary,
            ),
            DashboardStatCard(
              icon: Icons.sports_cricket,
              value: orgMatchesAsync.maybeWhen(data: (v) => '${v.length}', orElse: () => '—'),
              label: 'Matches',
              accentColor: AppColors.orange,
            ),
          ],
        ),
        const SizedBox(height: 24),
        orgMatchesAsync.when(
          data: (entries) {
            final live = entries.where((e) => e.match.status == MatchStatus.live).toList();
            final upcoming = entries.where((e) => e.match.status == MatchStatus.scheduled).toList()
              ..sort(_byScheduledAt);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (live.isNotEmpty) ...[
                  Row(
                    children: [
                      Text('Live Matches', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 8),
                      StatusPill(label: '${live.length} Live Now', color: AppColors.live, filled: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final entry in live) ...[
                    _LiveMatchCard(match: entry.match, tournamentId: entry.tournamentId),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text('Upcoming Matches', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    if (primaryTournament != null)
                      TextButton(
                        onPressed: () => context.push(
                          tournamentDetailPath(primaryTournament.id),
                          extra: 4, // Matches tab — see TournamentDetailScreen's tab index doc comment.
                        ),
                        child: const Text('View All'),
                      ),
                  ],
                ),
                if (upcoming.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No upcoming matches scheduled.'),
                  )
                else
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < upcoming.length && i < 5; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _UpcomingMatchRow(
                            match: upcoming[i].match,
                            tournamentId: upcoming[i].tournamentId,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              error is ApiException ? error.message : 'Unable to load matches.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
        if (primaryTournament != null) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('Points Table', style: Theme.of(context).textTheme.titleMedium)),
              TextButton(
                onPressed: () => context.push(
                  tournamentDetailPath(primaryTournament.id),
                  extra: 5, // Points Table tab.
                ),
                child: const Text('View Full'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (pointsTableAsync != null)
            pointsTableAsync.when(
              data: (rows) => rows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No standings yet.'),
                    )
                  : _PointsTablePreview(rows: rows),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  error is ApiException ? error.message : 'Unable to load points table.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text('Top Performers', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (awardsAsync != null)
            awardsAsync.when(
              data: (awards) {
                if (awards == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No active organization.'),
                  );
                }
                final cards = [
                  _PerformerCard(
                    title: 'Top Run Scorer',
                    icon: Icons.sports_cricket,
                    result: awards.bestBatsman,
                    photoUrl: _photoForPlayer(players, awards.bestBatsman.winner?.playerId),
                  ),
                  _PerformerCard(
                    title: 'Top Wicket Taker',
                    icon: Icons.sports_baseball,
                    result: awards.bestBowler,
                    photoUrl: _photoForPlayer(players, awards.bestBowler.winner?.playerId),
                  ),
                  _PerformerCard(
                    title: 'Best All Rounder',
                    icon: Icons.workspace_premium,
                    result: awards.bestAllRounder,
                    photoUrl: _photoForPlayer(players, awards.bestAllRounder.winner?.playerId),
                  ),
                  _PerformerCard(
                    title: 'Best Fielder',
                    icon: Icons.shield,
                    result: awards.bestFielder,
                    photoUrl: _photoForPlayer(players, awards.bestFielder.winner?.playerId),
                  ),
                ];
                return SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: cards.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => cards[index],
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  error is ApiException ? error.message : 'Unable to load top performers.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// A small colored circle showing a team's initials (first letter of up to
/// its first two words) — there's no team-logo field on [Match] (only
/// resolved name strings), and no existing "initials avatar" widget
/// elsewhere in the app to reuse, so this is new but intentionally minimal:
/// same rotating [AppColors.accents] palette already used for stat-card icon
/// badges, just applied here as a deterministic per-name color.
class _TeamInitialAvatar extends StatelessWidget {
  const _TeamInitialAvatar({required this.name});

  final String name;

  static const _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initials = trimmed.isEmpty
        ? '?'
        : trimmed.split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase();
    final color = AppColors.accents[trimmed.hashCode.abs() % AppColors.accents.length];
    return CircleAvatar(
      radius: _radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: _radius * 0.7),
      ),
    );
  }
}

/// One live match's card — [LivePill], "{home} VS {away}", and (once
/// [matchLiveStateProvider] resolves) the real current score/run-rate,
/// pulled from the scoring feature rather than fabricated. The score/status
/// lines simply don't render while that second fetch is in flight or fails
/// — [Match] itself has no score fields, only [LiveScoringState] does (see
/// this file's `_trueOvers` doc comment).
class _LiveMatchCard extends ConsumerWidget {
  const _LiveMatchCard({required this.match, required this.tournamentId});

  final Match match;
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAsync =
        ref.watch(matchLiveStateProvider((tournamentId: tournamentId, matchId: match.id)));
    final homeLabel = match.homeTeamName ?? 'TBD';
    final awayLabel = match.awayTeamName ?? 'TBD';
    final venue = match.venueName?.trim();
    final outline = Theme.of(context).colorScheme.outline;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(matchCenterPath(tournamentId, match.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LivePill(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      homeLabel,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'VS',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMuted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      awayLabel,
                      textAlign: TextAlign.right,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              liveAsync.when(
                data: (state) {
                  final innings = state.currentInnings;
                  if (innings == null) return const SizedBox.shrink();
                  final overs = _trueOvers(innings.totalOversBowled);
                  final target = state.target;
                  final statusLine = target != null
                      ? 'Target $target'
                      : overs > 0
                          ? 'CRR ${(innings.totalRuns / overs).toStringAsFixed(2)}'
                          : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        '${innings.totalRuns}/${innings.totalWickets} (${innings.totalOversBowled})',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (statusLine != null) ...[
                        const SizedBox(height: 2),
                        Text(statusLine, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (error, stackTrace) => const SizedBox.shrink(),
              ),
              if (venue != null && venue.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: outline),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venue,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One upcoming match's row within the Upcoming Matches card — overlapping
/// team-initial avatars, "{home} vs {away}", date/time + ground, and an
/// "Upcoming" [StatusPill].
class _UpcomingMatchRow extends StatelessWidget {
  const _UpcomingMatchRow({required this.match, required this.tournamentId});

  final Match match;
  final String tournamentId;

  @override
  Widget build(BuildContext context) {
    final homeLabel = match.homeTeamName ?? 'TBD';
    final awayLabel = match.awayTeamName ?? 'TBD';
    final scheduledAt = match.scheduledAt?.toLocal();
    final dateLabel = scheduledAt != null ? DateFormat('MMM d, h:mm a').format(scheduledAt) : 'Date TBD';
    final venue = match.venueName?.trim();
    final outline = Theme.of(context).colorScheme.outline;

    return InkWell(
      onTap: () => context.push(matchDetailPath(tournamentId, match.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 28,
              child: Stack(
                children: [
                  _TeamInitialAvatar(name: homeLabel),
                  Positioned(left: 16, child: _TeamInitialAvatar(name: awayLabel)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$homeLabel vs $awayLabel',
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: outline),
                      const SizedBox(width: 3),
                      Text(dateLabel, style: Theme.of(context).textTheme.bodySmall),
                      if (venue != null && venue.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.location_on, size: 12, color: outline),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            venue,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const StatusPill(label: 'Upcoming', color: AppColors.info),
          ],
        ),
      ),
    );
  }
}

/// Compact Pos/Team/P/W/L/Pts/NRR table — the top 5 rows of
/// [pointsTableProvider], not re-derived (Ties/No-Result columns from the
/// full [PointsTableTab] are dropped here to keep every row on one phone-
/// width line; the fuller 9-column table is one "View Full" tap away).
class _PointsTablePreview extends StatelessWidget {
  const _PointsTablePreview({required this.rows});

  final List<PointsTableRow> rows;

  static const _posWidth = 24.0;
  static const _numWidth = 24.0;
  static const _ptsWidth = 32.0;
  static const _nrrWidth = 48.0;

  @override
  Widget build(BuildContext context) {
    final top5 = rows.take(5).toList();
    final headerStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(width: _posWidth, child: Text('Pos', style: headerStyle)),
                Expanded(child: Text('Team', style: headerStyle)),
                SizedBox(width: _numWidth, child: Text('P', style: headerStyle, textAlign: TextAlign.center)),
                SizedBox(width: _numWidth, child: Text('W', style: headerStyle, textAlign: TextAlign.center)),
                SizedBox(width: _numWidth, child: Text('L', style: headerStyle, textAlign: TextAlign.center)),
                SizedBox(
                  width: _ptsWidth,
                  child: Text('Pts', style: headerStyle, textAlign: TextAlign.center),
                ),
                SizedBox(
                  width: _nrrWidth,
                  child: Text('NRR', style: headerStyle, textAlign: TextAlign.right),
                ),
              ],
            ),
            const Divider(height: 16),
            for (var i = 0; i < top5.length; i++) ...[
              if (i > 0) const Divider(height: 12),
              _pointsRow(context, top5[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pointsRow(BuildContext context, PointsTableRow row) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    final nrrColor = row.netRunRate > 0
        ? AppColors.positive
        : row.netRunRate < 0
            ? AppColors.negative
            : AppColors.textSecondary;
    return Row(
      children: [
        SizedBox(
          width: _posWidth,
          child: Text('${row.position}', style: bodyStyle?.copyWith(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(row.teamName, style: bodyStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        SizedBox(width: _numWidth, child: Text('${row.played}', style: bodyStyle, textAlign: TextAlign.center)),
        SizedBox(width: _numWidth, child: Text('${row.won}', style: bodyStyle, textAlign: TextAlign.center)),
        SizedBox(width: _numWidth, child: Text('${row.lost}', style: bodyStyle, textAlign: TextAlign.center)),
        SizedBox(
          width: _ptsWidth,
          child: Text(
            '${row.points}',
            style: bodyStyle?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: _nrrWidth,
          child: Text(
            row.netRunRate.toStringAsFixed(2),
            style: TextStyle(color: nrrColor, fontWeight: FontWeight.w600, fontSize: 13),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// One Top Performers card — circular avatar (player photo if
/// [_photoForPlayer] found one, else a generic person icon), player name,
/// team name, and the award's stat-line [AwardWinner.value]. Renders the
/// same honest "Not awarded" state [AwardsTab] uses (with the backend's
/// `reasoning`) when [AwardResult.winner] is null, rather than hiding the
/// card or inventing a placeholder winner.
class _PerformerCard extends StatelessWidget {
  const _PerformerCard({
    required this.title,
    required this.icon,
    required this.result,
    this.photoUrl,
  });

  final String title;
  final IconData icon;
  final AwardResult result;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final winner = result.winner;
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CircleAvatar(
                radius: 22,
                backgroundImage: photoUrl != null ? NetworkImage(Env.mediaUrl(photoUrl!)) : null,
                child: photoUrl == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(height: 8),
              if (winner == null)
                Text(
                  'Not awarded',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                )
              else ...[
                Text(
                  winner.playerName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  winner.teamName,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  winner.value,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Why there's no Revenue "featured" card here (mockup calls for a solid-
// green DashboardFeaturedStatCard showing total revenue + a "+X% from last
// month" delta):
//
// `financeDashboardProvider` (features/finance/application/finance_providers
// .dart) is tournament-scoped (`FutureProvider.family<FinanceDashboard,
// String tournamentId>`), not org-wide — there is no backend endpoint that
// sums revenue across every tournament in an org. Showing one tournament's
// total under an unqualified "Revenue" label on an org-wide dashboard would
// misrepresent it as the org's total. And `FinanceDashboard` has no
// month-over-month figure anywhere (`totalRevenue`/`revenueBreakdown`/
// `totalExpenses`/`expenseBreakdown`/`netBalance` are all point-in-time) —
// the mockup's "+X% from last month" delta genuinely doesn't exist in this
// app's data today and would have to be fabricated. Per this task's "don't
// fabricate data" constraint, the card is omitted entirely rather than
// showing a misleading total or an invented delta.
// ---------------------------------------------------------------------
