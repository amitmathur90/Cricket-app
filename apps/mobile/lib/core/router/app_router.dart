import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auction/presentation/auction_history_screen.dart';
import '../../features/auction/presentation/auction_player_bid_history_screen.dart';
import '../../features/auction/presentation/auction_report_screen.dart';
import '../../features/auction/presentation/auction_session_detail_screen.dart';
import '../../features/auction/presentation/auction_session_list_screen.dart';
import '../../features/auction/presentation/auction_team_dashboard_screen.dart';
import '../../features/captain/presentation/captain_home_screen.dart';
import '../../features/coaches/presentation/coaches_list_screen.dart';
import '../../features/finance/data/models/finance_transaction.dart';
import '../../features/finance/presentation/finance_player_fees_screen.dart';
import '../../features/finance/presentation/finance_team_fees_screen.dart';
import '../../features/finance/presentation/finance_transaction_detail_screen.dart';
import '../../features/finance/presentation/finance_transaction_form_screen.dart';
import '../../features/finance/presentation/finance_transactions_screen.dart';
import '../../features/matches/data/models/match.dart';
import '../../features/matches/presentation/lineup_selection_screen.dart';
import '../../features/matches/presentation/match_center_screen.dart';
import '../../features/matches/presentation/match_detail_screen.dart';
import '../../features/matches/presentation/match_form_screen.dart';
import '../../features/notifications/presentation/notification_center_screen.dart';
import '../../features/officials/presentation/officials_list_screen.dart';
import '../../features/organizations/presentation/create_organization_screen.dart';
import '../../features/organizations/presentation/join_organization_screen.dart';
import '../../features/organizations/presentation/org_select_screen.dart';
import '../../features/player_dashboard/presentation/player_shell_screen.dart';
import '../../features/players/data/models/player.dart';
import '../../features/players/presentation/create_player_screen.dart';
import '../../features/players/presentation/player_statistics_screen.dart';
import '../../features/practice/data/models/practice_session.dart';
import '../../features/practice/presentation/practice_attendance_screen.dart';
import '../../features/practice/presentation/practice_session_detail_screen.dart';
import '../../features/practice/presentation/practice_session_form_screen.dart';
import '../../features/practice/presentation/practice_sessions_screen.dart';
import '../../features/public/data/models/public_post.dart';
import '../../features/public/presentation/public_fan_home_screen.dart';
import '../../features/public/presentation/public_fixtures_screen.dart';
import '../../features/public/presentation/public_live_match_screen.dart';
import '../../features/public/presentation/public_points_table_screen.dart';
import '../../features/public/presentation/public_posts_screen.dart';
import '../../features/public/presentation/public_rankings_screen.dart';
import '../../features/public/presentation/public_sponsors_screen.dart';
import '../../features/public/presentation/public_teams_screen.dart';
import '../../features/public/presentation/public_tournament_detail_screen.dart';
import '../../features/public/presentation/public_tournament_list_screen.dart';
import '../../features/scoring/presentation/live_scoring_screen.dart';
import '../../features/scoring/presentation/scoring_setup_screen.dart';
import '../../features/sponsors/presentation/sponsors_list_screen.dart';
import '../../features/tournament_applications/presentation/player_tournaments_screen.dart';
import '../../features/tournaments/data/models/tournament.dart';
import '../../features/tournaments/presentation/admin_home_screen.dart';
import '../../features/tournaments/presentation/create_tournament_screen.dart';
import '../../features/tournaments/presentation/tournament_detail_screen.dart';
import '../../features/teams/data/models/team.dart';
import '../../features/teams/presentation/team_detail_screen.dart';
import '../../features/venues/data/models/venue.dart';
import '../../features/venues/presentation/venue_availability_screen.dart';
import '../../features/venues/presentation/venues_list_screen.dart';

const splashPath = '/splash';
const loginPath = '/auth/login';
const registerPath = '/auth/register';
const selectOrgPath = '/auth/select-org';
const createOrgPath = '/auth/create-organization';
const joinOrgPath = '/auth/join-organization';
const adminHomePath = '/admin';

/// Home shell for a `player`-role user (see SessionState.role, decoded from
/// the active-org JWT claim) — parallel to [adminHomePath] for
/// org_admin/tournament_admin and other elevated roles, and to
/// [captainHomePath] for `team_owner`.
const playerHomePath = '/player';

/// The existing tournament browse/apply flow (see `PlayerTournamentsScreen`)
/// — no longer the entire player-facing app (see [playerHomePath]'s
/// `PlayerShellScreen`, the new 5-tab bottom-nav shell), but still fully
/// reachable: pushed from the Home tab's "Tournaments" section.
const playerTournamentsPath = '/player/tournaments';

/// Home shell for a `team_owner`-role user (see SessionState.role) — the
/// Captain App: a 5-tab bottom nav (Home/Squad/Matches/Practice/Profile)
/// consolidating the Captain Management functionality already built across
/// the admin-side team/match screens (see `CaptainHomeScreen`'s own doc
/// comment), parallel to [playerHomePath] for `player` and [adminHomePath]
/// for every other role.
const captainHomePath = '/captain';

/// The in-app Notification Center (see `NotificationCenterScreen`) — a
/// single shared route for the admin/player/captain home shells' bell
/// icons ([NotificationBell]), since notifications are scoped to the
/// caller's active org/user rather than to a role.
const notificationsPath = '/notifications';

String tournamentDetailPath(String tournamentId) => '/admin/tournaments/$tournamentId';

/// The 5-step create/edit tournament wizard (see `CreateTournamentScreen`).
/// One route handles both: pass `extra: <Tournament>` to open it in edit
/// mode pre-filled with that tournament's data, or no `extra` to create a
/// new one.
const createTournamentPath = '/admin/tournaments/create';

/// The 5-step player registration wizard (see `CreatePlayerScreen`),
/// replacing the old single-form `AddPlayerDialog`.
const createPlayerPath = '/admin/players/create';

/// Career/cross-match statistics for one player (see
/// `PlayerStatisticsScreen`). Always pushed with `extra: <Player>` from
/// PlayerListTab's "View statistics" menu action, which already has the
/// full `Player` (photo/name/role) loaded — there's no fallback
/// single-player fetch for a cold deep-link, same as e.g.
/// `lineupSelectionPath`, which is likewise only ever reached from within
/// the app rather than externally linked.
String playerStatisticsPath(String playerId) => '/admin/players/$playerId/statistics';

String auctionSessionListPath(String tournamentId) => '/admin/tournaments/$tournamentId/auction';

String auctionSessionDetailPath(String tournamentId, String sessionId) =>
    '/admin/tournaments/$tournamentId/auction/$sessionId';

String auctionReportPath(String tournamentId, String sessionId) =>
    '/admin/tournaments/$tournamentId/auction/$sessionId/report';

/// Player-by-player table with a drill-down into each player's full bid
/// history (see [auctionPlayerBidHistoryPath]) — see `AuctionHistoryScreen`.
String auctionHistoryPath(String tournamentId, String sessionId) =>
    '/admin/tournaments/$tournamentId/auction/$sessionId/history';

/// One player's complete bid history within one session — see
/// `AuctionPlayerBidHistoryScreen`. Optionally pushed with `extra: <String>`
/// (the player's name) from AuctionHistoryScreen, which already has it
/// loaded, so the app bar has a title before this screen's own fetch
/// resolves.
String auctionPlayerBidHistoryPath(String tournamentId, String sessionId, String playerId) =>
    '/admin/tournaments/$tournamentId/auction/$sessionId/history/$playerId';

/// Per-team purse/spend/squad standing plus purchased-players lists for one
/// session — see `AuctionTeamDashboardScreen`.
String auctionTeamDashboardPath(String tournamentId, String sessionId) =>
    '/admin/tournaments/$tournamentId/auction/$sessionId/teams';

/// Team detail — always reached from within a tournament's Teams tab (see
/// TeamListTab), so a team's auction/roster context can be scoped to that
/// tournament (e.g. its Auction tab).
String teamDetailPath(String tournamentId, String teamId) =>
    '/admin/tournaments/$tournamentId/teams/$teamId';

/// The match create/edit form (see `MatchFormScreen`). One route handles
/// both: pass `extra: <Match>` to open it in edit mode pre-filled with that
/// match's data, or no `extra` to create a new one — same pattern as
/// [createTournamentPath].
String matchFormPath(String tournamentId) => '/admin/tournaments/$tournamentId/matches/form';

String matchDetailPath(String tournamentId, String matchId) =>
    '/admin/tournaments/$tournamentId/matches/$matchId';

/// "Select Playing XI" for one side (home or away, identified by
/// `tournamentTeamId`) of a match — see LineupSelectionScreen.
String lineupSelectionPath(String tournamentId, String matchId, String tournamentTeamId) =>
    '/admin/tournaments/$tournamentId/matches/$matchId/lineup/$tournamentTeamId';

/// One-time setup step before ball-by-ball scoring can begin — collects the
/// opening pair/bowler for the first or second innings (see
/// `ScoringSetupScreen`). Pass `extra: <ScoringSetupArgs>`.
String scoringSetupPath(String tournamentId, String matchId) =>
    '/admin/tournaments/$tournamentId/matches/$matchId/scoring/setup';

/// The live ball-by-ball scoring screen (see `LiveScoringScreen`) — reached
/// once a match's status is `live`.
String liveScoringPath(String tournamentId, String matchId) =>
    '/admin/tournaments/$tournamentId/matches/$matchId/scoring';

/// The read-only tabbed Match Center (see `MatchCenterScreen`) — full
/// scorecard/stats view, reached from `MatchDetailScreen` once a match is
/// `live` or `completed`.
String matchCenterPath(String tournamentId, String matchId) =>
    '/admin/tournaments/$tournamentId/matches/$matchId/center';

/// Finance transaction list/filter for one tournament (see
/// `FinanceTransactionsScreen`) — tournament-scoped like Points
/// Table/Matches, not a top-level org-wide screen.
String financeTransactionsPath(String tournamentId) => '/admin/tournaments/$tournamentId/finance';

/// The finance transaction create/edit form (see
/// `FinanceTransactionFormScreen`). One route handles both: pass
/// `extra: <FinanceTransaction>` to open it in edit mode pre-filled with
/// that transaction's data, or no `extra` to create a new one — same
/// pattern as [matchFormPath].
String financeTransactionFormPath(String tournamentId) =>
    '/admin/tournaments/$tournamentId/finance/form';

/// A single finance transaction's detail/"receipt" view (see
/// `FinanceTransactionDetailScreen`).
String financeTransactionDetailPath(String tournamentId, String transactionId) =>
    '/admin/tournaments/$tournamentId/finance/$transactionId';

/// Per-registered-team registration fee owed (see `FinanceTeamFeesScreen`).
String financeTeamFeesPath(String tournamentId) => '/admin/tournaments/$tournamentId/finance/team-fees';

/// Per-registered-player registration fee owed (see
/// `FinancePlayerFeesScreen`).
String financePlayerFeesPath(String tournamentId) =>
    '/admin/tournaments/$tournamentId/finance/player-fees';

/// Org-level coach CRUD (see CoachesListScreen) — not tournament- or
/// team-scoped.
const coachesListPath = '/admin/coaches';

/// Org-level venue CRUD (see VenuesListScreen) — not tournament- or
/// team-scoped, same as [coachesListPath].
const venuesListPath = '/admin/venues';

/// Day-by-day availability calendar for one venue (see
/// VenueAvailabilityScreen), reached from VenuesListScreen's per-row
/// calendar action.
String venueAvailabilityPath(String venueId) => '/admin/venues/$venueId/availability';

/// Org-level official (umpire/scorer/match referee) CRUD (see
/// OfficialsListScreen) — not tournament- or team-scoped, same as
/// [coachesListPath].
const officialsListPath = '/admin/officials';

/// Org-level sponsor CRUD (see SponsorsListScreen) — not tournament- or
/// team-scoped, same as [coachesListPath].
const sponsorsListPath = '/admin/sponsors';

/// Practice sessions are team-scoped, not tournament-scoped (unlike
/// matches — see PracticeSession entity's doc comment), so these routes
/// hang off `/admin/teams/:teamId/practice` rather than under a tournament.
/// Reused both as PracticeSessionsScreen (the admin drawer's "Practice"
/// jump-in target) and embedded inside TeamDetailScreen's Coach tab (see
/// TeamCoachTab).
String practiceSessionsPath(String teamId) => '/admin/teams/$teamId/practice';

/// The practice session create/edit form (see `PracticeSessionFormScreen`).
/// One route handles both: pass `extra: <PracticeSession>` to open it in
/// edit mode, or no `extra` to create a new one — same pattern as
/// [matchFormPath].
String practiceSessionFormPath(String teamId) => '/admin/teams/$teamId/practice/form';

String practiceSessionDetailPath(String teamId, String sessionId) =>
    '/admin/teams/$teamId/practice/$sessionId';

String practiceAttendancePath(String teamId, String sessionId) =>
    '/admin/teams/$teamId/practice/$sessionId/attendance';

// --- Public "Fan" section (see features/public/) ---
//
// A fully unauthenticated, read-only browse area wired to
// `apps/backend/src/modules/public/...` — no Authorization header is
// required by any route under this prefix (see PublicModule's doc comment
// on the backend). The phase-1 entry point is AdminDrawer's "Preview as
// Fan" item, which already has `organizationId` from the caller's own
// active org — there is no public "discover organizations" endpoint yet, so
// a cold/anonymous entry point (e.g. an external deep link with no prior
// app session) isn't wired up. These routes are still made reachable while
// `AuthStatus.unauthenticated` (see the redirect switch below) purely so a
// future entry point can reuse them without another router change.

String publicFanHomePath(String organizationId) => '/public/organizations/$organizationId';

String publicTournamentListPath(String organizationId) =>
    '${publicFanHomePath(organizationId)}/tournaments';

String publicTournamentDetailPath(String organizationId, String tournamentId) =>
    '${publicTournamentListPath(organizationId)}/$tournamentId';

String publicTeamsPath(String organizationId, String tournamentId) =>
    '${publicTournamentDetailPath(organizationId, tournamentId)}/teams';

/// Fixtures & Results — one screen, two client-side-filtered tabs (see
/// `PublicFixturesScreen`).
String publicFixturesPath(String organizationId, String tournamentId) =>
    '${publicTournamentDetailPath(organizationId, tournamentId)}/fixtures';

String publicPointsTablePath(String organizationId, String tournamentId) =>
    '${publicTournamentDetailPath(organizationId, tournamentId)}/points-table';

/// The full public live-score view for one match (see
/// `PublicLiveMatchScreen`) — reached from the Fan Home screen's LIVE NOW
/// card or a `live`-status match card in Fixtures & Results.
String publicLiveMatchPath(String organizationId, String tournamentId, String matchId) =>
    '${publicTournamentDetailPath(organizationId, tournamentId)}/matches/$matchId/live';

/// Org-wide player leaderboard — not tournament-scoped, matching
/// `PublicPlayersController.getRankings`.
String publicRankingsPath(String organizationId) => '${publicFanHomePath(organizationId)}/rankings';

/// News/Photos/Videos tabs (see `PublicPostsScreen`) — pass
/// `extra: <PublicPostType>` to open on a specific tab, or no `extra` to
/// default to News.
String publicPostsPath(String organizationId) => '${publicFanHomePath(organizationId)}/posts';

String publicSponsorsPath(String organizationId) => '${publicFanHomePath(organizationId)}/sponsors';

/// True for any location under the public fan section — these routes take a
/// dynamic `organizationId` segment, so (unlike `loginPath`/`registerPath`)
/// they can't be checked as exact-string matches in the redirect switch
/// below.
bool _isPublicFanRoute(String location) => location.startsWith('/public/organizations/');

/// Bridges Riverpod's [SessionState] changes to go_router's
/// `refreshListenable`, so route redirects re-evaluate whenever auth status
/// changes (login, logout, org selection, session expiry).
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    _ref.listen<AuthStatus>(
      sessionControllerProvider.select((s) => s.status),
      (previous, next) => notifyListeners(),
      fireImmediately: false,
    );
  }

  final Ref _ref;

  AuthStatus get status => _ref.read(sessionControllerProvider).status;

  /// The caller's active-org role (e.g. `org_admin`, `player`), read fresh
  /// on every redirect evaluation — role and status always change together
  /// (see SessionController._selectOrgAndFinish), so the `status` listener
  /// above is enough to trigger re-evaluation; no separate listener needed.
  String? get role => _ref.read(sessionControllerProvider).role;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: splashPath,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final status = refreshNotifier.status;
      final location = state.matchedLocation;

      switch (status) {
        case AuthStatus.unknown:
          return location == splashPath ? null : splashPath;
        case AuthStatus.unauthenticated:
          // The public fan section is reachable logged-out too — see the
          // "Public Fan section" doc comment above `publicFanHomePath`.
          return (location == loginPath ||
                  location == registerPath ||
                  _isPublicFanRoute(location))
              ? null
              : loginPath;
        case AuthStatus.needsOrgSelection:
          // joinOrgPath and createOrgPath are reachable from here too —
          // OrgSelectScreen's "Join with a code" and "New organization" FABs
          // are alternatives to picking one of the caller's existing
          // memberships.
          return (location == selectOrgPath ||
                  location == joinOrgPath ||
                  location == createOrgPath)
              ? null
              : selectOrgPath;
        case AuthStatus.needsOrgCreation:
          // joinOrgPath is reachable from here too — CreateOrganizationScreen's
          // "Join an organization with a code" option (an alternative to
          // creating a brand-new org).
          return (location == createOrgPath || location == joinOrgPath) ? null : createOrgPath;
        case AuthStatus.authenticated:
          final onPreAuthRoute = location == splashPath ||
              location == loginPath ||
              location == registerPath ||
              location == selectOrgPath ||
              location == createOrgPath ||
              location == joinOrgPath;
          if (!onPreAuthRoute) return null;
          // (A public fan route reaches here too — it's simply not in the
          // onPreAuthRoute list above, so it falls into the `return null`
          // just taken and is left alone, same as every other in-app route.
          // This is what lets an authenticated admin use "Preview as Fan"
          // without being bounced back to their own role's home screen.)
          // `player`-role members land on the player dashboard, `team_owner`
          // lands on the Captain App, and every other role (org_admin,
          // tournament_admin, scorer, ...) keeps going to the existing admin
          // home, unchanged.
          return switch (refreshNotifier.role) {
            'player' => playerHomePath,
            'team_owner' => captainHomePath,
            _ => adminHomePath,
          };
      }
    },
    routes: [
      GoRoute(path: splashPath, builder: (context, state) => const SplashScreen()),
      GoRoute(path: loginPath, builder: (context, state) => const LoginScreen()),
      GoRoute(path: registerPath, builder: (context, state) => const RegisterScreen()),
      GoRoute(path: selectOrgPath, builder: (context, state) => const OrgSelectScreen()),
      GoRoute(path: createOrgPath, builder: (context, state) => const CreateOrganizationScreen()),
      GoRoute(path: joinOrgPath, builder: (context, state) => const JoinOrganizationScreen()),
      GoRoute(path: adminHomePath, builder: (context, state) => const AdminHomeScreen()),
      GoRoute(path: playerHomePath, builder: (context, state) => const PlayerShellScreen()),
      GoRoute(
        path: playerTournamentsPath,
        builder: (context, state) => const PlayerTournamentsScreen(),
      ),
      GoRoute(path: captainHomePath, builder: (context, state) => const CaptainHomeScreen()),
      GoRoute(path: notificationsPath, builder: (context, state) => const NotificationCenterScreen()),
      GoRoute(
        path: createTournamentPath,
        builder: (context, state) => CreateTournamentScreen(
          existing: state.extra is Tournament ? state.extra as Tournament : null,
        ),
      ),
      GoRoute(
        path: createPlayerPath,
        builder: (context, state) => const CreatePlayerScreen(),
      ),
      GoRoute(
        path: '/admin/players/:playerId/statistics',
        builder: (context, state) => PlayerStatisticsScreen(player: state.extra! as Player),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId',
        builder: (context, state) => TournamentDetailScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          // Optional deep-link into a specific tab — see AdminHomeScreen's
          // drawer, which pushes this route with `extra: <tab index>` for
          // "Teams"/"Players"/"Applications" when there's exactly one
          // tournament to jump into.
          initialTabIndex: state.extra is int ? state.extra as int : 0,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/teams/:teamId',
        builder: (context, state) => TeamDetailScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          teamId: state.pathParameters['teamId']!,
          // Passed by TeamListTab, which already has the full Team loaded —
          // avoids a redundant fetch. Null on a cold deep-link; the screen
          // falls back to `teamDetailProvider` in that case.
          initialTeam: state.extra is Team ? state.extra as Team : null,
        ),
      ),
      GoRoute(
        // Static segment declared before the ':matchId' route below so it
        // matches first — go_router tests top-level routes in list order.
        path: '/admin/tournaments/:tournamentId/matches/form',
        builder: (context, state) => MatchFormScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          existing: state.extra is Match ? state.extra as Match : null,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/matches/:matchId',
        builder: (context, state) => MatchDetailScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          matchId: state.pathParameters['matchId']!,
          initialMatch: state.extra is Match ? state.extra as Match : null,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/matches/:matchId/lineup/:tournamentTeamId',
        builder: (context, state) => LineupSelectionScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          matchId: state.pathParameters['matchId']!,
          tournamentTeamId: state.pathParameters['tournamentTeamId']!,
        ),
      ),
      GoRoute(
        // Static/longer segments declared before the parent ':matchId'
        // route isn't actually required here (these paths are strictly
        // longer than '/matches/:matchId', so there's no ambiguity) — kept
        // adjacent to the lineup route purely for readability.
        path: '/admin/tournaments/:tournamentId/matches/:matchId/scoring/setup',
        builder: (context, state) => ScoringSetupScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          matchId: state.pathParameters['matchId']!,
          args: state.extra as ScoringSetupArgs,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/matches/:matchId/scoring',
        builder: (context, state) => LiveScoringScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          matchId: state.pathParameters['matchId']!,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/matches/:matchId/center',
        builder: (context, state) => MatchCenterScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          matchId: state.pathParameters['matchId']!,
        ),
      ),
      GoRoute(path: coachesListPath, builder: (context, state) => const CoachesListScreen()),
      GoRoute(path: venuesListPath, builder: (context, state) => const VenuesListScreen()),
      GoRoute(
        path: '/admin/venues/:venueId/availability',
        builder: (context, state) => VenueAvailabilityScreen(
          venueId: state.pathParameters['venueId']!,
          initialVenue: state.extra is Venue ? state.extra as Venue : null,
        ),
      ),
      GoRoute(path: officialsListPath, builder: (context, state) => const OfficialsListScreen()),
      GoRoute(path: sponsorsListPath, builder: (context, state) => const SponsorsListScreen()),
      GoRoute(
        path: '/admin/teams/:teamId/practice',
        builder: (context, state) => PracticeSessionsScreen(
          teamId: state.pathParameters['teamId']!,
          initialTeam: state.extra is Team ? state.extra as Team : null,
        ),
      ),
      GoRoute(
        // Static segment declared before the ':sessionId' route below so it
        // matches first — go_router tests top-level routes in list order,
        // same trick as the matches form route above.
        path: '/admin/teams/:teamId/practice/form',
        builder: (context, state) => PracticeSessionFormScreen(
          teamId: state.pathParameters['teamId']!,
          existing: state.extra is PracticeSession ? state.extra as PracticeSession : null,
        ),
      ),
      GoRoute(
        path: '/admin/teams/:teamId/practice/:sessionId',
        builder: (context, state) => PracticeSessionDetailScreen(
          teamId: state.pathParameters['teamId']!,
          sessionId: state.pathParameters['sessionId']!,
          initialSession: state.extra is PracticeSession ? state.extra as PracticeSession : null,
        ),
      ),
      GoRoute(
        path: '/admin/teams/:teamId/practice/:sessionId/attendance',
        builder: (context, state) => PracticeAttendanceScreen(
          teamId: state.pathParameters['teamId']!,
          sessionId: state.pathParameters['sessionId']!,
          initialSession: state.extra is PracticeSession ? state.extra as PracticeSession : null,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/auction',
        builder: (context, state) => AuctionSessionListScreen(
          tournamentId: state.pathParameters['tournamentId']!,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/auction/:sessionId',
        builder: (context, state) => AuctionSessionDetailScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/auction/:sessionId/report',
        builder: (context, state) => AuctionReportScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/auction/:sessionId/history',
        builder: (context, state) => AuctionHistoryScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/auction/:sessionId/history/:playerId',
        builder: (context, state) => AuctionPlayerBidHistoryScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          sessionId: state.pathParameters['sessionId']!,
          playerId: state.pathParameters['playerId']!,
          playerName: state.extra is String ? state.extra as String : null,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/auction/:sessionId/teams',
        builder: (context, state) => AuctionTeamDashboardScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/finance',
        builder: (context, state) => FinanceTransactionsScreen(
          tournamentId: state.pathParameters['tournamentId']!,
        ),
      ),
      GoRoute(
        // Static segments declared before the ':transactionId' route below
        // so they match first — go_router tests top-level routes in list
        // order, same trick as the matches/practice form routes above.
        path: '/admin/tournaments/:tournamentId/finance/form',
        builder: (context, state) => FinanceTransactionFormScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          existing: state.extra is FinanceTransaction ? state.extra as FinanceTransaction : null,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/finance/team-fees',
        builder: (context, state) => FinanceTeamFeesScreen(
          tournamentId: state.pathParameters['tournamentId']!,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/finance/player-fees',
        builder: (context, state) => FinancePlayerFeesScreen(
          tournamentId: state.pathParameters['tournamentId']!,
        ),
      ),
      GoRoute(
        path: '/admin/tournaments/:tournamentId/finance/:transactionId',
        builder: (context, state) => FinanceTransactionDetailScreen(
          tournamentId: state.pathParameters['tournamentId']!,
          transactionId: state.pathParameters['transactionId']!,
          initialTransaction:
              state.extra is FinanceTransaction ? state.extra as FinanceTransaction : null,
        ),
      ),
      // --- Public "Fan" section — see the doc comment above
      // publicFanHomePath for the entry-point/auth-reachability rationale.
      GoRoute(
        path: '/public/organizations/:organizationId',
        builder: (context, state) => PublicFanHomeScreen(
          organizationId: state.pathParameters['organizationId']!,
          organizationName: state.extra is String ? state.extra as String : null,
        ),
      ),
      GoRoute(
        path: '/public/organizations/:organizationId/tournaments',
        builder: (context, state) => PublicTournamentListScreen(
          organizationId: state.pathParameters['organizationId']!,
        ),
      ),
      GoRoute(
        path: '/public/organizations/:organizationId/tournaments/:tournamentId',
        builder: (context, state) => PublicTournamentDetailScreen(
          organizationId: state.pathParameters['organizationId']!,
          tournamentId: state.pathParameters['tournamentId']!,
        ),
      ),
      GoRoute(
        path: '/public/organizations/:organizationId/tournaments/:tournamentId/teams',
        builder: (context, state) => PublicTeamsScreen(
          organizationId: state.pathParameters['organizationId']!,
          tournamentId: state.pathParameters['tournamentId']!,
        ),
      ),
      GoRoute(
        path: '/public/organizations/:organizationId/tournaments/:tournamentId/fixtures',
        builder: (context, state) => PublicFixturesScreen(
          organizationId: state.pathParameters['organizationId']!,
          tournamentId: state.pathParameters['tournamentId']!,
        ),
      ),
      GoRoute(
        path: '/public/organizations/:organizationId/tournaments/:tournamentId/points-table',
        builder: (context, state) => PublicPointsTableScreen(
          organizationId: state.pathParameters['organizationId']!,
          tournamentId: state.pathParameters['tournamentId']!,
        ),
      ),
      GoRoute(
        path:
            '/public/organizations/:organizationId/tournaments/:tournamentId/matches/:matchId/live',
        builder: (context, state) => PublicLiveMatchScreen(
          organizationId: state.pathParameters['organizationId']!,
          tournamentId: state.pathParameters['tournamentId']!,
          matchId: state.pathParameters['matchId']!,
        ),
      ),
      GoRoute(
        path: '/public/organizations/:organizationId/rankings',
        builder: (context, state) => PublicRankingsScreen(
          organizationId: state.pathParameters['organizationId']!,
        ),
      ),
      GoRoute(
        path: '/public/organizations/:organizationId/posts',
        builder: (context, state) => PublicPostsScreen(
          organizationId: state.pathParameters['organizationId']!,
          initialType: state.extra is PublicPostType ? state.extra as PublicPostType : null,
        ),
      ),
      GoRoute(
        path: '/public/organizations/:organizationId/sponsors',
        builder: (context, state) => PublicSponsorsScreen(
          organizationId: state.pathParameters['organizationId']!,
        ),
      ),
    ],
  );
});
