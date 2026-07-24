import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

class UsersApiService {
  UsersApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? ApiConstants.usersBaseUrl).trim().replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

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

  /// Update current user profile via `PATCH /api/v1/users/me`.
  ///
  /// Backend typically accepts `fleetProfile` (and/or snake_case variants).
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

  /// Permanently delete the signed-in user (`DELETE /api/v1/users/me`).
  ///
  /// Backend requires the account password in the JSON body: `{ "password": "..." }`.
  Future<Map<String, dynamic>> deleteMe({
    required String accessToken,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.usersMePath}');
    final res = await _client.delete(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'password': password}),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to delete account');
  }

  /// Pending company invitations for the signed-in mechanic.
  Future<Map<String, dynamic>> fetchCompanyInvites({required String accessToken}) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.usersMeCompanyInvitesPath}');
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to load company invitations');
  }

  /// Accept a company invitation (`POST .../company-invites/{inviteId}/accept`).
  Future<Map<String, dynamic>> acceptCompanyInvite({
    required String accessToken,
    required String inviteId,
  }) async {
    final id = inviteId.trim();
    if (id.isEmpty) throw UsersApiException('Invalid invitation');
    final uri = Uri.parse('$_baseUrl${ApiConstants.usersMeCompanyInvitesPath}/$id/accept');
    final res = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: '{}',
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to accept invitation');
  }

  /// Decline a company invitation (`POST .../company-invites/{inviteId}/decline`).
  Future<Map<String, dynamic>> declineCompanyInvite({
    required String accessToken,
    required String inviteId,
  }) async {
    final id = inviteId.trim();
    if (id.isEmpty) throw UsersApiException('Invalid invitation');
    final uri = Uri.parse('$_baseUrl${ApiConstants.usersMeCompanyInvitesPath}/$id/decline');
    final res = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: '{}',
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to decline invitation');
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
      throw UsersApiException(msg);
    }
    return body;
  }
}

class UsersApiException implements Exception {
  UsersApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
