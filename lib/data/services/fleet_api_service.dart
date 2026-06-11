import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

class FleetApiService {
  FleetApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? ApiConstants.usersBaseUrl).trim().replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> fetchFleetDashboard({required String accessToken}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/fleet/dashboard');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch dashboard');
  }

  Future<Map<String, dynamic>> fetchFleetVehicles({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.fleetVehiclesPath}');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to load vehicles');
  }

  /// `GET /api/v1/fleet/vehicles/:vehicleId` — vehicle + recentJobs + meta.
  Future<Map<String, dynamic>> fetchFleetVehicleById({
    required String accessToken,
    required String vehicleId,
  }) async {
    final id = vehicleId.trim();
    final uri = Uri.parse('$_baseUrl${ApiConstants.fleetVehiclesPath}/${Uri.encodeComponent(id)}');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to load vehicle');
  }

  /// `POST /api/v1/fleet/vehicles`
  Future<Map<String, dynamic>> createFleetVehicle({
    required String accessToken,
    required String registration,
    required String type,
    required String make,
    required String model,
    String? vin,
    int? currentMileageKm,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.fleetVehiclesPath}');
    final body = <String, dynamic>{
      'registration': registration.trim(),
      'type': type.trim(),
      'make': make.trim(),
      'model': model.trim(),
    };
    final v = vin?.trim();
    if (v != null && v.isNotEmpty) {
      body['vin'] = v;
    }
    if (currentMileageKm != null && currentMileageKm > 0) {
      body['currentMileageKm'] = currentMileageKm;
    }
    final res = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to add vehicle');
  }

  /// `PATCH /api/v1/fleet/vehicles/:vehicleId`
  Future<Map<String, dynamic>> patchFleetVehicle({
    required String accessToken,
    required String vehicleId,
    required String registration,
    required String make,
    required String model,
    String? type,
    int? year,
    String? vin,
  }) async {
    final id = vehicleId.trim();
    final uri = Uri.parse('$_baseUrl${ApiConstants.fleetVehiclesPath}/${Uri.encodeComponent(id)}');
    final body = <String, dynamic>{
      'registration': registration.trim(),
      'make': make.trim(),
      'model': model.trim(),
    };
    final t = type?.trim();
    if (t != null && t.isNotEmpty) {
      body['type'] = t;
    }
    if (year != null) {
      body['year'] = year;
    }
    final v = vin?.trim();
    if (v != null && v.isNotEmpty) {
      body['vin'] = v;
    }
    final res = await _client.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to update vehicle');
  }

  Future<Map<String, dynamic>> fetchJobs({
    required String accessToken,
    required String tab, // active | completed
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}').replace(
      queryParameters: {
        'tab': tab,
        'page': '$page',
        'limit': '$limit',
      },
    );
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch jobs');
  }

  /// Single job detail: `GET /api/v1/jobs/:jobId`
  Future<Map<String, dynamic>> fetchJob({
    required String accessToken,
    required String jobId,
  }) async {
    final id = jobId.trim();
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}/${Uri.encodeComponent(id)}');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch job');
  }

  /// Quotes for a job: `GET /api/v1/jobs/:jobId/quotes`
  Future<Map<String, dynamic>> fetchJobQuotes({
    required String accessToken,
    required String jobId,
  }) async {
    final id = jobId.trim();
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}/${Uri.encodeComponent(id)}/quotes');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch quotes');
  }

  /// `GET /api/v1/billing/stripe/config`
  Future<Map<String, dynamic>> fetchStripeBillingConfig({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.billingStripeConfigPath}');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to load Stripe config');
  }

  /// `GET /api/v1/billing/payment-methods`
  Future<Map<String, dynamic>> fetchBillingPaymentMethods({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.billingPaymentMethodsPath}');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to load payment methods');
  }

  /// `PATCH /api/v1/billing/payment-methods/:id/default`
  Future<Map<String, dynamic>> setBillingPaymentMethodDefault({
    required String accessToken,
    required String methodId,
  }) async {
    final id = methodId.trim();
    final uri = Uri.parse(
      '$_baseUrl${ApiConstants.billingPaymentMethodsPath}/${Uri.encodeComponent(id)}/default',
    );
    final res = await _client.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{}),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to set default payment method');
  }

  /// `DELETE /api/v1/billing/payment-methods/:id`
  Future<Map<String, dynamic>> deleteBillingPaymentMethod({
    required String accessToken,
    required String methodId,
  }) async {
    final id = methodId.trim();
    final uri = Uri.parse(
      '$_baseUrl${ApiConstants.billingPaymentMethodsPath}/${Uri.encodeComponent(id)}',
    );
    final res = await _client.delete(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to remove payment method');
  }

  /// Fleet rates a completed job: `POST /api/v1/fleet/reviews`
  Future<Map<String, dynamic>> submitFleetReview({
    required String accessToken,
    required String jobId,
    required int rating,
    String? comment,
  }) async {
    final id = jobId.trim();
    final payload = <String, dynamic>{
      'jobId': id,
      'rating': rating,
    };
    final c = comment?.trim();
    if (c != null && c.isNotEmpty) {
      payload['comment'] = c;
    }

    final uri = Uri.parse('$_baseUrl${ApiConstants.fleetReviewsPath}');
    final res = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to submit review');
  }

  /// Fleet cancels a job: `PATCH /api/v1/jobs/:jobId/cancel`
  Future<Map<String, dynamic>> cancelJob({
    required String accessToken,
    required String jobId,
  }) async {
    final id = jobId.trim();
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}/${Uri.encodeComponent(id)}/cancel');
    final res = await _client.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{}),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to cancel job');
  }

  /// Fleet accepts a mechanic quote: `PATCH /api/v1/quotes/:quoteId/accept`
  Future<Map<String, dynamic>> acceptQuote({
    required String accessToken,
    required String quoteId,
  }) async {
    final id = quoteId.trim();
    final uri = Uri.parse('$_baseUrl/api/v1/quotes/${Uri.encodeComponent(id)}/accept');
    final res = await _client.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{}),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to accept quote');
  }

  /// Fleet approves completed work / releases payment: `PATCH /api/v1/jobs/:jobId/complete/approve`
  ///
  /// - Card pay: pass [paymentMethodId] (saved card Mongo `_id`, NOT `pm_…`) and [finalAmount].
  /// - Hand Cash: pass only [finalAmount] (omit [paymentMethodId]). See `payment.md` §5.
  Future<Map<String, dynamic>> approveJobCompletion({
    required String accessToken,
    required String jobId,
    String? paymentMethodId,
    num? finalAmount,
  }) async {
    final id = jobId.trim();
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}/${Uri.encodeComponent(id)}/complete/approve');
    final body = <String, dynamic>{};
    final pm = paymentMethodId?.trim();
    if (pm != null && pm.isNotEmpty) {
      body['paymentMethodId'] = pm;
    }
    if (finalAmount != null) {
      body['finalAmount'] = finalAmount;
    }
    final res = await _client.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to approve completion');
  }

  /// `POST /api/v1/billing/stripe/setup-intent` — start adding a card.
  /// Returns `{ clientSecret, setupIntentId, ... }` inside `data`.
  Future<Map<String, dynamic>> createStripeSetupIntent({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.billingStripeSetupIntentPath}');
    final res = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{}),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to start card setup');
  }

  /// `POST /api/v1/billing/stripe/payment-methods/attach` — save card on server.
  /// [paymentMethodId] is the Stripe `pm_…` from the SDK (NOT the Mongo `_id`).
  Future<Map<String, dynamic>> attachStripePaymentMethod({
    required String accessToken,
    required String paymentMethodId,
    bool isDefault = true,
    String? setupIntentId,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.billingStripePaymentMethodsAttachPath}');
    final body = <String, dynamic>{
      'paymentMethodId': paymentMethodId.trim(),
      'isDefault': isDefault,
    };
    final sid = setupIntentId?.trim();
    if (sid != null && sid.isNotEmpty) {
      body['setupIntentId'] = sid;
    }
    final res = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to save card');
  }

  Future<Map<String, dynamic>> createJob({
    required String accessToken,
    required String title,
    required String notes,
    required String issueType,
    required String mode, // EMERGENCY | SCHEDULED
    required String urgency, // HIGH | MEDIUM | LOW
    required String registration,
    required String vehicleType,
    required String vehicleMake,
    required String vehicleModel,
    String? trailerMakeModel,
    required num estimatedPayout,
    required String locationJson,
    String? driverName,
    String? driverPhone,
    String? availabilityWindowJson,
    List<http.MultipartFile> photos = const [],
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}');
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    });

    req.fields.addAll({
      'title': title,
      'notes': notes,
      'issueType': issueType,
      'mode': mode,
      'urgency': urgency,
      'registration': registration,
      'vehicleType': vehicleType,
      'vehicleMake': vehicleMake,
      'vehicleModel': vehicleModel,
      'estimatedPayout': estimatedPayout.toString(),
      'location': locationJson,
    });

    if (trailerMakeModel != null && trailerMakeModel.trim().isNotEmpty) {
      req.fields['trailerMakeModel'] = trailerMakeModel.trim();
    }
    if (driverName != null && driverName.trim().isNotEmpty) {
      req.fields['driverName'] = driverName.trim();
    }
    if (driverPhone != null && driverPhone.trim().isNotEmpty) {
      req.fields['driverPhone'] = driverPhone.trim();
    }
    if (availabilityWindowJson != null && availabilityWindowJson.trim().isNotEmpty) {
      req.fields['availabilityWindow'] = availabilityWindowJson.trim();
    }

    for (final p in photos) {
      req.files.add(p);
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _decodeOrThrow(res, defaultMessage: 'Failed to create job');
  }

  Future<Map<String, dynamic>> fetchNotifications({
    required String accessToken,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/notifications').replace(
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
      },
    );
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch notifications');
  }

  /// Single notification (`GET /api/v1/notifications/:id`) — includes `navigation` for deep links.
  Future<Map<String, dynamic>> fetchNotificationById({
    required String accessToken,
    required String notificationId,
  }) async {
    final id = notificationId.trim();
    final uri = Uri.parse('$_baseUrl/api/v1/notifications/${Uri.encodeComponent(id)}');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to load notification');
  }

  Map<String, dynamic> _decodeOrThrow(http.Response res, {required String defaultMessage}) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(res.body);
      body = (decoded is Map<String, dynamic>) ? decoded : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (body['message'] is String && (body['message'] as String).trim().isNotEmpty)
          ? body['message'] as String
          : '$defaultMessage (HTTP ${res.statusCode})';
      throw FleetApiException(msg);
    }
    return body;
  }
}

class FleetApiException implements Exception {
  FleetApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

