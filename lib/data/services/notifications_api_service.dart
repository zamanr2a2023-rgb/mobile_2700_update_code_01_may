import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

class NotificationsApiService {
  NotificationsApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? ApiConstants.usersBaseUrl).trim().replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  /// `POST /api/v1/notifications/device-tokens`
  Future<void> registerDeviceToken({
    required String accessToken,
    required String token,
    required String platform,
    String appVersion = ApiConstants.appVersion,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.notificationsDeviceTokensPath}');
    final res = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'token': token,
        'platform': platform,
        'appVersion': appVersion,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      Map<String, dynamic> body;
      try {
        final decoded = jsonDecode(res.body);
        body = (decoded is Map<String, dynamic>) ? decoded : <String, dynamic>{};
      } catch (_) {
        body = <String, dynamic>{};
      }
      final msg = (body['message'] is String && (body['message'] as String).trim().isNotEmpty)
          ? body['message'] as String
          : 'Failed to register device token (HTTP ${res.statusCode})';
      throw NotificationsApiException(msg);
    }
  }
}

class NotificationsApiException implements Exception {
  NotificationsApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
