/// One mechanic quote from `GET /api/v1/jobs/:jobId/quotes`.
class FleetJobQuote {
  const FleetJobQuote({
    required this.id,
    this.etaMinutes,
    required this.currency,
    required this.labour,
    required this.callOutFee,
    required this.parts,
    required this.total,
    required this.mechanicName,
    required this.mechanicRating,
    required this.jobsDone,
    required this.verified,
    required this.specialtySummary,
    this.apiStatus,
    this.mechanicPhone,
    this.createdAt,
    this.profilePhotoUrl,
    this.distanceKm,
  });

  final String id;
  final int? etaMinutes;
  final String currency;
  final double labour;
  final double callOutFee;
  final double parts;
  final double total;

  final String mechanicName;
  final double mechanicRating;
  final int jobsDone;
  final bool verified;
  final String specialtySummary;

  /// Raw quote status from API, e.g. `ACCEPTED`, `EXPIRED`.
  final String? apiStatus;

  /// E.164 or display phone from `mechanic.phone`.
  final String? mechanicPhone;

  final DateTime? createdAt;
  final String? profilePhotoUrl;
  final double? distanceKm;

  factory FleetJobQuote.fromJson(Map<String, dynamic> m) {
    final mech = (m['mechanic'] is Map<String, dynamic>) ? m['mechanic'] as Map<String, dynamic> : const <String, dynamic>{};
    final bd = (m['breakdown'] is Map<String, dynamic>) ? m['breakdown'] as Map<String, dynamic> : const <String, dynamic>{};

    double toD(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;

    final photo = mech['profilePhotoUrl'] ?? mech['profilePhoto'] ?? mech['avatarUrl'];

    int? parseEta(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.round();
      return int.tryParse('$v');
    }

    final phoneRaw = (mech['phone'] as String?)?.trim();

    return FleetJobQuote(
      id: ((m['_id'] as String?) ?? '').trim(),
      etaMinutes: parseEta(m['etaMinutes']),
      currency: ((bd['currency'] as String?) ?? (m['currency'] as String?) ?? 'GBP').trim().isEmpty
          ? 'GBP'
          : ((bd['currency'] as String?) ?? (m['currency'] as String?) ?? 'GBP').trim(),
      labour: toD(bd['labour']),
      callOutFee: toD(bd['callOutFee']),
      parts: toD(bd['parts']),
      total: toD(bd['total']),
      mechanicName: ((mech['displayName'] as String?) ?? '—').trim().isEmpty ? '—' : (mech['displayName'] as String?)!.trim(),
      mechanicRating: toD(mech['rating']),
      jobsDone: (mech['jobsDone'] is num) ? (mech['jobsDone'] as num).round() : int.tryParse('${mech['jobsDone']}') ?? 0,
      verified: mech['verified'] == true,
      specialtySummary: ((mech['specialtySummary'] as String?) ?? '').trim(),
      apiStatus: (m['status'] as String?)?.trim(),
      mechanicPhone: (phoneRaw != null && phoneRaw.isNotEmpty) ? phoneRaw : null,
      createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? ''),
      profilePhotoUrl: photo is String && photo.trim().isNotEmpty ? photo.trim() : null,
      distanceKm: null,
    );
  }

  static String formatMoney(double amount, String currency) {
    final sym = switch (currency.toUpperCase()) {
      'GBP' => '£',
      'USD' => r'$',
      'EUR' => '€',
      _ => '',
    };
    return '$sym${amount.round()}';
  }

  String get labourDisplay => formatMoney(labour, currency);
  String get calloutDisplay => formatMoney(callOutFee, currency);
  String get partsDisplay => formatMoney(parts, currency);
  String get totalDisplay => formatMoney(total, currency);

  String get etaLabel =>
      (etaMinutes != null && etaMinutes! > 0) ? 'ETA $etaMinutes min' : 'ETA —';

  String get respondedLabel {
    final t = createdAt;
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.isNegative) return 'Just now';
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 48) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}
