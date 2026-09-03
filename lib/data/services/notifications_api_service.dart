import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import 'api_client.dart';

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

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    ApiClient.decodeOrThrowSync(
      res,
      defaultMessage: 'Failed to register device token',
      onError: NotificationsApiException.new,
    );
  }
}

class NotificationsApiException implements Exception {
  NotificationsApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
