import '../../data/models/session.dart';

/// Result of validating a locally stored session against the backend.
enum SessionValidationStatus {
  /// No local credentials.
  none,

  /// Access token accepted by the backend.
  valid,

  /// Token missing, expired, revoked, or rejected — local session must be cleared.
  invalid,

  /// Network/server temporary failure — do not clear credentials.
  unreachable,
}

class SessionValidationResult {
  const SessionValidationResult._(this.status, {this.session});

  const SessionValidationResult.none() : this._(SessionValidationStatus.none);

  const SessionValidationResult.valid(Session session)
      : this._(SessionValidationStatus.valid, session: session);

  const SessionValidationResult.invalid()
      : this._(SessionValidationStatus.invalid);

  const SessionValidationResult.unreachable()
      : this._(SessionValidationStatus.unreachable);

  final SessionValidationStatus status;
  final Session? session;

  bool get isValid => status == SessionValidationStatus.valid;
  bool get isInvalid => status == SessionValidationStatus.invalid;
  bool get isUnreachable => status == SessionValidationStatus.unreachable;
}

/// Startup validation could not reach the backend — keep credentials, show Retry.
class SessionUnreachableException implements Exception {
  const SessionUnreachableException([
    this.message = 'Unable to verify your session. Check your connection and try again.',
  ]);

  final String message;

  @override
  String toString() => message;
}
