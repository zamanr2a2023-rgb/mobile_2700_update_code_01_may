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
  Future<Map<String, dynamic>> approveJobCompletion({
    required String accessToken,
    required String jobId,
  }) async {
    final id = jobId.trim();
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}/${Uri.encodeComponent(id)}/complete/approve');
    final res = await _client.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{}),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to approve completion');
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

