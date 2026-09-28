import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/session_controller.dart';
import '../../notifications/presentation/widgets/notification_bell.dart';
import '../../organizations/application/organizations_providers.dart';
import '../application/tournaments_providers.dart';
import '../data/models/tournament.dart';
import 'widgets/admin_drawer.dart';
import 'widgets/dashboard_overview.dart';

/// Admin dashboard — the first `/admin/*` screen an org_admin /
/// tournament_admin (and other elevated roles) sees. Mobile translation of a
/// desktop dashboard mockup (sidebar nav + top bar + stat cards + content
/// sections): the permanent sidebar becomes a [AdminDrawer] hamburger menu,
/// and the body is a stat-card overview ([DashboardOverview]) followed by
/// this org's join code and tournament list (unchanged capability from the
/// screen this replaced — just re-homed under the new dashboard framing
/// instead of being the entire screen).
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  bool _searching = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _query = '';
      }
    });
  }

  Future<void> _deleteTournament(BuildContext context, WidgetRef ref, Tournament tournament) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete tournament?'),
        content: Text(
          'This permanently deletes "${tournament.name}" and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(tournamentsRepositoryProvider)
          .delete(tournament.organizationId, tournament.id);
      ref.invalidate(tournamentsListProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _copyJoinCode(BuildContext context, String joinCode) async {
    await Clipboard.setData(ClipboardData(text: joinCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Join code copied')));
  }

  Future<void> _regenerateJoinCode(BuildContext context, WidgetRef ref, String organizationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate join code?'),
        content: const Text(
          'The current join code will stop working immediately. Anyone who still needs to '
          'join will need the new code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(organizationsRepositoryProvider).regenerateJoinCode(organizationId);
      ref.invalidate(activeOrganizationProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final tournamentsAsync = ref.watch(tournamentsListProvider);
    final organizationAsync = ref.watch(activeOrganizationProvider);
    final organizationId = session.activeOrgId;
    final displayName = session.user?.fullName ?? session.user?.email ?? 'Admin';

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search tournaments…',
                  border: InputBorder.none,
                ),
                style: Theme.of(context).appBarTheme.titleTextStyle,
                onChanged: (value) => setState(() => _query = value),
              )
            : const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search tournaments',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          const NotificationBell(),
          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 18)),
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(sessionControllerProvider.notifier).logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  session.user?.email ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sign out'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(tournamentsListProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Dashboard 🏆',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'Welcome back, $displayName',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const DashboardOverview(),
            const SizedBox(height: 24),
            if (organizationId != null)
              organizationAsync.when(
                data: (organization) => organization?.joinCode == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _JoinCodeCard(
                          joinCode: organization!.joinCode!,
                          onCopy: () => _copyJoinCode(context, organization.joinCode!),
                          onRegenerate: () => _regenerateJoinCode(context, ref, organizationId),
                        ),
                      ),
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
              ),
            Text('Tournaments', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            tournamentsAsync.when(
              data: (tournaments) {
                final filtered = _query.trim().isEmpty
                    ? tournaments
                    : tournaments
                        .where((t) => t.name.toLowerCase().contains(_query.trim().toLowerCase()))
                        .toList();
                if (tournaments.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(child: Text('No tournaments yet. Tap + to create one.')),
                  );
                }
                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(child: Text('No tournaments match your search.')),
                  );
                }
                return Column(
                  children: [
                    for (final tournament in filtered) ...[
                      _TournamentTile(
                        tournament: tournament,
                        onDelete: () => _deleteTournament(context, ref, tournament),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(
                  child: Text(
                    error is ApiException ? error.message : 'Failed to load tournaments',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: organizationId == null
          ? null
          : FloatingActionButton(
              onPressed: () => _showCreateMenu(context),
              child: const Icon(Icons.add),
            ),
    );
  }

  void _showCreateMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bolt),
              title: const Text('Quick match'),
              subtitle: const Text('Start a match right now — no tournament setup'),
              onTap: () {
                Navigator.of(context).pop();
                context.push(quickMatchPath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events),
              title: const Text('Create tournament'),
              onTap: () {
                Navigator.of(context).pop();
                context.push(createTournamentPath);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets an org_admin see/share/regenerate the org's self-join code (see
/// OrganizationsController.join / regenerateJoinCode). Shown to any admin
/// who lands on this screen — regenerate is org_admin-only server-side, so
/// a tournament_admin tapping it just sees whatever error the API returns
/// (same "don't hide actions per-role in this M1 UI" convention as
/// PlayerListTab).
class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({required this.joinCode, required this.onCopy, required this.onRegenerate});

  final String joinCode;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.qr_code),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Join code', style: Theme.of(context).textTheme.labelMedium),
                  Text(
                    joinCode,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy join code',
              icon: const Icon(Icons.copy),
              onPressed: onCopy,
            ),
            IconButton(
              tooltip: 'Regenerate join code',
              icon: const Icon(Icons.refresh),
              onPressed: onRegenerate,
            ),
          ],
        ),
      ),
    );
  }
}

/// A tournament's card in the list — logo, name, date range, location,
/// teams-registered count, status/registration badges, and an edit/delete
/// actions menu. Tapping anywhere but the menu opens the tournament detail
/// screen (unchanged from before this redesign).
class _TournamentTile extends StatelessWidget {
  const _TournamentTile({required this.tournament, required this.onDelete});

  final Tournament tournament;
  final VoidCallback onDelete;

  static const _statusColors = {
    'draft': Colors.grey,
    'upcoming': Colors.blue,
    'live': Colors.green,
    'completed': Colors.blueGrey,
  };

  Color _registrationColor(RegistrationStatus status) => switch (status) {
        RegistrationStatus.notOpen => Colors.grey,
        RegistrationStatus.open => Colors.green,
        RegistrationStatus.closed => Colors.red,
      };

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColors[tournament.status] ?? Colors.grey;
    final registrationColor = _registrationColor(tournament.registrationStatus);
    final dateFormat = DateFormat.MMMd();
    final start = DateTime.tryParse(tournament.startDate);
    final end = DateTime.tryParse(tournament.endDate);
    final dateRange = (start != null && end != null)
        ? '${dateFormat.format(start)} – ${dateFormat.format(end)}'
        : '${tournament.startDate} to ${tournament.endDate}';
    final teamsLabel = tournament.numberOfTeams != null
        ? '${tournament.teamsCount}/${tournament.numberOfTeams} teams'
        : '${tournament.teamsCount} teams';
    final location = tournament.location?.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(tournamentDetailPath(tournament.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: tournament.logoUrl != null
                    ? NetworkImage(Env.mediaUrl(tournament.logoUrl!))
                    : null,
                child: tournament.logoUrl == null ? const Icon(Icons.emoji_events) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tournament.format.label} · $dateRange',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (location != null && location.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                location,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Badge(label: teamsLabel, color: Theme.of(context).colorScheme.outline),
                        _Badge(label: _capitalize(tournament.status), color: statusColor),
                        _Badge(
                          label: tournament.registrationStatus.label,
                          color: registrationColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Tournament actions',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      context.push(createTournamentPath, extra: tournament);
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small color-coded pill used for the status/registration-status/teams
/// badges on a tournament card.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
