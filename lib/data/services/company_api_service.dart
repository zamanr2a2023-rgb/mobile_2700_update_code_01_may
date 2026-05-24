import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

/// Company-role API calls (same host as mechanic; Bearer identifies company user).
class CompanyApiService {
  CompanyApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? ApiConstants.usersBaseUrl).trim().replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  /// Dashboard summary (`GET /api/v1/company/dashboard`).
  Future<Map<String, dynamic>> fetchDashboard({required String accessToken}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/company/dashboard');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch company dashboard');
  }

  /// Published jobs visible to companies (`GET /api/v1/company/feed`).
  Future<Map<String, dynamic>> fetchCompanyFeed({
    required String accessToken,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/company/feed').replace(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch company feed');
  }

  /// Submit a quote for a published job (`POST /api/v1/jobs/:jobId/quotes`).
  ///
  /// Body matches API: `amount`, `notes`, `etaMinutes` (see Postman).
  Future<Map<String, dynamic>> postJobQuote({
    required String accessToken,
    required String jobId,
    required num amount,
    required int etaMinutes,
    String notes = '',
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}/${Uri.encodeComponent(jobId)}/quotes');
    final payload = <String, dynamic>{
      'amount': amount,
      'notes': notes,
      'etaMinutes': etaMinutes,
    };
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

  /// Provider quotes submitted by this company (`GET /api/v1/quotes/me`).
  Future<Map<String, dynamic>> fetchMyQuotes({
    required String accessToken,
    int page = 1,
    int limit = 100,
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

  /// Company earnings summary (`GET /api/v1/company/earnings/summary`).
  Future<Map<String, dynamic>> fetchCompanyEarningsSummary({required String accessToken}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/company/earnings/summary');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch company earnings summary');
  }

  /// Completed earning jobs (`GET /api/v1/company/earnings/jobs`).
  Future<Map<String, dynamic>> fetchCompanyEarningsJobs({
    required String accessToken,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/company/earnings/jobs').replace(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch company earning jobs');
  }

  /// Authenticated GET for paths returned by job cards (`primaryAction.href`), e.g. invoice detail.
  Future<Map<String, dynamic>> fetchCompanyAuthorizedGet({
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

  /// Company job list for management UI (`GET /api/v1/company/jobs`).
  /// Omit [tab] or use `'all'` for the full list; other values match API e.g.
  /// `pending_review`, `unassigned`, `assigned`, `in_progress`.
  Future<Map<String, dynamic>> fetchCompanyJobs({
    required String accessToken,
    int page = 1,
    int limit = 20,
    String? tab,
  }) async {
    final q = <String, String>{'page': '$page', 'limit': '$limit'};
    if (tab != null && tab.isNotEmpty) {
      q['tab'] = tab;
    }
    final uri = Uri.parse('$_baseUrl/api/v1/company/jobs').replace(queryParameters: q);
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch company jobs');
  }

  /// Assign a mechanic to a company job (`POST /api/v1/company/jobs/:jobId/assign`).
  ///
  /// [mechanicId] is typically the mechanic user `_id` from team; callers may fall back
  /// to a display ref only if that is what the backend expects.
  Future<Map<String, dynamic>> postCompanyJobAssign({
    required String accessToken,
    required String jobId,
    required String mechanicId,
  }) async {
    final id = jobId.trim();
    final uri = Uri.parse('$_baseUrl/api/v1/company/jobs/${Uri.encodeComponent(id)}/assign');
    final payload = <String, dynamic>{
      'mechanicId': mechanicId.trim(),
    };
    final res = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to assign mechanic');
  }

  /// PATCH to a path returned by job cards (`primaryAction.path`), e.g. invoice approval.
  Future<Map<String, dynamic>> patchCompanyJobPath({
    required String accessToken,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final rel = path.trim().startsWith('/') ? path.trim() : '/${path.trim()}';
    final uri = Uri.parse('$_baseUrl$rel');
    final res = await _client.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decodeOrThrow(res, defaultMessage: 'Request failed');
  }

  /// Company mechanics & invites (`GET /api/v1/company/team`).
  Future<Map<String, dynamic>> fetchCompanyTeam({required String accessToken}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/company/team');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to fetch company team');
  }

  /// Invite payload uses [body] (typically `{ "email": "..." }` per `inviteAction.bodyFields`).
  Future<Map<String, dynamic>> postCompanyTeamInvitation({
    required String accessToken,
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final rel = path.trim().startsWith('/') ? path.trim() : '/${path.trim()}';
    final uri = Uri.parse('$_baseUrl$rel');
    final res = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to send invitation');
  }

  /// DELETE for team URLs from the API (e.g. `cardAction.href` → `/api/v1/company/team/members/{id}`, or
  /// `DELETE /api/v1/company/team/invitations/{inviteId}` to cancel an invite).
  Future<void> deleteCompanyTeamByPath({
    required String accessToken,
    required String path,
  }) async {
    final rel = path.trim().startsWith('/') ? path.trim() : '/${path.trim()}';
    final uri = Uri.parse('$_baseUrl$rel');
    final res = await _client.delete(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    Map<String, dynamic> body = {};
    try {
      if (res.body.isNotEmpty) {
        final decoded = jsonDecode(res.body);
        body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      }
    } catch (_) {}
    final msg = (body['message'] as String?) ?? 'Request failed';
    throw Exception(msg);
  }

  Map<String, dynamic> _decodeOrThrow(http.Response res, {required String defaultMessage}) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(res.body);
      body = (decoded is Map<String, dynamic>) ? decoded : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (!ok) {
      final msg = (body['message'] as String?) ?? defaultMessage;
      throw Exception(msg);
    }
    return body;
  }
}
