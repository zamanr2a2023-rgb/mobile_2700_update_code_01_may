/// Chat list + message rows from [`GET /api/v1/chat/threads`](…) and job messages API.
library;

String _str(dynamic v) => v == null ? '' : '$v'.trim();

/// Formats ISO-8601 for thread list (short time, Yesterday, weekday, or date).
String formatChatThreadTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) {
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  if (diff == 1) return 'Yesterday';
  if (diff < 7) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(local.weekday - 1).clamp(0, 6)];
  }
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
}

/// One message in [`GET /chat/jobs/:jobId/messages`] `data.items[]`.
class JobChatMessage {
  const JobChatMessage({
    required this.id,
    required this.jobId,
    required this.text,
    required this.attachments,
    required this.createdAtIso,
    required this.isOwn,
    required this.senderLabel,
    this.senderPhotoUrl,
  });

  final String id;
  final String jobId;
  final String text;
  final List<String> attachments;
  final String createdAtIso;
  final bool isOwn;
  final String senderLabel;
  final String? senderPhotoUrl;

  factory JobChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] is Map<String, dynamic> ? json['sender'] as Map<String, dynamic> : null;
    final att = json['attachments'];
    final urls = <String>[];
    if (att is List<dynamic>) {
      for (final e in att) {
        final s = '$e'.trim();
        if (s.isNotEmpty) urls.add(s);
      }
    }
    return JobChatMessage(
      id: _str(json['_id']),
      jobId: _str(json['jobId']),
      text: _str(json['text']),
      attachments: urls,
      createdAtIso: _str(json['createdAt']),
      isOwn: json['isOwn'] == true,
      senderLabel: sender != null ? _str(sender['label']) : '',
      senderPhotoUrl: () {
        if (sender == null) return null;
        final p = _str(sender['profilePhotoUrl']);
        return p.isEmpty ? null : p;
      }(),
    );
  }

  String get timeLabel {
    final dt = DateTime.tryParse(createdAtIso);
    if (dt == null) return '';
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

/// Parsed page from [`GET /chat/jobs/:jobId/messages`].
class JobChatMessagesPage {
  const JobChatMessagesPage({
    required this.items,
    required this.peerTitle,
    required this.peerSubtitle,
    this.peerPhotoUrl,
    this.hasOlder = false,
    this.nextBefore,
  });

  final List<JobChatMessage> items;
  final String peerTitle;
  final String peerSubtitle;
  final String? peerPhotoUrl;
  final bool hasOlder;
  final String? nextBefore;

  static JobChatMessagesPage? tryParse(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) return null;
    final itemsRaw = data['items'];
    final items = <JobChatMessage>[];
    if (itemsRaw is List<dynamic>) {
      for (final e in itemsRaw) {
        if (e is Map<String, dynamic>) items.add(JobChatMessage.fromJson(e));
      }
    }
    final cp = data['counterparty'] is Map<String, dynamic> ? data['counterparty'] as Map<String, dynamic> : null;
    final job = data['job'] is Map<String, dynamic> ? data['job'] as Map<String, dynamic> : null;
    final meta = data['meta'] is Map<String, dynamic> ? data['meta'] as Map<String, dynamic> : null;

    final peerTitle = cp != null ? _str(cp['label']) : (job != null ? _str(job['jobCode']) : '');
    final peerSubtitle = job != null ? _str(job['title']) : '';

    String? photo;
    if (cp != null) {
      final p = _str(cp['profilePhotoUrl']);
      photo = p.isEmpty ? null : p;
    }

    final nextBefore = meta != null ? _str(meta['nextBefore']) : '';
    return JobChatMessagesPage(
      items: items,
      peerTitle: peerTitle.isEmpty ? 'Chat' : peerTitle,
      peerSubtitle: peerSubtitle,
      peerPhotoUrl: photo,
      hasOlder: meta != null && meta['hasOlder'] == true,
      nextBefore: nextBefore.isEmpty ? null : nextBefore,
    );
  }
}

/// Single row from [`GET /chat/threads`] `data[]`.
class ChatInboxThreadRow {
  const ChatInboxThreadRow({
    required this.conversationId,
    required this.title,
    required this.subtitle,
    this.counterpartyPhotoUrl,
    required this.preview,
    required this.sortTimeIso,
  });

  final String conversationId;
  final String title;
  final String subtitle;
  final String? counterpartyPhotoUrl;
  final String preview;
  final String sortTimeIso;

  static ChatInboxThreadRow? tryParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final conv = _str(raw['conversationId']);
    if (conv.isEmpty) return null;
    final lm = raw['lastMessage'];
    final lastText = lm is Map<String, dynamic> ? _str(lm['text']) : '';
    final lastCreated = lm is Map<String, dynamic> ? _str(lm['createdAt']) : '';
    final updated = _str(raw['updatedAt']);
    final sortIso = lastCreated.isNotEmpty ? lastCreated : updated;
    final cp = raw['counterparty'] is Map<String, dynamic> ? raw['counterparty'] as Map<String, dynamic> : null;
    String? pic;
    if (cp != null) {
      final p = _str(cp['profilePhotoUrl']);
      pic = p.isEmpty ? null : p;
    }
    return ChatInboxThreadRow(
      conversationId: conv,
      title: _str(raw['title']).isEmpty ? 'Chat' : _str(raw['title']),
      subtitle: _str(raw['subtitle']),
      counterpartyPhotoUrl: pic,
      preview: lastText,
      sortTimeIso: sortIso.isNotEmpty ? sortIso : updated,
    );
  }
}
