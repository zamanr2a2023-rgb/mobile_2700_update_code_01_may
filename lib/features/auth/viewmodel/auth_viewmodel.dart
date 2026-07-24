import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/device_token_sync_service.dart';
import '../../../data/models/session.dart';
import '../../../data/repositories/app_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authRepository);

  final AuthRepository _authRepository;

  bool _bootstrapped = false;
  bool get bootstrapped => _bootstrapped;

  Session? _session;
  Session? get session => _session;
  bool get isAuthenticated => _session != null;

  /// Selected role before completing registration (terms flow).
  UserRole? registrationRole;

  Future<void> loadSession() async {
    _session = await _authRepository.getSession();
    _bootstrapped = true;
    notifyListeners();
    final s = _session;
    if (s != null) {
      unawaited(DeviceTokenSyncService.instance.syncWithSession(s));
    }
  }

  Future<void> loginAs(String email, String password, UserRole role) async {
    final s = await _authRepository.login(email: email, password: password, roleHint: role);
    _session = s;
    notifyListeners();
    unawaited(DeviceTokenSyncService.instance.syncWithSession(s));
  }

  /// Dev-friendly sign-in matching prototype “Sign In” without backend.
  Future<void> quickLogin(UserRole role) async {
    await loginAs('driver@fleetco.co.uk', '', role);
  }

  Future<void> logout() async {
    if (_session != null) {
      await _authRepository.logout(
        accessToken: _session!.accessToken,
        refreshToken: _session!.refreshToken,
      );
    } else {
      await _authRepository.clearSession();
    }
    _session = null;
    registrationRole = null;
    await DeviceTokenSyncService.instance.clearLastSync();
    notifyListeners();
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
    _session = null;
    registrationRole = null;
    await DeviceTokenSyncService.instance.clearLastSync();
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
