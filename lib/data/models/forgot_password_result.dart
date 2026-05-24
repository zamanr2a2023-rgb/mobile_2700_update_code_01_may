/// Response from `POST /api/v1/auth/forgot-password`.
class ForgotPasswordResult {
  const ForgotPasswordResult({
    required this.message,
    this.resetToken,
  });

  final String message;

  /// Present in some API environments (e.g. dev); reset link is emailed in production.
  final String? resetToken;
}
