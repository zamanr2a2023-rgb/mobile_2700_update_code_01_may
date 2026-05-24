import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import 'jobs_api_service.dart' show buildJobPhotoMultipartPart;

class MechanicApiService {
  MechanicApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? ApiConstants.usersBaseUrl).trim().replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> updateAvailability({
    required String accessToken,
    required String availability, // ONLINE | OFFLINE
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.usersMeAvailabilityPath}');
    final res = await _client.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'availability': availability,
        'lastKnownLocation': {
          'coordinates': [longitude, latitude],
        },
      }),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to update availability');
  }

  /// Current user (`GET /api/v1/users/me`) — mechanic fleet profile, preferences, payout, etc.
  Future<Map<String, dynamic>> fetchMe({required String accessToken}) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.usersMePath}');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to load profile');
  }

  /// Update mechanic profile / preferences via `PATCH /api/v1/users/me` (flat JSON body).
  Future<Map<String, dynamic>> updateMe({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.usersMePath}');
    final res = await _client.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to update profile');
  }

  /// Job feed for mechanic: `GET /api/v1/jobs?feed=true&lat=&lng=&radiusMiles=`
  Future<Map<String, dynamic>> fetchJobFeed({
    required String accessToken,
    required double lat,
    required double lng,
    int radiusMiles = 15,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/jobs').replace(
      queryParameters: {
        'feed': 'true',
        'lat': '$lat',
        'lng': '$lng',
        'radiusMiles': '$radiusMiles',
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
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch job feed');
  }

  /// Earnings summary: `GET /api/v1/earnings/summary`
  Future<Map<String, dynamic>> fetchEarningsSummary({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/earnings/summary');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch earnings summary');
  }

  /// Completed earning job rows for mechanic: `GET /api/v1/earnings/jobs`
  Future<Map<String, dynamic>> fetchEarningsJobs({
    required String accessToken,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/earnings/jobs').replace(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch earnings jobs');
  }

  /// Authenticated GET for paths from earning rows (`primaryAction.path`), e.g. invoice download/detail.
  Future<Map<String, dynamic>> fetchMechanicAuthorizedGet({
    required String accessToken,
    required String path,
  }) async {
    final rel = path.trim().startsWith('/') ? path.trim() : '/${path.trim()}';
    final uri = Uri.parse('$_baseUrl$rel');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Request failed');
  }

  /// Active jobs for this mechanic: `GET /api/v1/jobs?tab=active&page=:page&limit=:limit`
  Future<Map<String, dynamic>> fetchMyJobs({
    required String accessToken,
    String tab = 'active',
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/jobs').replace(
      queryParameters: {'tab': tab, 'page': '$page', 'limit': '$limit'},
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

  Future<Map<String, dynamic>> fetchMyQuotes({
    required String accessToken,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/quotes/me').replace(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch quotes');
  }

  /// Single job for mechanic tracker: `GET /api/v1/jobs/:jobId`
  Future<Map<String, dynamic>> fetchJobById({
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
    return _decodeOrThrow(res, defaultMessage: 'Failed to load job');
  }

  /// Submit quote for a job (`POST /api/v1/jobs/:jobId/quotes`).
  Future<Map<String, dynamic>> postJobQuote({
    required String accessToken,
    required String jobId,
    required num amount,
    required int etaMinutes,
    String notes = '',
    String availabilityType = 'NOW',
    String? scheduledAt,
  }) async {
    final id = jobId.trim();
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}/${Uri.encodeComponent(id)}/quotes');
    final payload = <String, dynamic>{
      'amount': amount,
      'notes': notes,
      'availabilityType': availabilityType,
      'etaMinutes': etaMinutes,
    };
    if (scheduledAt != null && scheduledAt.trim().isNotEmpty) {
      payload['scheduledAt'] = scheduledAt.trim();
    }
    final res = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to submit quote');
  }

  /// Mechanic rates the fleet after job completion (`POST /api/v1/jobs/:jobId/reviews/fleet`).
  Future<Map<String, dynamic>> postJobFleetReview({
    required String accessToken,
    required String jobId,
    required int rating,
    String comment = '',
  }) async {
    final id = jobId.trim();
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}/${Uri.encodeComponent(id)}/reviews/fleet');
    final res = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{
        'rating': rating.clamp(1, 5),
        'comment': comment.trim(),
      }),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to submit review');
  }

  Future<Map<String, dynamic>> patchJobJourneyStart({
    required String accessToken,
    required String jobId,
  }) async {
    final id = jobId.trim();
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}/${Uri.encodeComponent(id)}/journey/start');
    final res = await _client.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{}),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to start journey');
  }

  Future<Map<String, dynamic>> patchJobArrive({
    required String accessToken,
    required String jobId,
  }) async {
    final id = jobId.trim();
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}/${Uri.encodeComponent(id)}/arrive');
    final res = await _client.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{}),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to mark arrival');
  }

  Future<Map<String, dynamic>> patchJobWorkStart({
    required String accessToken,
    required String jobId,
  }) async {
    final id = jobId.trim();
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}/${Uri.encodeComponent(id)}/work/start');
    final res = await _client.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{}),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to start work');
  }

  /// `PATCH /api/v1/jobs/:id/work/complete` — multipart (matches Postman).
  Future<Map<String, dynamic>> patchJobWorkCompleteMultipart({
    required String accessToken,
    required String jobId,
    required String repairNotes,
    required String invoiceJson,
    required String finalAmount,
    required String totalAmount,
    List<http.MultipartFile> photos = const [],
  }) async {
    final id = jobId.trim();
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}/${Uri.encodeComponent(id)}/work/complete');
    final req = http.MultipartRequest('PATCH', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..fields['repairNotes'] = repairNotes
      ..fields['invoice'] = invoiceJson
      ..fields['finalAmount'] = finalAmount
      ..fields['totalAmount'] = totalAmount
      ..files.addAll(photos);

    final streamed = await _client.send(req);
    final res = await http.Response.fromStream(streamed);
    return _decodeOrThrow(res, defaultMessage: 'Failed to complete job');
  }

  /// Build photo parts for [patchJobWorkCompleteMultipart] from raw image bytes.
  static http.MultipartFile buildCompletePhotoPart({
    required List<int> bytes,
    required String originalName,
    required int index,
  }) =>
      buildJobPhotoMultipartPart(bytes: bytes, originalName: originalName, index: index);

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

  /// `POST /api/v1/billing/payment-methods` — manual card registration (demo / non-Stripe).
  Future<Map<String, dynamic>> postBillingPaymentMethod({
    required String accessToken,
    required String methodType,
    required String provider,
    required String providerMethodId,
    required String cardBrand,
    required String last4,
    required int expMonth,
    required int expYear,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.billingPaymentMethodsPath}');
    final body = <String, dynamic>{
      'methodType': methodType,
      'provider': provider,
      'providerMethodId': providerMethodId,
      'card': {
        'brand': cardBrand.toLowerCase().trim(),
        'last4': last4.trim(),
        'expMonth': expMonth,
        'expYear': expYear,
      },
    };
    final res = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to add payment method');
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
      throw MechanicApiException(msg);
    }
    return body;
  }
}

class MechanicApiException implements Exception {
  MechanicApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

