abstract final class ApiConstants {
  /// Backend root URL. Override for local dev:
  /// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.thetruckfix.co.uk',
  );

  static String get baseUrl => _normalizedBase;
  static String get authBaseUrl => _normalizedBase;
  static String get usersBaseUrl => _normalizedBase;

  static String get _normalizedBase => apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  // Legacy commented local URLs (use --dart-define=API_BASE_URL=... instead):
  // http://103.208.183.248:5000

  static const String authLoginPath = '/api/v1/auth/login';
  static const String authLogoutPath = '/api/v1/auth/logout';
  static const String authRegisterPath = '/api/v1/auth/register';
  static const String authForgotPasswordPath = '/api/v1/auth/forgot-password';

  static const String usersMeAvailabilityPath = '/api/v1/users/me/availability';
  static const String usersMePath = '/api/v1/users/me';
  static const String supportTicketsPath = '/api/v1/support/tickets';
  static const String jobsPath = '/api/v1/jobs';

  /// Job-scoped chat (see `lib/react/check.md`).
  static const String chatThreadsPath = '/api/v1/chat/threads';

  /// Fleet submits mechanic review: `POST /api/v1/fleet/reviews`
  static const String fleetReviewsPath = '/api/v1/fleet/reviews';

  /// Fleet vehicle list (`GET`) for My Fleet overlay.
  static const String fleetVehiclesPath = '/api/v1/fleet/vehicles';

  /// Fleet billing: saved cards & bank methods.
  static const String billingPaymentMethodsPath = '/api/v1/billing/payment-methods';

  /// Stripe publishable key for Flutter Stripe SDK (`GET`, Bearer auth).
  static const String billingStripeConfigPath = '/api/v1/billing/stripe/config';

  /// Start a Stripe SetupIntent to add a card (`POST`, Bearer auth, empty body).
  static const String billingStripeSetupIntentPath = '/api/v1/billing/stripe/setup-intent';

  /// Attach a confirmed Stripe `pm_…` to the server (`POST`, Bearer auth).
  static const String billingStripePaymentMethodsAttachPath =
      '/api/v1/billing/stripe/payment-methods/attach';

  /// Register FCM device token for push (`POST`, Bearer auth).
  static const String notificationsDeviceTokensPath =
      '/api/v1/notifications/device-tokens';

  /// Matches [pubspec.yaml] `version` (major.minor.patch).
  static const String appVersion = '1.0.0';

  /// Google Maps / Places / Geocoding (restrict in Cloud Console for production).
  static const String googleMapsApiKey =
      'AIzaSyCXbW6lUF1nBJiJQILPlS4fkVGRi1SZlxw';
}
