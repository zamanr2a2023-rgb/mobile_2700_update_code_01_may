import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../models/company_invite.dart';

/// Public (unauthenticated) invitation validation.
class PublicInviteApiService {
  PublicInviteApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? ApiConstants.baseUrl).trim().replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  /// `GET /api/v1/public/invites/validate?token=&email=`
  Future<PublicInviteValidation> validateInvite({
    required String token,
    required String email,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.publicInvitesValidatePath}').replace(
      queryParameters: {
        'token': token.trim(),
        'email': email.trim(),
      },
    );
    final res = await _client.get(
      uri,
      headers: const {'Accept': 'application/json'},
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
          : 'Invitation is not valid (HTTP ${res.statusCode})';
      throw PublicInviteApiException(msg);
    }

    return PublicInviteValidation.fromEnvelope(body);
  }
}

class PublicInviteApiException implements Exception {
  PublicInviteApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
