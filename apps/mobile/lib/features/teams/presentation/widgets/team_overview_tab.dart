import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../organizations/application/organizations_providers.dart';
import '../../data/models/team.dart';

/// Real, currently-available team fields — everything on the org-level
/// `Team` record itself, plus the organization it belongs to. Squad/captain
/// aren't shown here (see the Squad/Captain tabs for why — no roster GET
/// endpoint exists yet).
class TeamOverviewTab extends ConsumerWidget {
  const TeamOverviewTab({super.key, required this.team});

  final Team team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizationAsync = ref.watch(activeOrganizationProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundImage:
                team.logoUrl != null ? NetworkImage(Env.mediaUrl(team.logoUrl!)) : null,
            child: team.logoUrl == null ? const Icon(Icons.shield, size: 36) : null,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            team.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        if (team.shortCode != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(team.shortCode!, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        const SizedBox(height: 24),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: const Text('Organization'),
                subtitle: Text(
                  organizationAsync.when(
                    data: (org) => org?.name ?? '—',
                    loading: () => 'Loading…',
                    error: (_, __) => '—',
                  ),
                ),
              ),
              if (team.shortCode != null)
                ListTile(
                  leading: const Icon(Icons.tag_outlined),
                  title: const Text('Short code'),
                  subtitle: Text(team.shortCode!),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "This team's squad and captain aren't available here yet — see the "
                    'Squad and Captain tabs for details.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
