import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../application/public_providers.dart';

/// `GET public/organizations/:organizationId/sponsors` — only sponsors with
/// `visibleOnApp: true` (filtered server-side), name/logo/package only, no
/// financial or contract fields (see `PublicSponsor`'s doc comment).
class PublicSponsorsScreen extends ConsumerWidget {
  const PublicSponsorsScreen({super.key, required this.organizationId});

  final String organizationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sponsorsAsync = ref.watch(publicSponsorsProvider(organizationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Sponsors')),
      body: sponsorsAsync.when(
        data: (sponsors) {
          if (sponsors.isEmpty) {
            return const Center(child: Text('No sponsors to show yet.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(publicSponsorsProvider(organizationId).future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sponsors.length,
              itemBuilder: (context, index) {
                final sponsor = sponsors[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: sponsor.logoUrl != null
                          ? NetworkImage(Env.mediaUrl(sponsor.logoUrl!))
                          : null,
                      child: sponsor.logoUrl == null ? const Icon(Icons.handshake_outlined) : null,
                    ),
                    title: Text(sponsor.companyName),
                    subtitle: sponsor.packageName != null ? Text(sponsor.packageName!) : null,
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load sponsors'),
        ),
      ),
    );
  }
}
