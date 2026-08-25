import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../application/players_providers.dart';
import '../data/models/player.dart';
import '../data/models/player_statistics.dart';
import 'widgets/player_statistics_batting_tab.dart';
import 'widgets/player_statistics_bowling_tab.dart';
import 'widgets/player_statistics_fielding_tab.dart';
import 'widgets/player_statistics_match_history_tab.dart';
import 'widgets/player_statistics_performance_graph_tab.dart';

/// Player Statistics profile screen — `GET
/// .../players/:playerId/statistics` (`PlayersController.getStatistics`)
/// rendered as a teal-gradient profile header (photo/name/role/rating with
/// Matches/Runs/Wickets/Rating embedded as quick stats), a white detail card
/// (batting/bowling style, DOB, role, experience, address — only for fields
/// the player actually has), and 5 tabs: Batting, Bowling, Fielding, Match
/// History, Performance Graph.
///
/// Reached via "View statistics" on PlayerListTab's per-player popup menu
/// (parallel to "Auction history", which opens a dialog —
/// `showPlayerPurchaseHistoryDialog` — this one is a dedicated screen/route
/// instead, since 5 tabs' worth of content doesn't fit a dialog).
///
/// Also reused, generically, as the player bottom-nav shell's Stats tab
/// (`PlayerStatsTab`, features/player_dashboard) for a self-view of the
/// signed-in player's own career statistics — pass [embedded]: true there so
/// this renders without its own `Scaffold`/`AppBar` (the tab bar moves
/// inline, right under the header, since there's no app bar to host it in
/// `bottom:`) instead of pushing a whole new screen inside the shell.
class PlayerStatisticsScreen extends ConsumerWidget {
  const PlayerStatisticsScreen({super.key, required this.player, this.embedded = false});

  /// The already-loaded [Player] (photo/name/role). For the admin route,
  /// passed by PlayerListTab so the header renders immediately without a
  /// second fetch; for the embedded self-view, passed by `PlayerStatsTab`
  /// (resolved via `myPlayerProvider`). Only the statistics themselves
  /// (`playerStatisticsProvider`) come from the network here either way.
  final Player player;

  /// When true, renders as a bare body (no `Scaffold`/`AppBar`) suitable for
  /// embedding inside another screen's own tab body. Defaults to false for
  /// the original admin "View statistics" route, which is unchanged.
  final bool embedded;

  /// Icon+label tabs matching the redesigned mockup's tab-bar aesthetic.
  /// Kept as the original 5 tabs (Batting/Bowling/Fielding/Match
  /// History/Performance Graph) rather than the mockup's 4 (Overview/
  /// Stats/Matches/Awards) — collapsing to 4 would either merge distinct
  /// data (batting vs bowling vs fielding are separate backend sections) or
  /// invent an "Awards" tab with no backing data. See the class doc above.
  static const _tabs = [
    Tab(icon: Icon(Icons.sports_cricket), text: 'Batting'),
    Tab(icon: Icon(Icons.sports_baseball), text: 'Bowling'),
    Tab(icon: Icon(Icons.front_hand), text: 'Fielding'),
    Tab(icon: Icon(Icons.history), text: 'Match History'),
    Tab(icon: Icon(Icons.show_chart), text: 'Performance Graph'),
  ];

  static const TabBar _tabBar = TabBar(
    isScrollable: true,
    labelColor: AppColors.teal,
    unselectedLabelColor: AppColors.textSecondary,
    indicatorColor: AppColors.teal,
    tabs: _tabs,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(playerStatisticsProvider(player.id));
    final summary = statsAsync.valueOrNull?.summary;

    final body = Column(
      children: [
        _ProfileHeader(player: player, summary: summary),
        _DetailListCard(player: player),
        if (embedded) _tabBar,
        if (statsAsync.hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              statsAsync.error is ApiException
                  ? (statsAsync.error! as ApiException).message
                  : 'Failed to load statistics',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: statsAsync.when(
            data: (stats) => TabBarView(
              children: [
                PlayerStatisticsBattingTab(batting: stats.batting),
                PlayerStatisticsBowlingTab(bowling: stats.bowling),
                PlayerStatisticsFieldingTab(fielding: stats.fielding),
                PlayerStatisticsMatchHistoryTab(matchHistory: stats.matchHistory),
                PlayerStatisticsPerformanceGraphTab(matchHistory: stats.matchHistory),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
      ],
    );

    if (embedded) {
      return DefaultTabController(length: _tabs.length, child: body);
    }
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(player.fullName),
          bottom: _tabBar,
        ),
        body: body,
      ),
    );
  }
}

/// Decimal-as-string rating ("8.60") rendered to one decimal place ("8.6");
/// falls back to the raw string if it's ever not parseable as a number.
String _formatRating(String raw) {
  final parsed = double.tryParse(raw);
  return parsed != null ? parsed.toStringAsFixed(1) : raw;
}

/// "AM" from "Amit Mathur", "A" from a single-word name — placeholder shown
/// in the avatar circle when the player has no [Player.photoUrl].
String _initials(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

/// Teal-gradient profile card: avatar, name (+ verified badge), role, an
/// amber rating badge top-right, and a Matches/Runs/Wickets/Rating quick-stat
/// row embedded in the card itself — replaces the old plain-row header plus
/// separate white 2x3 stat grid below it.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.player, required this.summary});

  final Player player;

  /// Null while statistics are still loading (or failed) — the quick-stat
  /// numbers render as "-" placeholders in that case rather than blocking
  /// the whole header on the network call.
  final PlayerStatisticsSummary? summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.teal, AppColors.tealDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            if (player.rating != null)
              Positioned(top: 14, right: 14, child: _RatingBadge(rating: player.rating!)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        backgroundImage: player.photoUrl != null
                            ? NetworkImage(Env.mediaUrl(player.photoUrl!))
                            : null,
                        child: player.photoUrl == null
                            ? Text(
                                _initials(player.fullName),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          // Keeps the name/role column clear of the rating
                          // badge floating in the top-right corner.
                          padding: EdgeInsets.only(right: player.rating != null ? 56 : 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      player.fullName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (player.verificationStatus == PlayerVerificationStatus.approved) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, color: Colors.white, size: 16),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                player.role.label,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _QuickStatsRow(player: player, summary: summary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final String rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: AppColors.amber, size: 14),
          const SizedBox(width: 4),
          Text(
            _formatRating(rating),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Matches / Runs / Wickets / Rating — the 4 quick stats the mockup shows
/// embedded directly in the gradient header (replacing the old 6-stat white
/// grid below it). Average/Strike Rate/Economy remain available in their
/// respective Batting/Bowling tabs rather than being dropped entirely.
class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.player, required this.summary});

  final Player player;
  final PlayerStatisticsSummary? summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Row(
      children: [
        Expanded(child: _QuickStat(value: s != null ? '${s.matchesPlayed}' : '-', label: 'Matches')),
        Expanded(child: _QuickStat(value: s != null ? '${s.totalRuns}' : '-', label: 'Runs')),
        Expanded(child: _QuickStat(value: s != null ? '${s.totalWickets}' : '-', label: 'Wickets')),
        Expanded(
          child: _QuickStat(
            value: player.rating != null ? _formatRating(player.rating!) : '-',
            label: 'Rating',
          ),
        ),
      ],
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Plain white card of label/value rows (Batting Style, Bowling Style, Date
/// of Birth, Playing Role, Experience, Address) below the header. Only rows
/// backed by a non-null [Player] field are shown — no "Address: —"
/// placeholders for data the player never entered.
class _DetailListCard extends StatelessWidget {
  const _DetailListCard({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (player.battingStyle != null) ('Batting Style', player.battingStyle!),
      if (player.bowlingStyle != null) ('Bowling Style', player.bowlingStyle!),
      if (player.dob != null) ('Date of Birth', _formatDob(player.dob!)),
      ('Playing Role', player.role.label),
      if (player.experience != null) ('Experience', player.experience!),
      if (player.address != null) ('Address', player.address!),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                _DetailRow(label: rows[i].$1, value: rows[i].$2),
                if (i != rows.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// [Player.dob] is stored `yyyy-MM-dd` (see CreatePlayerScreen's
  /// `_dateFormat`); rendered here as e.g. "Jan 12, 1995" for readability,
  /// falling back to the raw string if it's ever unparseable.
  static String _formatDob(String dob) {
    final parsed = DateTime.tryParse(dob);
    return parsed != null ? DateFormat.yMMMd().format(parsed) : dob;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
