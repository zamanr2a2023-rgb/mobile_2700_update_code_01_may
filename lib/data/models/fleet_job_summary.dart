/// Fleet-side job tracking summary.
class FleetJobSummary {
  const FleetJobSummary({
    required this.id,
    this.backendId,
    required this.truck,
    required this.issue,
    required this.status,
    required this.urgency,
    required this.urgencyColorHex,
    required this.urgencyBgHex,
    required this.statusColorHex,
    required this.statusBgHex,
    this.mechanic,
    this.pay,
  });

  /// Human-readable job code (e.g. TF-3302). Shown in UI.
  final String id;

  /// Mongo/backend id for `GET /api/v1/jobs/:id/quotes` etc. Null for local demo rows.
  final String? backendId;
  final String truck;
  final String issue;
  final String status;
  final String urgency;
  final int urgencyColorHex;
  final int urgencyBgHex;
  final int statusColorHex;
  final int statusBgHex;

  /// `assignedMechanic.displayName` from the API, e.g. "James Mitchell".
  final String? mechanic;

  /// Formatted payout string, e.g. "£275". Derived from finalAmount/acceptedAmount/estimatedPayout.
  final String? pay;
}
