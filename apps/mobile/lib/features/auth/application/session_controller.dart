import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/jwt.dart';
import '../../organizations/data/models/org_membership.dart';
import '../data/auth_repository.dart';
import '../data/models/safe_user.dart';
import 'auth_providers.dart';

/// Where the router should send the user, driven entirely by
/// [SessionState.status] — see `core/router/app_router.dart`.
enum AuthStatus {
  /// Still resolving stored tokens on app start.
  unknown,
  unauthenticated,

  /// Logged in, but the access token has no `activeOrgId` claim and the
  /// user has more than one active org membership to choose from.
  needsOrgSelection,

  /// Logged in, no `activeOrgId` claim, and zero active org memberships —
  /// a brand-new user with no organization yet.
  needsOrgCreation,
  authenticated,
}

class SessionState {
  const SessionState({
    this.status = AuthStatus.unknown,
    this.user,
    this.activeOrgId,
    this.role,
    this.memberships = const [],
    this.isBusy = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final SafeUser? user;
  final String? activeOrgId;
  final String? role;
  final List<OrgMembership> memberships;
  final bool isBusy;
  final String? errorMessage;

  SessionState copyWith({
    AuthStatus? status,
    SafeUser? user,
    String? activeOrgId,
    String? role,
    List<OrgMembership>? memberships,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      user: user ?? this.user,
      activeOrgId: activeOrgId ?? this.activeOrgId,
      role: role ?? this.role,
      memberships: memberships ?? this.memberships,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Owns the app's auth/session lifecycle: bootstrapping from stored tokens
/// on launch, login/register, org selection/creation, and logout. The
/// go_router redirect logic in `core/router/app_router.dart` reacts purely
/// to `state.status`.
class SessionController extends StateNotifier<SessionState> {
  SessionController(this._ref) : super(const SessionState()) {
    // core/network raises this signal when a refresh attempt fails (see
    // ApiClient.onSessionExpired / network_providers.dart) — core never
    // imports this feature directly, so we listen instead.
    _ref.listen<int>(sessionExpiredSignalProvider, (previous, next) {
      if (previous != null && next != previous) {
        handleSessionExpired();
      }
    });
    unawaited(_bootstrap());
  }

  final Ref _ref;

  AuthRepository get _authRepository => _ref.read(authRepositoryProvider);
  TokenStorage get _tokenStorage => _ref.read(tokenStorageProvider);

  Future<void> _bootstrap() async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    await _resolveFromAccessToken(accessToken);
  }

  /// Given a freshly-issued or stored access token, figures out whether the
  /// app can go straight to the authenticated admin area, or needs to route
  /// through org selection/creation first.
  Future<void> _resolveFromAccessToken(String accessToken) async {
    try {
      final claims = decodeJwtPayload(accessToken);
      final activeOrgId = claims['activeOrgId'] as String?;
      final role = claims['role'] as String?;
      final user = await _authRepository.me();

      if (activeOrgId != null) {
        state = SessionState(
          status: AuthStatus.authenticated,
          user: user,
          activeOrgId: activeOrgId,
          role: role,
        );
        return;
      }

      await _resolveOrgSelection(user);
    } catch (_) {
      await _tokenStorage.clear();
      state = const SessionState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _resolveOrgSelection(SafeUser user) async {
    final memberships = await _authRepository.myMemberships();
    final activeMemberships = memberships.where((m) => m.isActive).toList();

    if (activeMemberships.isEmpty) {
      state = SessionState(
        status: AuthStatus.needsOrgCreation,
        user: user,
        memberships: memberships,
      );
      return;
    }

    if (activeMemberships.length == 1) {
      await _selectOrgAndFinish(activeMemberships.first.organizationId, user: user);
      return;
    }

    state = SessionState(
      status: AuthStatus.needsOrgSelection,
      user: user,
      memberships: activeMemberships,
    );
  }

  Future<void> _selectOrgAndFinish(String organizationId, {required SafeUser user}) async {
    final newAccessToken = await _authRepository.selectOrg(organizationId);
    await _tokenStorage.saveAccessToken(newAccessToken);
    final claims = decodeJwtPayload(newAccessToken);
    state = SessionState(
      status: AuthStatus.authenticated,
      user: user,
      activeOrgId: organizationId,
      role: claims['role'] as String?,
    );
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final result = await _authRepository.login(email: email, password: password);
      await _tokenStorage.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      await _resolveFromAccessToken(result.accessToken);
    } on ApiException catch (e) {
      state = state.copyWith(
        isBusy: false,
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final result = await _authRepository.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      await _tokenStorage.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      await _resolveFromAccessToken(result.accessToken);
    } on ApiException catch (e) {
      state = state.copyWith(
        isBusy: false,
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
    }
  }

  Future<void> selectOrg(String organizationId) async {
    final user = state.user;
    if (user == null) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _selectOrgAndFinish(organizationId, user: user);
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, errorMessage: e.message);
    }
  }

  /// Called right after `POST /organizations` succeeds (see
  /// CreateOrganizationScreen) — the creator is already an active
  /// `org_admin` member of the new org, so this just selects it.
  Future<void> onOrganizationCreated(String organizationId) => selectOrg(organizationId);

  Future<void> handleSessionExpired() async {
    await _tokenStorage.clear();
    state = const SessionState(status: AuthStatus.unauthenticated);
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
    state = const SessionState(status: AuthStatus.unauthenticated);
  }
}

final sessionControllerProvider = StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(ref);
});
