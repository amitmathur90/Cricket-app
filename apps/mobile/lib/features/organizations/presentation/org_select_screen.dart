import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth/application/session_controller.dart';

/// Shown when the logged-in user is an active member of more than one
/// organization and the access token has no unambiguous `activeOrgId`
/// claim — see SessionController._resolveOrgSelection.
class OrgSelectScreen extends ConsumerWidget {
  const OrgSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    ref.listen<SessionState>(sessionControllerProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose an organization'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: session.memberships.isEmpty
          ? const Center(child: Text('No organizations found.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: session.memberships.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final membership = session.memberships[index];
                final org = membership.organization;
                return Card(
                  child: ListTile(
                    title: Text(org?.name ?? membership.organizationId),
                    subtitle: Text('Role: ${membership.role}'),
                    trailing: session.isBusy ? const CircularProgressIndicator() : const Icon(Icons.chevron_right),
                    onTap: session.isBusy
                        ? null
                        : () => ref
                            .read(sessionControllerProvider.notifier)
                            .selectOrg(membership.organizationId),
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'discover-tournaments',
            onPressed: session.isBusy ? null : () => context.push(discoverTournamentsPath),
            icon: const Icon(Icons.travel_explore_outlined),
            label: const Text('Discover tournaments'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'join-org',
            onPressed: session.isBusy ? null : () => context.push(joinOrgPath),
            icon: const Icon(Icons.qr_code),
            label: const Text('Join with a code'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'new-org',
            onPressed: session.isBusy ? null : () => context.push(createOrgPath),
            icon: const Icon(Icons.add),
            label: const Text('New organization'),
          ),
        ],
      ),
    );
  }
}
