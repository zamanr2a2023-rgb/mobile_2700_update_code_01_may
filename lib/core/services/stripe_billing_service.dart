import 'package:flutter_stripe/flutter_stripe.dart';

import '../../data/models/stripe_billing_config.dart';
import '../../data/services/fleet_api_service.dart';

/// Fetches Stripe billing config and initializes [flutter_stripe] once per key.
class StripeBillingService {
  StripeBillingService({FleetApiService? api}) : _api = api ?? FleetApiService();

  final FleetApiService _api;

  String? _initializedPublishableKey;
  StripeBillingConfig? _lastConfig;

  StripeBillingConfig? get lastConfig => _lastConfig;

  bool get isInitialized => _initializedPublishableKey != null;

  /// Step 1 of Fleet billing: `GET /billing/stripe/config` then SDK init.
  Future<StripeBillingConfig> ensureInitialized({required String accessToken}) async {
    final body = await _api.fetchStripeBillingConfig(accessToken: accessToken);
    final config = StripeBillingConfig.fromApiBody(body);
    if (config == null) {
      throw Exception('Invalid Stripe config response');
    }
    if (!config.enabled) {
      throw Exception('Stripe billing is not enabled');
    }
    if (config.publishableKey.isEmpty) {
      throw Exception('Stripe publishable key is missing');
    }

    _lastConfig = config;
    if (_initializedPublishableKey != config.publishableKey) {
      Stripe.publishableKey = config.publishableKey;
      await Stripe.instance.applySettings();
      _initializedPublishableKey = config.publishableKey;
    }
    return config;
  }
}
