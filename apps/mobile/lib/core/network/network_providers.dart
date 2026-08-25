import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import 'api_client.dart';
import 'uploads_repository.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Bumped whenever [ApiClient] detects that the refresh token is no longer
/// usable (expired/revoked/reused). `SessionController` (in the auth
/// feature) listens to this and clears session state / routes to login.
///
/// Living here — rather than having this layer import the auth feature
/// directly — keeps the dependency one-directional: features depend on
/// core, core never depends on a feature.
final sessionExpiredSignalProvider = StateProvider<int>((ref) => 0);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStorage: ref.watch(tokenStorageProvider),
    onSessionExpired: () async {
      ref.read(sessionExpiredSignalProvider.notifier).state++;
    },
  );
});

final uploadsRepositoryProvider = Provider<UploadsRepository>((ref) {
  return UploadsRepository(ref.watch(apiClientProvider));
});
