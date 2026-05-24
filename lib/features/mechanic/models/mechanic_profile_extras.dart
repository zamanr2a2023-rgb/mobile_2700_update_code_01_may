/// Job-scoped chat thread row (inbox). [jobId] === API `conversationId`.
class MechanicMessageThread {
  const MechanicMessageThread({
    required this.jobId,
    required this.title,
    required this.subtitle,
    this.photoUrl,
    required this.preview,
    required this.timeLabel,
    this.phone,
  });

  /// Same as [jobId]; inbox list key / navigation id.
  String get id => jobId;

  final String jobId;
  final String title;
  final String subtitle;
  final String? photoUrl;
  final String preview;
  final String timeLabel;
  final String? phone;
}
