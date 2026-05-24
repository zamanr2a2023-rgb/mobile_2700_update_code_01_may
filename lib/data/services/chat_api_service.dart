import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/constants/api_constants.dart';
import '../models/job_chat_models.dart';

MediaType _chatImageMediaTypeForFilename(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return MediaType('image', 'png');
  if (lower.endsWith('.gif')) return MediaType('image', 'gif');
  if (lower.endsWith('.webp')) return MediaType('image', 'webp');
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
    return MediaType('image', 'heic');
  }
  return MediaType('image', 'jpeg');
}

final _chatImageExt = RegExp(r'\.(jpe?g|png|gif|webp|heic|heif)$', caseSensitive: false);

String _normalizeChatAttachmentFilename(String filePath) {
  var name = filePath.trim().replaceAll('\\', '/');
  if (name.contains('/')) name = name.split('/').last;
  if (name.isEmpty) return 'chat.jpg';
  if (!_chatImageExt.hasMatch(name)) return '$name.jpg';
  return name;
}

class ChatApiException implements Exception {
  ChatApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// `GET/POST/PATCH /api/v1/chat/...`
class ChatApiService {
  ChatApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? ApiConstants.usersBaseUrl).trim().replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  /// `GET /api/v1/chat/threads?page=&limit=`
  Future<Map<String, dynamic>> fetchThreads({
    required String accessToken,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.chatThreadsPath}').replace(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to load messages');
  }

  static List<ChatInboxThreadRow> parseThreadsEnvelope(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is! List<dynamic>) return [];
    final out = <ChatInboxThreadRow>[];
    for (final e in data) {
      final row = ChatInboxThreadRow.tryParse(e);
      if (row != null) out.add(row);
    }
    out.sort((a, b) {
      final da = DateTime.tryParse(a.sortTimeIso)?.millisecondsSinceEpoch ?? 0;
      final db = DateTime.tryParse(b.sortTimeIso)?.millisecondsSinceEpoch ?? 0;
      return db.compareTo(da);
    });
    return out;
  }

  /// `GET /api/v1/chat/jobs/:jobId/messages?limit=&before=`
  Future<Map<String, dynamic>> fetchJobMessages({
    required String accessToken,
    required String jobId,
    int limit = 50,
    String? beforeMessageId,
  }) async {
    final id = jobId.trim();
    final q = <String, String>{'limit': '$limit'};
    final b = beforeMessageId?.trim();
    if (b != null && b.isNotEmpty) {
      q['before'] = b;
      q['beforeMessageId'] = b;
    }
    final uri = Uri.parse(
      '$_baseUrl/api/v1/chat/jobs/${Uri.encodeComponent(id)}/messages',
    ).replace(queryParameters: q);
    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to load chat');
  }

  /// `POST /api/v1/chat/jobs/:jobId/messages`
  Future<Map<String, dynamic>> sendJobMessage({
    required String accessToken,
    required String jobId,
    required String text,
    List<String> attachments = const [],
  }) async {
    final id = jobId.trim();
    final uri = Uri.parse('$_baseUrl/api/v1/chat/jobs/${Uri.encodeComponent(id)}/messages');
    final res = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'text': text,
        'attachments': attachments,
      }),
    );
    return _decodeOrThrow(res, defaultMessage: 'Failed to send message');
  }

  /// `POST /api/v1/chat/jobs/:jobId/attachments` — multipart field `file` (image/jpeg, image/png, … — not `application/octet-stream`).
  Future<Map<String, dynamic>> uploadJobChatAttachment({
    required String accessToken,
    required String jobId,
    required String filePath,
  }) async {
    final id = jobId.trim();
    final path = filePath.trim();
    if (id.isEmpty) {
      throw ChatApiException('Missing job id for upload.');
    }
    if (path.isEmpty) {
      throw ChatApiException('Missing file path for upload.');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw ChatApiException('Image file not found.');
    }

    final filename = _normalizeChatAttachmentFilename(path);
    final contentType = _chatImageMediaTypeForFilename(filename);

    final uri = Uri.parse('$_baseUrl/api/v1/chat/jobs/${Uri.encodeComponent(id)}/attachments');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          path,
          filename: filename,
          contentType: contentType,
        ),
      );
    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    return _decodeOrThrow(res, defaultMessage: 'Failed to upload image');
  }

  /// Reads attachment URL from [uploadJobChatAttachment] response (`data.url`, `data.secureUrl`, …).
  static String? parseAttachmentUrlFromUpload(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is String && data.trim().isNotEmpty) return data.trim();
    if (data is Map<String, dynamic>) {
      for (final k in ['url', 'secureUrl', 'fileUrl', 'attachmentUrl', 'publicUrl', 'src']) {
        final v = data[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    final root = envelope['url'];
    if (root is String && root.trim().isNotEmpty) return root.trim();
    return null;
  }

  /// `PATCH /api/v1/chat/jobs/:jobId/read`
  Future<void> markJobMessagesRead({
    required String accessToken,
    required String jobId,
  }) async {
    final id = jobId.trim();
    final uri = Uri.parse('$_baseUrl/api/v1/chat/jobs/${Uri.encodeComponent(id)}/read');
    final res = await _client.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    _decodeOrThrow(res, defaultMessage: 'Failed to mark read');
  }

  Map<String, dynamic> _decodeOrThrow(http.Response res, {required String defaultMessage}) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(res.body);
      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg =
          body['message'] is String && (body['message'] as String).trim().isNotEmpty ? body['message'] as String : '$defaultMessage (HTTP ${res.statusCode})';
      throw ChatApiException(msg);
    }
    return body;
  }
}
