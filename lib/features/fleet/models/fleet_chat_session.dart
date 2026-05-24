/// Context when opening mechanic chat from dashboard or tracking detail.
class FleetChatSession {
  const FleetChatSession({
    required this.mechanicName,
    this.mechanicPhone,
    this.mechanicPhotoUrl,
    required this.jobCode,
    required this.truckLine,
    /// Backend job id for `GET/POST /api/v1/chat/jobs/:jobId/...`. Null uses demo [FleetChatScreen].
    this.jobId,
  });

  final String mechanicName;
  final String? mechanicPhone;
  final String? mechanicPhotoUrl;
  final String jobCode;
  final String truckLine;

  /// Mongo/API job id for REST job chat.
  final String? jobId;
}
