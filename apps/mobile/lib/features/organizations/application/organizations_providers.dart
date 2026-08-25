import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/models/organization.dart';
import '../data/organizations_repository.dart';

final organizationsRepositoryProvider = Provider<OrganizationsRepository>((ref) {
  return OrganizationsRepository(ref.watch(apiClientProvider));
});

/// The caller's active organization (full record, including its join
/// code) — null when there's no active org yet. Used by AdminHomeScreen to
/// surface the join code for org_admins to share/regenerate.
final activeOrganizationProvider = FutureProvider.autoDispose<Organization?>((ref) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return null;
  return ref.watch(organizationsRepositoryProvider).getById(organizationId);
});
