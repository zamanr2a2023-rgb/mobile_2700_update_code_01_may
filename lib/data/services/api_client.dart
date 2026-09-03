import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/auth/auth_session_coordinator.dart';
import '../../core/constants/api_constants.dart';

/// Thrown when the backend rejects the access token and local session is cleared.
class AuthSessionInvalidException implements Exception {
  AuthSessionInvalidException([this.message = 'Session expired. Please sign in again.']);

  final String message;

  @override
  String toString() => message;
}

/// Central HTTP helpers for TruckFix authenticated API calls.
///
/// Services still build requests with an explicit Bearer token (existing pattern),
/// but all authenticated response decoding must go through [decodeOrThrow] so
/// 401 / invalid-token failures clear the session once and route to Login.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? ApiConstants.baseUrl).trim().replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  http.Client get client => _client;
  String get baseUrl => _baseUrl;

  /// Optional token provider for future centralized request attachment.
  static String? Function()? accessTokenProvider;

  /// Optional single-flight refresh. Null / returning null means refresh is unavailable.
  ///
  /// This codebase has no `/auth/refresh` endpoint today; leave unset.
  static Future<String?> Function()? refreshAccessToken;

  static Future<String?>? _refreshInFlight;

  /// Headers for an authenticated JSON request.
  static Map<String, String> bearerHeaders(String accessToken, {bool jsonBody = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer ${accessToken.trim()}',
    };
    if (jsonBody) headers['Content-Type'] = 'application/json';
    return headers;
  }

  static Map<String, dynamic> decodeJsonObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String? pickMessage(Map<String, dynamic> body) {
    for (final key in const ['message', 'error', 'msg']) {
      final v = body[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  /// True for HTTP 401 or backend messages that mean the access token is dead.
  static bool isAuthFailure(int statusCode, Map<String, dynamic> body) {
    if (statusCode == 401) return true;
    // Never treat server errors as auth failures.
    if (statusCode >= 500) return false;

    final msg = (pickMessage(body) ?? '').toLowerCase();
    if (msg.isEmpty) return false;

    const needles = <String>[
      'invalid token',
      'token invalid',
      'token expired',
      'expired token',
      'jwt expired',
      'jwt malformed',
      'authentication failed',
      'auth failed',
      'session expired',
      'token revoked',
      'revoked token',
      'access token expired',
      'no authorization token',
      'missing authorization',
      'please log in again',
      'please login again',
      'please sign in again',
    ];
    for (final n in needles) {
      if (msg.contains(n)) return true;
    }
    return false;
  }

  /// Best-effort local JWT `exp` check (no signature verification).
  static bool isJwtExpired(String token, {Duration skew = const Duration(seconds: 30)}) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
      return DateTime.now().toUtc().isAfter(expiry.subtract(skew));
    } catch (_) {
      return false;
    }
  }

  /// Decode an authenticated API response. On auth failure: one refresh attempt
  /// (if configured), otherwise clear session and throw [AuthSessionInvalidException].
  ///
  /// Does **not** treat timeouts / 5xx as auth failures.
  static Future<Map<String, dynamic>> decodeOrThrow(
    http.Response res, {
    required String defaultMessage,
    required Exception Function(String message) onError,
    bool handleAuthFailure = true,
  }) async {
    final body = decodeJsonObject(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }

    final msg = pickMessage(body) ?? '$defaultMessage (HTTP ${res.statusCode})';

    if (handleAuthFailure && isAuthFailure(res.statusCode, body)) {
      final refreshed = await _tryRefreshOnce();
      if (refreshed) {
        // Caller must retry the original request with the new token.
        throw AuthSessionInvalidException('token_refreshed_retry');
      }
      await AuthSessionCoordinator.instance.invalidateSession(reason: 'http_${res.statusCode}');
      throw AuthSessionInvalidException(msg);
    }

    throw onError(msg);
  }

  /// Synchronous variant used by existing sync `_decodeOrThrow` call sites.
  /// Auth invalidation is fire-and-forget (single-flight).
  static Map<String, dynamic> decodeOrThrowSync(
    http.Response res, {
    required String defaultMessage,
    required Exception Function(String message) onError,
    bool handleAuthFailure = true,
  }) {
    final body = decodeJsonObject(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }

    final msg = pickMessage(body) ?? '$defaultMessage (HTTP ${res.statusCode})';

    if (handleAuthFailure && isAuthFailure(res.statusCode, body)) {
      // ignore: unawaited_futures
      AuthSessionCoordinator.instance.invalidateSession(reason: 'http_${res.statusCode}');
      throw AuthSessionInvalidException(msg);
    }

    throw onError(msg);
  }

  static Future<bool> _tryRefreshOnce() async {
    final refresh = refreshAccessToken;
    if (refresh == null) return false;

    final existing = _refreshInFlight;
    if (existing != null) {
      final token = await existing;
      return token != null && token.trim().isNotEmpty;
    }

    late final Future<String?> future;
    future = () async {
      try {
        return await refresh();
      } catch (_) {
        return null;
      } finally {
        scheduleMicrotask(() {
          if (identical(_refreshInFlight, future)) {
            _refreshInFlight = null;
          }
        });
      }
    }();

    _refreshInFlight = future;
    final token = await future;
    return token != null && token.trim().isNotEmpty;
  }
}
