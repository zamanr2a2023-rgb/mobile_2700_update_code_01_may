import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/constants/api_constants.dart';

/// Single photo part for `POST /jobs` — servers often reject `application/octet-stream`.
http.MultipartFile buildJobPhotoMultipartPart({
  required List<int> bytes,
  required String originalName,
  required int index,
}) {
  final filename = _normalizeJobPhotoFilename(originalName, index);
  return http.MultipartFile.fromBytes(
    'photos',
    bytes,
    filename: filename,
    contentType: _imageMediaTypeForFilename(filename),
  );
}

MediaType _imageMediaTypeForFilename(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return MediaType('image', 'png');
  if (lower.endsWith('.gif')) return MediaType('image', 'gif');
  if (lower.endsWith('.webp')) return MediaType('image', 'webp');
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
    return MediaType('image', 'heic');
  }
  return MediaType('image', 'jpeg');
}

final _imageExt = RegExp(r'\.(jpe?g|png|gif|webp|heic|heif)$', caseSensitive: false);

String _normalizeJobPhotoFilename(String originalName, int index) {
  var name = originalName.trim().replaceAll('\\', '/');
  if (name.contains('/')) name = name.split('/').last;
  if (name.isEmpty) return 'photo_$index.jpg';
  if (!_imageExt.hasMatch(name)) name = '$name.jpg';
  return name;
}

class JobsApiService {
  JobsApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? ApiConstants.usersBaseUrl).trim().replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  /// Create a job using multipart/form-data (matches your Postman request).
  Future<Map<String, dynamic>> createJob({
    required String accessToken,
    required Map<String, String> fields,
    List<http.MultipartFile> photos = const [],
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.jobsPath}');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..fields.addAll(fields)
      ..files.addAll(photos);

    final streamed = await _client.send(req);
    final res = await http.Response.fromStream(streamed);

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(res.body);
      body = (decoded is Map<String, dynamic>) ? decoded : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final raw = body['message'] is String ? body['message'] as String : null;
      throw JobsApiException(JobsApiException.userMessage(raw, statusCode: res.statusCode));
    }

    return body;
  }
}

class JobsApiException implements Exception {
  JobsApiException(this.message);
  final String message;

  /// Turns backend/debug text into a short message suitable for SnackBars.
  static String userMessage(String? raw, {int? statusCode}) {
    if (raw == null || raw.trim().isEmpty) {
      if (statusCode != null) {
        return 'Could not post your job (error $statusCode). Please try again.';
      }
      return 'Could not post your job. Please try again.';
    }

    var msg = raw.trim();
    final debugIdx = msg.indexOf(' (content-type=');
    if (debugIdx > 0) msg = msg.substring(0, debugIdx).trim();

    final lower = msg.toLowerCase();
    if (lower.contains('description') && lower.contains('required')) {
      return 'Please describe the problem in Notes before posting.';
    }
    if (lower.contains('title') && lower.contains('required')) {
      return 'Please select a job category.';
    }
    if (lower.contains('location') && lower.contains('required')) {
      return 'Please set the breakdown location on the map.';
    }
    if (lower.contains('registration') && lower.contains('required')) {
      return 'Please enter the vehicle registration.';
    }

    return msg;
  }

  @override
  String toString() => message;
}

