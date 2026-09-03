import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_session_coordinator.dart';
import '../../../core/auth/session_validation.dart';
import '../../../core/services/device_token_sync_service.dart';
import '../../../data/models/session.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/services/api_client.dart';
import '../../../features/auth/logic/splash_login_check.dart';
import '../../../routes/app_routes.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authRepository) {
    AuthSessionCoordinator.instance.bind(
      clearLocalAuth: () async {
        await _wipeLocalAuth();
        notifyListeners();
      },
    );
    ApiClient.accessTokenProvider = () => _session?.accessToken;
  }

  final AuthRepository _authRepository;

  bool _bootstrapped = false;
  bool get bootstrapped => _bootstrapped;

  /// True while startup validation is in progress (intro stays visible).
  bool _bootstrapping = false;
  bool get bootstrapping => _bootstrapping;

  Session? _session;
  Session? get session => _session;
  bool get isAuthenticated => _session != null;

  /// Selected role before completing registration (terms flow).
  UserRole? registrationRole;

  /// Soft load: does **not** mark the user authenticated until [bootstrapSession]
  /// validates credentials (or login/register succeeds).
  Future<void> loadSession() async {
    // Intentionally leave `_session` null here so routers do not enter
    // authenticated homes based solely on a restored prefs blob.
    _bootstrapped = false;
    _bootstrapping = true;
    notifyListeners();
  }

  /// Validate stored credentials (or confirm none), then return the post-intro route.
  ///
  /// - valid session → role home
  /// - missing/invalid → splash (logged out)
  /// - unreachable → throws [SessionUnreachableException] so UI can Retry
  Future<String> bootstrapSession() async {
    _bootstrapping = true;
    notifyListeners();

    try {
      final result = await _authRepository.validateStoredSession();
      switch (result.status) {
        case SessionValidationStatus.none:
        case SessionValidationStatus.invalid:
          await _wipeLocalAuth();
          _bootstrapped = true;
          _bootstrapping = false;
          notifyListeners();
          return AppRoutes.splash;
        case SessionValidationStatus.valid:
          _session = result.session;
          _bootstrapped = true;
          _bootstrapping = false;
          notifyListeners();
          final s = _session!;
          unawaited(DeviceTokenSyncService.instance.syncWithSession(s));
          return homeRouteForSession(s);
        case SessionValidationStatus.unreachable:
          _bootstrapped = false;
          _bootstrapping = false;
          notifyListeners();
          throw const SessionUnreachableException();
      }
    } catch (e) {
      if (e is SessionUnreachableException) rethrow;
      _bootstrapped = false;
      _bootstrapping = false;
      notifyListeners();
      throw const SessionUnreachableException();
    }
  }

  Future<void> loginAs(String email, String password, UserRole role) async {
    final s = await _authRepository.login(email: email, password: password, roleHint: role);
    _session = s;
    _bootstrapped = true;
    _bootstrapping = false;
    notifyListeners();
    unawaited(DeviceTokenSyncService.instance.syncWithSession(s));
  }

  /// Dev-friendly sign-in matching prototype “Sign In” without backend.
  Future<void> quickLogin(UserRole role) async {
    await loginAs('driver@fleetco.co.uk', '', role);
  }

  /// Shared wipe used by logout, delete-account, and 401 invalidation.
  Future<void> _wipeLocalAuth() async {
    _session = null;
    registrationRole = null;
    await _authRepository.clearSession();
    await DeviceTokenSyncService.instance.clearLastSync();
  }

  Future<void> logout() async {
    final access = _session?.accessToken;
    final refresh = _session?.refreshToken;
    // Clear local state first so UI cannot keep using a dead session.
    await _wipeLocalAuth();
    notifyListeners();
    try {
      await _authRepository.logout(accessToken: access, refreshToken: refresh);
    } catch (_) {
      // Best-effort server logout; local wipe already completed.
    }
  }

  /// Permanently deletes the signed-in account (Apple Guideline 5.1.1(v)).
  Future<void> deleteAccount({required String password}) async {
    final token = _session?.accessToken?.trim();
    if (token == null || token.isEmpty) {
      throw Exception('Not signed in');
    }
    final pwd = password.trim();
    if (pwd.isEmpty) {
      throw Exception('Password is required');
    }
    await _authRepository.deleteAccount(accessToken: token, password: pwd);
    await _wipeLocalAuth();
    // Defer so callers can navigate before GoRouter tears down the current tree.
    scheduleMicrotask(() {
      if (hasListeners) notifyListeners();
    });
  }

  Future<void> completeRegistration(UserRole role, {String email = 'new@truckfix.app'}) async {
    await loginAs(email, '', role);
    registrationRole = null;
    notifyListeners();
  }

  void setRegistrationRole(UserRole role) {
    registrationRole = role;
    notifyListeners();
  }

  void clearRegistrationRole() {
    registrationRole = null;
    notifyListeners();
  }

  /// Apply a session returned from register/login APIs (already persisted).
  Future<void> adoptSession(Session session) async {
    _session = session;
    registrationRole = null;
    _bootstrapped = true;
    _bootstrapping = false;
    notifyListeners();
    unawaited(DeviceTokenSyncService.instance.syncWithSession(session));
  }

  /// After accepting a company invite — merge returned user into the session.
  /// Role should become [UserRole.employee] when the backend confirms it.
  Future<Session> applyInviteAcceptResponse(Map<String, dynamic> body) async {
    final updated = await _authRepository.mergeSessionFromAuthBody(
      body,
      roleHint: UserRole.employee,
    );
    _session = updated;
    registrationRole = null;
    notifyListeners();
    unawaited(DeviceTokenSyncService.instance.syncWithSession(updated));
    return updated;
  }
}
