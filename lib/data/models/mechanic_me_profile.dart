/// Mechanic-facing row from [`GET /api/v1/users/me`](…) for Profile tab (`mechanicProfile` + `performance` + `preferences`).
class MechanicMeProfile {
  const MechanicMeProfile({
    required this.userUpdatedAt,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.profilePhotoUrl,
    required this.jobsDone,
    required this.avgRating,
    required this.ratingCount,
    required this.responseMinutes,
    required this.hourlyRate,
    required this.emergencyRate,
    required this.callOutFee,
    required this.rateCurrency,
    required this.serviceRadiusMiles,
    required this.baseLocationText,
    required this.basePostcode,
    required this.bankDisplayName,
    required this.bankAccountMasked,
    required this.bankSortCode,
    required this.billingAddress,
    required this.vatNumber,
    required this.vatRegistered,
    required this.pushEnabled,
    required this.alertRadiusMiles,
    required this.notifNewBreakdownJobs,
    required this.notifJobAcceptedDeclined,
    required this.notifPaymentReceived,
    required this.notifSystemAlerts,
    required this.notifAppAlerts,
    required this.paymentCardLabel,
    required this.employerCompanyName,
    required this.jobsThisWeek,
  });

  /// `data.updatedAt` — bumps when syncing local UI state from server.
  final String userUpdatedAt;

  final String displayName;
  final String email;
  final String phone;
  final String? profilePhotoUrl;

  /// From [`performance.jobsDone`](…) with fallback to `mechanicProfile.stats.jobsDone`.
  final int jobsDone;

  final double avgRating;
  final int ratingCount;
  final int responseMinutes;

  final num? hourlyRate;
  final num? emergencyRate;
  final num? callOutFee;
  final String rateCurrency;

  /// Service area radius (`mechanicProfile.serviceRadiusMiles`).
  final num? serviceRadiusMiles;

  final String baseLocationText;
  final String basePostcode;

  final String? bankDisplayName;
  final String? bankAccountMasked;
  final String? bankSortCode;
  final String? billingAddress;
  final String? vatNumber;
  final bool vatRegistered;

  final bool pushEnabled;
  final int alertRadiusMiles;

  final bool notifNewBreakdownJobs;
  final bool notifJobAcceptedDeclined;
  final bool notifPaymentReceived;
  final bool notifSystemAlerts;
  final bool notifAppAlerts;

  /// `paymentSummary.cardLabel` for secondary profile actions.
  final String? paymentCardLabel;

  /// Populated for mechanic employees from `companyMembership.company` when expanded.
  final String employerCompanyName;

  /// From `performance` when API exposes a weekly count (else `0`).
  final int jobsThisWeek;

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  static dynamic _completionEntry(Map<String, dynamic> data, String groupKey, String entryKey) {
    final completion = data['profileCompletion'];
    if (completion is! Map<String, dynamic>) return null;
    final items = completion['items'];
    if (items is! List<dynamic>) return null;
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      if (raw['key'] != groupKey) continue;
      final entries = raw['entries'];
      if (entries is! List<dynamic>) continue;
      for (final e in entries) {
        if (e is Map<String, dynamic> && e['key'] == entryKey) {
          return e['value'];
        }
      }
    }
    return null;
  }

  static String? _trimStr(dynamic v) {
    if (v is! String) return null;
    final s = v.trim();
    return s.isEmpty ? null : s;
  }

  /// Same idea as [FleetMeProfileUi.fromApiBody]: some backends wrap the user in
  /// `{ "data": { ... } }`, others return the user object at the root of the JSON.
  static Map<String, dynamic> _unwrapData(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return envelope;
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return const {};
  }

  factory MechanicMeProfile.fromUsersMeEnvelope(Map<String, dynamic> envelope) {
    final data = _unwrapData(envelope);
    final mp = _asMap(data['mechanicProfile'] ?? envelope['mechanicProfile']);
    final perf = _asMap(data['performance'] ?? envelope['performance']);
    final prefs = _asMap(data['preferences'] ?? envelope['preferences']);
    final notif = _asMap(prefs['notifications']);
    final stats = _asMap(mp['stats']);
    final rating = _asMap(mp['rating']);
    final pay = _asMap(data['paymentSummary'] ?? envelope['paymentSummary']);

    final perfJobs = perf['jobsDone'];
    final statJobs = stats['jobsDone'];
    final jobsDone = perfJobs != null ? _toInt(perfJobs) : _toInt(statJobs);

    final perfRating = perf['avgRating'] ?? perf['averageRating'] ?? perf['average'];
    final avgRating = perfRating != null ? _toDouble(perfRating) : _toDouble(rating['average']);

    final perfRc = perf['ratingCount'];
    final ratingCount = perfRc != null ? _toInt(perfRc) : _toInt(rating['count']);

    final perfResp = perf['responseMinutes'];
    final responseMinutes =
        perfResp != null ? _toInt(perfResp) : _toInt(stats['responseMinutesAvg']);

    final emergencyRaw = mp['emergencyRate'] ?? _completionEntry(data, 'ratesCoverage', 'emergencyRate');
    num? emergencyRate;
    if (emergencyRaw is num) {
      emergencyRate = emergencyRaw;
    } else if (emergencyRaw != null) {
      emergencyRate = num.tryParse('$emergencyRaw');
    }

    final push = prefs['pushEnabled'] == true || data['pushEnabled'] == true || envelope['pushEnabled'] == true;
    final alertR = () {
      final a = _toInt(prefs['alertRadiusMiles']);
      if (a > 0) return a;
      final b = _toInt(data['alertRadiusMiles']);
      return b > 0 ? b : 0;
    }();
    final alertRadiusMiles = alertR > 0 ? alertR : 25;

    final email = _trimStr(data['email']) ?? _trimStr(mp['email']) ?? _trimStr(envelope['email']) ?? '';
    final phone = _trimStr(data['phone']) ?? _trimStr(mp['phone']) ?? _trimStr(mp['phoneNumber']) ?? '';

    var employerCompanyName = '';
    final cm = _asMap(data['companyMembership'] ?? envelope['companyMembership']);
    final co = cm['company'];
    final coMap = _asMap(co);
    if (coMap.isNotEmpty) {
      employerCompanyName = _trimStr(coMap['companyName']) ?? _trimStr(coMap['name']) ?? _trimStr(coMap['tradingName']) ?? '';
    }
    if (employerCompanyName.isEmpty) {
      employerCompanyName = _trimStr(data['employerCompanyName']) ?? '';
    }

    final jobsThisWeek = _toInt(
      perf['jobsThisWeek'] ?? perf['jobsCompletedThisWeek'] ?? perf['completedThisWeek'],
    );

    final displayName = _trimStr(mp['displayName']) ??
        _trimStr(data['displayName']) ??
        _trimStr(data['fullName']) ??
        _trimStr(envelope['displayName']) ??
        _trimStr(envelope['fullName']) ??
        'Mechanic';

    return MechanicMeProfile(
      userUpdatedAt: _trimStr(data['updatedAt']) ?? _trimStr(envelope['updatedAt']) ?? '',
      displayName: displayName,
      email: email,
      phone: phone,
      profilePhotoUrl: _trimStr(mp['profilePhotoUrl']) ?? _trimStr(data['profilePhotoUrl']),
      jobsDone: jobsDone,
      avgRating: avgRating,
      ratingCount: ratingCount,
      responseMinutes: responseMinutes,
      hourlyRate: mp['hourlyRate'] is num ? mp['hourlyRate'] as num : num.tryParse('${mp['hourlyRate']}'),
      emergencyRate: emergencyRate,
      callOutFee: mp['callOutFee'] is num ? mp['callOutFee'] as num : num.tryParse('${mp['callOutFee']}'),
      rateCurrency: _trimStr(mp['rateCurrency']) ?? 'GBP',
      serviceRadiusMiles: mp['serviceRadiusMiles'] is num
          ? mp['serviceRadiusMiles'] as num
          : num.tryParse('${mp['serviceRadiusMiles']}'),
      baseLocationText: _trimStr(mp['baseLocationText']) ?? '',
      basePostcode: _trimStr(mp['basePostcode']) ?? '',
      bankDisplayName: _trimStr(mp['bankDisplayName']),
      bankAccountMasked: _trimStr(mp['bankAccountMasked']),
      bankSortCode: _trimStr(mp['bankSortCode']),
      billingAddress: _trimStr(mp['billingAddress']),
      vatNumber: _trimStr(mp['vatNumber']),
      vatRegistered: mp['vatRegistered'] == true,
      pushEnabled: push,
      alertRadiusMiles: alertRadiusMiles,
      notifNewBreakdownJobs: notif['newBreakdownJobs'] == true,
      notifJobAcceptedDeclined: notif['jobAcceptedDeclined'] == true,
      notifPaymentReceived: notif['paymentReceived'] == true,
      notifSystemAlerts: notif['systemAlerts'] == true || notif['systemAndAppAlerts'] == true,
      notifAppAlerts: notif['appAlerts'] == true,
      paymentCardLabel: _trimStr(pay['cardLabel']),
      employerCompanyName: employerCompanyName,
      jobsThisWeek: jobsThisWeek,
    );
  }

  /// ISO currency code → compact symbol/prefix for rates UI.
  static String currencyPrefix(String code) {
    switch (code.toUpperCase()) {
      case 'GBP':
        return '£';
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'ZAR':
        return 'R ';
      default:
        return '${code.toUpperCase()} ';
    }
  }

  String formatMoney(num? amount) {
    if (amount == null) return '—';
    final sym = currencyPrefix(rateCurrency);
    final v = amount == amount.roundToDouble() ? amount.toInt().toString() : amount.toStringAsFixed(2);
    return '$sym$v';
  }

  String get baseLocationLine {
    final loc = baseLocationText.trim();
    final pc = basePostcode.trim();
    if (loc.isEmpty && pc.isEmpty) return '—';
    final shortPc = _outwardPostcode(pc);
    if (loc.isEmpty) return shortPc.isEmpty ? pc : shortPc;
    if (shortPc.isEmpty) return loc;
    return '$loc, $shortPc';
  }

  static String _outwardPostcode(String full) {
    final p = full.trim();
    if (p.isEmpty) return '';
    final parts = p.split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : p;
  }
}
