import '../../features/categories/job_taxonomy.dart';

/// Job card in mechanic feed.
class JobOffer {
  const JobOffer({
    required this.id,
    required this.truck,
    required this.issue,
    required this.distanceMi,
    required this.urgency,
    required this.pay,
    required this.posted,
    required this.quotes,
    this.backendId,
  });

  final String id;
  final String truck;
  final String issue;
  final double distanceMi;
  final JobUrgency urgency;
  final String pay;
  final String posted;
  final int quotes;

  /// Mongo `_id` from API. Null for local demo rows.
  final String? backendId;

  factory JobOffer.fromJson(Map<String, dynamic> json) {
    final vehicle = (json['vehicle'] as Map<String, dynamic>?) ?? {};
    final vType = (vehicle['type'] as String?) ?? '';
    final vReg = (vehicle['registration'] as String?) ?? '';
    final truck = [vType, vReg].where((s) => s.isNotEmpty).join(' · ');

    final rawUrgency = ((json['urgency'] as String?) ?? '').toUpperCase();
    final urgency = switch (rawUrgency) {
      'CRITICAL' => JobUrgency.critical,
      'HIGH' => JobUrgency.high,
      'MEDIUM' => JobUrgency.medium,
      _ => JobUrgency.low,
    };

    final currency = (json['currency'] as String?) ?? 'GBP';
    final sym = currency == 'GBP' ? '£' : (currency == 'USD' ? r'$' : currency);
    final payNum = json['acceptedAmount'] ?? json['finalAmount'] ?? json['estimatedPayout'];
    final payInt = (payNum is num) ? payNum.toInt() : (int.tryParse('$payNum') ?? 0);

    final distRaw = json['distanceMiles'];
    final distMi = (distRaw is num) ? distRaw.toDouble() : 0.0;

    final quoteSummary = (json['quoteSummary'] as Map<String, dynamic>?) ?? {};
    final quotes = (quoteSummary['count'] as num?)?.toInt() ??
        (json['quoteCount'] as num?)?.toInt() ?? 0;

    return JobOffer(
      backendId: (json['_id'] as String?)?.trim(),
      id: (json['jobCode'] as String?) ?? '',
      truck: truck,
      issue: (json['title'] as String?) ?? '',
      distanceMi: distMi,
      urgency: urgency,
      pay: '$sym$payInt',
      posted: (json['postedAgoLabel'] as String?) ?? '',
      quotes: quotes,
    );
  }
}
