/// Response payload from `GET /api/v1/billing/stripe/config`.
class StripeBillingConfig {
  const StripeBillingConfig({
    required this.enabled,
    required this.publishableKey,
  });

  final bool enabled;
  final String publishableKey;

  static StripeBillingConfig? fromApiBody(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is! Map<String, dynamic>) return null;
    return StripeBillingConfig(
      enabled: data['enabled'] == true,
      publishableKey: (data['publishableKey'] as String?)?.trim() ?? '',
    );
  }
}
