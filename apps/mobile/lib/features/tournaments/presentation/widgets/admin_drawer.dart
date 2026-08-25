import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/application/session_controller.dart';
import '../../../organizations/application/organizations_providers.dart';
import '../../../teams/application/teams_providers.dart';
import '../../application/tournaments_providers.dart';

/// The admin dashboard's hamburger-menu navigation — the mobile translation
/// of the reference mockup's permanent sidebar. Drawer items fall into two
/// groups:
///
/// - Wired items (Dashboard, Tournaments, Teams, Players, Auction,
///   Applications, Matches, Schedule, Points Table, Finance, Coaches,
///   Practice, Venues, Officials, Sponsors) navigate to screens that
///   actually exist today. Teams, Players, Applications, Matches, Points
///   Table and Finance currently only exist as tabs *inside* a specific
///   tournament's detail screen (there's no top-level "all teams"/"all
///   matches" screen yet), and Auction is a standalone flow reached the same
///   way AuctionEntryTab's own CTA reaches it. So tapping one of these:
///     - with exactly one tournament in the org, jumps straight into that
///       tournament (its detail screen on the relevant tab, or straight into
///       the auction sessions list for Auction);
///     - with zero or more than one tournament, shows a snackbar nudging the
///       admin to open a specific tournament first rather than guessing
///       which one was meant.
///   "Matches" and "Schedule" both land on the same Matches tab (index 4)
///   — the fixture list *is* the schedule in this app's translation of the
///   reference mockup, there's no separate calendar screen. "Points Table"
///   lands on TournamentDetailScreen's Points Table tab (index 5) — promoted
///   out of the "Soon" group now that `TournamentsService.getPointsTable`
///   and its tab actually exist. "Finance" lands on its Finance tab (index
///   6) — promoted out of "Soon" now that the finance module's dashboard,
///   transaction CRUD, and team/player fee views (see features/finance) are
///   built.
///   Coaches is org-level (no jump-in needed, same as Players' underlying
///   data — it opens CoachesListScreen directly). Practice is team-scoped,
///   not tournament-scoped (see PracticeSession entity's doc comment), so
///   it has its own jump-in logic (see [_openPractice]) rather than reusing
///   the tournament-tab jump-in above: with exactly one org team it jumps
///   straight to that team's practice list (PracticeSessionsScreen); with
///   zero or more than one, it nudges the admin to open a specific team via
///   Teams first (there's no top-level "all teams" screen either, and
///   Teams' own jump-in already lands on a tournament's Teams tab, which
///   lists these same org-level teams — see TeamListTab). Venues, Officials
///   and Sponsors are org-level too (no jump-in needed, same as Coaches) —
///   they open VenuesListScreen/OfficialsListScreen/SponsorsListScreen
///   directly. Officials covers umpires, scorers, and match referees in one
///   screen with a role filter, mirroring how the backend groups them under
///   a single `officials` table (see Official entity's doc comment) rather
///   than splitting into three near-identical drawer items/screens.
/// - Not-yet-built items (Captains, Live Score, Statistics, Reports,
///   Settings) are shown greyed-out with a "Soon" badge — so the full
///   structure from the reference mockup stays visible and sets
///   expectations — but tapping one only shows a "Coming soon" snackbar; no
///   placeholder screens exist for these. Statistics specifically stays
///   here because no tournament-wide player-statistics/leaderboard endpoint
///   exists on the backend today — only per-match scorecards (see
///   ScoringRealtimeService.getScorecard).
class AdminDrawer extends ConsumerWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final organizationAsync = ref.watch(activeOrganizationProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(
              orgName: organizationAsync.value?.name,
              userName: session.user?.fullName,
              userEmail: session.user?.email,
              onSignOut: () {
                Navigator.of(context).pop();
                ref.read(sessionControllerProvider.notifier).logout();
              },
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerTile(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    selected: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _DrawerTile(
                    icon: Icons.emoji_events_outlined,
                    label: 'Tournaments',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _DrawerTile(
                    icon: Icons.groups_outlined,
                    label: 'Teams',
                    onTap: () =>
                        _openTournamentScoped(context, ref, tabIndex: 0, featureLabel: 'Teams'),
                  ),
                  _DrawerTile(
                    icon: Icons.person_outline,
                    label: 'Players',
                    onTap: () =>
                        _openTournamentScoped(context, ref, tabIndex: 1, featureLabel: 'Players'),
                  ),
                  _DrawerTile(
                    icon: Icons.gavel_outlined,
                    label: 'Auction',
                    onTap: () => _openAuction(context, ref),
                  ),
                  _DrawerTile(
                    icon: Icons.fact_check_outlined,
                    label: 'Applications',
                    onTap: () => _openTournamentScoped(
                      context,
                      ref,
                      tabIndex: 3,
                      featureLabel: 'Applications',
                    ),
                  ),
                  _DrawerTile(
                    icon: Icons.sports_outlined,
                    label: 'Matches',
                    onTap: () =>
                        _openTournamentScoped(context, ref, tabIndex: 4, featureLabel: 'Matches'),
                  ),
                  _DrawerTile(
                    icon: Icons.calendar_month_outlined,
                    label: 'Schedule',
                    onTap: () =>
                        _openTournamentScoped(context, ref, tabIndex: 4, featureLabel: 'Schedule'),
                  ),
                  _DrawerTile(
                    icon: Icons.leaderboard_outlined,
                    label: 'Points Table',
                    onTap: () => _openTournamentScoped(
                      context,
                      ref,
                      tabIndex: 5,
                      featureLabel: 'Points Table',
                    ),
                  ),
                  _DrawerTile(
                    icon: Icons.payments_outlined,
                    label: 'Finance',
                    onTap: () =>
                        _openTournamentScoped(context, ref, tabIndex: 6, featureLabel: 'Finance'),
                  ),
                  _DrawerTile(
                    icon: Icons.badge_outlined,
                    label: 'Coaches',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(coachesListPath);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.sports_cricket_outlined,
                    label: 'Practice',
                    onTap: () => _openPractice(context, ref),
                  ),
                  _DrawerTile(
                    icon: Icons.stadium_outlined,
                    label: 'Venues',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(venuesListPath);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.assignment_ind_outlined,
                    label: 'Officials',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(officialsListPath);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.handshake_outlined,
                    label: 'Sponsors',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(sponsorsListPath);
                    },
                  ),
                  const Divider(height: 24),
                  _DrawerTile(
                    icon: Icons.visibility_outlined,
                    label: 'Preview as Fan',
                    onTap: () => _openPublicFanView(context, ref),
                  ),
                  const Divider(height: 24),
                  const _ComingSoonTile(icon: Icons.shield_outlined, label: 'Captains'),
                  const _ComingSoonTile(icon: Icons.live_tv_outlined, label: 'Live Score'),
                  const _ComingSoonTile(icon: Icons.bar_chart_outlined, label: 'Statistics'),
                  const _ComingSoonTile(icon: Icons.summarize_outlined, label: 'Reports'),
                  const _ComingSoonTile(icon: Icons.settings_outlined, label: 'Settings'),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTournamentScoped(
    BuildContext context,
    WidgetRef ref, {
    required int tabIndex,
    required String featureLabel,
  }) async {
    Navigator.of(context).pop();
    final tournaments = ref.read(tournamentsListProvider).value;
    if (tournaments == null || tournaments.isEmpty) {
      _showHint(context, 'Open a tournament first to view its $featureLabel.');
      return;
    }
    if (tournaments.length > 1) {
      _showHint(context, 'Pick a tournament below to view its $featureLabel.');
      return;
    }
    context.push(tournamentDetailPath(tournaments.single.id), extra: tabIndex);
  }

  Future<void> _openAuction(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    final tournaments = ref.read(tournamentsListProvider).value;
    if (tournaments == null || tournaments.isEmpty) {
      _showHint(context, 'Open a tournament first to view its Auction.');
      return;
    }
    if (tournaments.length > 1) {
      _showHint(context, 'Pick a tournament below to view its Auction.');
      return;
    }
    context.push(auctionSessionListPath(tournaments.single.id));
  }

  /// Practice sessions are team-scoped, not tournament-scoped, so this
  /// mirrors [_openTournamentScoped]'s "exactly one -> jump straight in,
  /// otherwise nudge" shape but resolves against the org's *teams* instead
  /// of its tournaments. Unlike [_openTournamentScoped]/[_openAuction],
  /// which read `tournamentsListProvider` synchronously (safe because
  /// AdminHomeScreen — this drawer's only host — already watches it, so
  /// it's warm by the time the drawer opens), `teamsListProvider` isn't
  /// watched anywhere upstream of this drawer, so this awaits the provider's
  /// future directly rather than risk reading a still-null cache.
  Future<void> _openPractice(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    try {
      final teams = await ref.read(teamsListProvider.future);
      if (!context.mounted) return;
      if (teams.isEmpty) {
        _showHint(context, 'Add a team first to view its Practice sessions.');
        return;
      }
      if (teams.length > 1) {
        _showHint(context, 'Open a team (via Teams) to view its Practice sessions.');
        return;
      }
      context.push(practiceSessionsPath(teams.single.id), extra: teams.single);
    } catch (_) {
      if (!context.mounted) return;
      _showHint(context, 'Could not load teams. Try again.');
    }
  }

  /// Entry point into the unauthenticated "browse as a fan" section (see
  /// `features/public/`) — pushes the caller's own active org id into
  /// `PublicFanHomeScreen`. The org name is passed along purely for display
  /// (there's no public org-detail endpoint to fetch it from inside that
  /// section — see `PublicFanHomeScreen.organizationName`'s doc comment);
  /// it's read from [activeOrganizationProvider], which this drawer's host
  /// (`AdminHomeScreen`) already keeps warm.
  void _openPublicFanView(BuildContext context, WidgetRef ref) {
    Navigator.of(context).pop();
    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) {
      _showHint(context, 'No active organization to preview.');
      return;
    }
    final organizationName = ref.read(activeOrganizationProvider).value?.name;
    context.push(publicFanHomePath(organizationId), extra: organizationName);
  }

  void _showHint(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.orgName,
    required this.userName,
    required this.userEmail,
    required this.onSignOut,
  });

  final String? orgName;
  final String? userName;
  final String? userEmail;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 20),
      color: colorScheme.primaryContainer,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            child: Text(_initials(userName ?? userEmail ?? '?')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  orgName ?? 'Organization',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  userName ?? userEmail ?? '',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colorScheme.onPrimaryContainer),
                  overflow: TextOverflow.ellipsis,
                ),
                if (userEmail != null && userName != null)
                  Text(
                    userEmail!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.75),
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: Icon(Icons.logout, color: colorScheme.onPrimaryContainer),
            onPressed: onSignOut,
          ),
        ],
      ),
    );
  }

  String _initials(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      onTap: onTap,
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).disabledColor;
    return ListTile(
      leading: Icon(icon, color: mutedColor),
      title: Text(label, style: TextStyle(color: mutedColor)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: mutedColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Soon',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: mutedColor),
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$label is coming soon.')));
      },
    );
  }
}
