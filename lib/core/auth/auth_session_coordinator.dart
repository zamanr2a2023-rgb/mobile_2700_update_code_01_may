import 'dart:async';

import 'package:flutter/foundation.dart';

/// Single place that clears local auth when the backend rejects the session.
///
/// Prevents concurrent 401s from triggering multiple logout/navigation sequences.
class AuthSessionCoordinator {
  AuthSessionCoordinator._();

  static final AuthSessionCoordinator instance = AuthSessionCoordinator._();

  Future<void> Function()? _clearLocalAuth;
  Future<void>? _inFlight;
  var _bound = false;

  /// Bound once from [AuthViewModel] at startup.
  void bind({required Future<void> Function() clearLocalAuth}) {
    _clearLocalAuth = clearLocalAuth;
    _bound = true;
  }

  bool get isBound => _bound;

  bool get isInvalidating => _inFlight != null;

  /// Atomically clear access/refresh tokens + in-memory session.
  /// Concurrent callers share the same in-flight future.
  Future<void> invalidateSession({String reason = 'auth_failure'}) {
    final existing = _inFlight;
    if (existing != null) return existing;

    final clear = _clearLocalAuth;
    if (clear == null) {
      if (kDebugMode) {
        debugPrint('[AuthSession] invalidate ignored (not bound): $reason');
      }
      return Future<void>.value();
    }

    if (kDebugMode) {
      debugPrint('[AuthSession] invalidating local session ($reason)');
    }

    late final Future<void> future;
    future = () async {
      try {
        await clear();
      } finally {
        // Keep `_inFlight` briefly so nested 401s still coalesce.
        scheduleMicrotask(() {
          if (identical(_inFlight, future)) {
            _inFlight = null;
          }
        });
      }
    }();

    _inFlight = future;
    return future;
  }
}
