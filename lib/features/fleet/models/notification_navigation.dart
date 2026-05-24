import 'fleet_chat_session.dart';

/// Parses `GET /api/v1/notifications/:id` → `data.navigation` for fleet deep links.
FleetChatSession? fleetChatSessionFromNotificationData(Map<String, dynamic> data) {
  final nav = data['navigation'];
  if (nav is! Map) return null;

  final screen = (nav['screen'] as String?)?.trim().toUpperCase();
  if (screen != 'JOB_CHAT') return null;

  final params = nav['params'];
  final p = params is Map ? Map<String, dynamic>.from(params) : <String, dynamic>{};

  final payload = data['data'];
  final nested = payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{};

  final jobId = _str(p['jobId'] ?? nested['jobId']);
  if (jobId == null) return null;

  final jobCode = _str(p['jobCode'] ?? nested['jobCode']) ?? jobId;
  final title = _str(data['title']) ?? '';

  return FleetChatSession(
    mechanicName: 'Mechanic',
    jobCode: jobCode,
    truckLine: title.contains(' for ') ? title.split(' for ').last.trim() : jobCode,
    jobId: jobId,
  );
}

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}
