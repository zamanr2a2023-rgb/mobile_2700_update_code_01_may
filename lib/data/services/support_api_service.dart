import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

/// Maps Help & Support UI category ids (`technical`, fleet `mechanic`, …) to API enums.
String supportTicketCategoryEnum(String uiId) {
  switch (uiId) {
    case 'technical':
    case 'mechanic':
      return 'TECHNICAL';
    case 'payment':
      return 'BILLING';
    case 'account':
      return 'ACCOUNT';
    case 'job':
      return 'JOB';
    case 'other':
      return 'OTHER';
    default:
      return 'OTHER';
  }
}

class SupportApiService {
  SupportApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? ApiConstants.usersBaseUrl).trim().replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  /// Creates a ticket via `POST /api/v1/support/tickets`.
  Future<Map<String, dynamic>> createTicket({
    required String accessToken,
    required String subject,
    required String message,
    String? category,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.supportTicketsPath}');
    final payload = <String, dynamic>{
      'subject': subject.trim(),
      'message': message.trim(),
    };
    final c = category?.trim();
    if (c != null && c.isNotEmpty) {
      payload['category'] = c;
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
          : 'Failed to send message (HTTP ${res.statusCode})';
      throw SupportApiException(msg);
    }
    return body;
  }
}

class SupportApiException implements Exception {
  SupportApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
