/// Context when opening mechanic chat from dashboard or tracking detail.
class FleetChatSession {
  const FleetChatSession({
    required this.mechanicName,
    this.mechanicPhone,
    this.mechanicPhotoUrl,
    required this.jobCode,
    required this.truckLine,
  });

  final String mechanicName;
  final String? mechanicPhone;
  final String? mechanicPhotoUrl;
  final String jobCode;
  final String truckLine;
}
