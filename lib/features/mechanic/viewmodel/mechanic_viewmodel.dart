import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/models/job_offer.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/services/mechanic_api_service.dart';

class MechanicMyQuote {
  const MechanicMyQuote({
    required this.id,
    required this.jobCode,
    required this.truckLine,
    required this.issue,
    required this.amountDisplay,
    required this.currency,
    required this.status,
    required this.submittedLabel,
    this.etaLabel,
    this.activeJobId,
    this.jobBackendId,
    this.summaryLine,
    this.canOpenActiveJob = false,
    this.canResubmit = false,
  });

  final String id;
  final String jobCode;
  final String truckLine;
  final String issue;
  final String amountDisplay;
  final String currency;
  final String status; // WAITING | ACCEPTED | EXPIRED | DECLINED
  final String submittedLabel;
  final String? etaLabel;
  final String? activeJobId;
  final String? jobBackendId;

  /// API `summaryLine` field, e.g. "Accepted! Tap to view active job".
  final String? summaryLine;

  /// `actions.canOpenActiveJob` — whether tapping should go to the active job.
  final bool canOpenActiveJob;

  /// `actions.canResubmit` — whether a "Resubmit" button should be shown.
  final bool canResubmit;

  static String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hrs ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays} days ago';
    } catch (_) {
      return '';
    }
  }

  static String _etaLabel(dynamic eta) {
    if (eta == null) return '';
    final mins = (eta is num) ? eta.toInt() : int.tryParse('$eta') ?? 0;
    if (mins <= 0) return '';
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  factory MechanicMyQuote.fromJson(Map<String, dynamic> json) {
    final breakdown = (json['breakdown'] as Map<String, dynamic>?) ?? {};
    final total = (breakdown['total'] as num?)?.toDouble() ?? (json['amount'] as num?)?.toDouble() ?? 0.0;
    final currency = (breakdown['currency'] as String?)
        ?? (json['currency'] as String?)
        ?? 'GBP';
    final symbol = currency == 'GBP' ? '£' : (currency == 'USD' ? '\$' : currency);

    final job = (json['job'] as Map<String, dynamic>?) ?? {};
    final vehicle = (job['vehicle'] as Map<String, dynamic>?) ?? {};
    final vType = (vehicle['type'] as String?) ?? '';
    final vReg = (vehicle['registration'] as String?) ?? '';
    final truckLine = [vType, vReg].where((s) => s.isNotEmpty).join(' · ');

    final rawStatus = (json['status'] as String? ?? 'WAITING').toUpperCase();

    final actions = (json['actions'] as Map<String, dynamic>?) ?? {};
    final canOpenActiveJob = actions['canOpenActiveJob'] == true;
    final canResubmit = actions['canResubmit'] == true;
    final summaryLine = (json['summaryLine'] as String?)?.trim();

    return MechanicMyQuote(
      id: json['_id'] as String? ?? '',
      jobCode: (job['jobCode'] as String?) ?? (json['_id'] as String? ?? ''),
      truckLine: truckLine,
      issue: (job['title'] as String?) ?? '',
      amountDisplay: '$symbol${total.toStringAsFixed(0)}',
      currency: currency,
      status: rawStatus,
      submittedLabel: _timeAgo(json['createdAt'] as String?),
      etaLabel: _etaLabel(json['etaMinutes']),
      activeJobId: null,
      jobBackendId: job['_id'] as String?,
      summaryLine: (summaryLine != null && summaryLine.isNotEmpty) ? summaryLine : null,
      canOpenActiveJob: canOpenActiveJob,
      canResubmit: canResubmit,
    );
  }

}

// ─── Earnings Summary model ────────────────────────────────────────────────

class MechanicBarMonth {
  const MechanicBarMonth({
    required this.shortLabel,
    required this.net,
    required this.current,
  });

  final String shortLabel; // e.g. "Dec", "Jan"
  final int net;
  final bool current;
}

class MechanicEarningsSummary {
  const MechanicEarningsSummary({
    required this.todayGross,
    required this.monthGross,
    required this.monthNet,
    required this.allTimeNet,
    required this.currentMonthLabel,
    required this.bars,
  });

  final int todayGross;
  final int monthGross;
  final int monthNet;
  final int allTimeNet;

  /// Short name of current month, e.g. "May" — used in summary card labels.
  final String currentMonthLabel;
  final List<MechanicBarMonth> bars;

  factory MechanicEarningsSummary.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? {};
    final cards = (data['cards'] as Map<String, dynamic>?) ?? {};

    int toInt(dynamic v) =>
        (v is num) ? v.toInt() : (int.tryParse('$v') ?? 0);

    final series =
        ((data['monthlyNetSeries'] as List<dynamic>?) ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

    // Mark last entry as current month
    final bars = series.asMap().entries.map((e) {
      final idx = e.key;
      final s = e.value;
      final labelFull = (s['label'] as String?) ?? '';
      final shortLabel = labelFull.length >= 3 ? labelFull.substring(0, 3) : labelFull;
      return MechanicBarMonth(
        shortLabel: shortLabel,
        net: toInt(s['net']),
        current: idx == series.length - 1,
      );
    }).toList();

    // Current month name from last series entry
    final lastLabel = series.isNotEmpty
        ? ((series.last['label'] as String?) ?? '')
        : '';
    final currentMonthLabel =
        lastLabel.isNotEmpty ? lastLabel.split(' ').first : 'This month';

    return MechanicEarningsSummary(
      todayGross: toInt(cards['todayGross']),
      monthGross: toInt(cards['monthGross']),
      monthNet: toInt(cards['monthNet']),
      allTimeNet: toInt(cards['allTimeNet']),
      currentMonthLabel: currentMonthLabel,
      bars: bars,
    );
  }
}

// ─── My Active Jobs model ──────────────────────────────────────────────────

class MechanicActiveJob {
  const MechanicActiveJob({
    required this.backendId,
    required this.jobCode,
    required this.truck,
    required this.fleet,
    required this.issue,
    required this.pay,
    required this.statusLabel,
    required this.statusTone,
    this.distanceLabel,
    this.scheduledForLabel,
    this.etaMinutes,
  });

  final String backendId;
  final String jobCode;
  final String truck;
  final String fleet;
  final String issue;
  final String pay;

  /// From `statusUi.label`, e.g. "EN ROUTE", "AWAITING APPROVAL".
  final String statusLabel;

  /// From `statusUi.tone`: "green" | "blue" | "amber" | "yellow" | "red" | "neutral".
  final String statusTone;

  final String? distanceLabel;
  final String? scheduledForLabel;
  final int? etaMinutes;

  static String _moneyDisplay(dynamic amount, String currency) {
    final sym = switch (currency.toUpperCase()) {
      'GBP' => '£',
      'USD' => r'$',
      'EUR' => '€',
      _ => '',
    };
    final v = (amount is num) ? amount.toInt() : (int.tryParse('$amount') ?? 0);
    return '$sym$v';
  }

  static String? _scheduledLabel(String? iso) {
    if (iso == null) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dDay = DateTime(dt.year, dt.month, dt.day);
      final diff = dDay.difference(today).inDays;
      final hhmm =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (diff == 0) return 'Today · $hhmm';
      if (diff == 1) return 'Tomorrow · $hhmm';
      return '${dt.day}/${dt.month} · $hhmm';
    } catch (_) {
      return null;
    }
  }

  factory MechanicActiveJob.fromJson(Map<String, dynamic> json) {
    final vehicle = (json['vehicle'] as Map<String, dynamic>?) ?? {};
    final vType = (vehicle['type'] as String?) ?? '';
    final vReg = (vehicle['registration'] as String?) ?? '';
    final truckLine = [vType, vReg].where((s) => s.isNotEmpty).join(' · ');

    final fleet = (json['fleet'] as Map<String, dynamic>?) ?? {};
    final fleetName = (fleet['companyName'] as String?) ?? '';

    final statusUi = (json['statusUi'] as Map<String, dynamic>?) ?? {};
    final statusLabel =
        ((statusUi['label'] as String?) ?? (json['status'] as String?) ?? '').trim();
    final statusTone = ((statusUi['tone'] as String?) ?? 'neutral').toLowerCase();

    final currency = (json['currency'] as String?) ?? 'GBP';
    final payAmount = json['acceptedAmount'] ?? json['finalAmount'] ?? json['estimatedPayout'];

    final tracking = (json['tracking'] as Map<String, dynamic>?);
    final etaMinutes = (tracking?['etaMinutes'] is num)
        ? (tracking!['etaMinutes'] as num).toInt()
        : null;

    final distMiles = json['distanceMiles'];
    final distLabel = (distMiles is num && distMiles > 0)
        ? '${distMiles.toStringAsFixed(1)} mi'
        : null;

    return MechanicActiveJob(
      backendId: (json['_id'] as String?) ?? '',
      jobCode: (json['jobCode'] as String?) ?? '',
      truck: truckLine,
      fleet: fleetName,
      issue: (json['title'] as String?) ?? '',
      pay: _moneyDisplay(payAmount, currency),
      statusLabel: statusLabel,
      statusTone: statusTone,
      distanceLabel: distLabel,
      scheduledForLabel: _scheduledLabel(json['scheduledFor'] as String?),
      etaMinutes: etaMinutes,
    );
  }
}

// ─── ViewModel ─────────────────────────────────────────────────────────────

typedef _Coord = ({double lat, double lng});

class MechanicViewModel extends ChangeNotifier {
  MechanicViewModel(this._jobs, this._auth, this._api);

  final JobRepository _jobs;
  final AuthRepository _auth;
  final MechanicApiService _api;

  String tab = 'feed';
  bool online = true;
  int radiusMi = 15;
  int? maxDistMi;
  String postcode = 'M1 1AE';
  String city = 'Manchester';
  bool showHelp = false;

  // My Quotes
  List<MechanicMyQuote> myQuotes = [];
  bool myQuotesLoading = false;
  String? myQuotesError;

  // My Active Jobs
  List<MechanicActiveJob> myActiveJobs = [];
  bool myJobsLoading = false;
  String? myJobsError;
  int myJobsTotalActive = 0;

  // Earnings Summary
  MechanicEarningsSummary? earningsSummary;
  bool earningsLoading = false;
  String? earningsError;

  List<JobOffer> get rawJobs => _jobs.mechanicJobsNearby();

  List<JobOffer> filteredJobs() {
    var list = rawJobs.where((j) => j.distanceMi <= radiusMi);
    if (maxDistMi != null) {
      list = list.where((j) => j.distanceMi <= maxDistMi!);
    }
    return list.toList()..sort((a, b) => a.distanceMi.compareTo(b.distanceMi));
  }

  void setTab(String t) {
    tab = t;
    notifyListeners();
  }

  static const Map<String, _Coord> _cityCoords = {
    'Manchester': (lat: 53.4808, lng: -2.2426),
    'London': (lat: 51.5074, lng: -0.1278),
    'Birmingham': (lat: 52.4862, lng: -1.8904),
    'Leeds': (lat: 53.8008, lng: -1.5491),
    'Liverpool': (lat: 53.4084, lng: -2.9916),
    'Sheffield': (lat: 53.3811, lng: -1.4701),
    'Bristol': (lat: 51.4545, lng: -2.5879),
  };

  _Coord _resolvedCoords() {
    return _cityCoords[city] ?? (lat: 53.4808, lng: -2.2426);
  }

  Future<_Coord> _getRealCoordsOrFallback() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _resolvedCoords();

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _resolvedCoords();
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return _resolvedCoords();
    }
  }

  Future<void> toggleOnline() async {
    final next = !online;
    online = next;
    notifyListeners();

    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Missing access token. Please login again.');
      }
      final coords = await _getRealCoordsOrFallback();
      await _api.updateAvailability(
        accessToken: token,
        availability: next ? 'ONLINE' : 'OFFLINE',
        latitude: coords.lat,
        longitude: coords.lng,
      );
    } catch (_) {
      online = !next; // revert
      notifyListeners();
      rethrow;
    }
  }

  void setRadius(int v) {
    radiusMi = v;
    if (maxDistMi != null && maxDistMi! > radiusMi) maxDistMi = null;
    notifyListeners();
  }

  void applyLocation(String newPostcode) {
    final upper = newPostcode.trim().toUpperCase();
    postcode = upper;
    final alnum = upper.replaceAll(RegExp(r'[^A-Z]'), '');
    final prefix = alnum.length >= 2 ? alnum.substring(0, 2) : (alnum.isEmpty ? 'M1' : alnum);
    const cityMap = {
      'M': 'Manchester',
      'B': 'Birmingham',
      'E': 'London',
      'N': 'London',
      'W': 'London',
      'LS': 'Leeds',
      'S': 'Sheffield',
      'L': 'Liverpool',
      'BS': 'Bristol',
    };
    city = cityMap[prefix] ?? cityMap[prefix[0]] ?? upper.split(' ').first;
    notifyListeners();
  }

  void setMaxDist(int? d) {
    maxDistMi = d;
    notifyListeners();
  }

  Future<void> loadMyQuotes() async {
    myQuotesLoading = true;
    myQuotesError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Missing access token. Please login again.');
      }
      final body = await _api.fetchMyQuotes(accessToken: token);
      final list = (body['data'] as List<dynamic>?) ?? [];
      myQuotes = list
          .whereType<Map<String, dynamic>>()
          .map(MechanicMyQuote.fromJson)
          .toList();
    } catch (e) {
      myQuotesError = e.toString();
    } finally {
      myQuotesLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadEarnings() async {
    earningsLoading = true;
    earningsError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Missing access token. Please login again.');
      }
      final body = await _api.fetchEarningsSummary(accessToken: token);
      earningsSummary = MechanicEarningsSummary.fromJson(body);
    } catch (e) {
      earningsError = e.toString();
    } finally {
      earningsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyJobs() async {
    myJobsLoading = true;
    myJobsError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Missing access token. Please login again.');
      }
      final body = await _api.fetchMyJobs(accessToken: token);
      final meta = (body['meta'] as Map<String, dynamic>?) ?? {};
      myJobsTotalActive = (meta['activeCount'] as num?)?.toInt() ??
          (meta['total'] as num?)?.toInt() ??
          0;
      final list = (body['data'] as List<dynamic>?) ?? [];
      myActiveJobs = list
          .whereType<Map<String, dynamic>>()
          .map(MechanicActiveJob.fromJson)
          .toList();
    } catch (e) {
      myJobsError = e.toString();
    } finally {
      myJobsLoading = false;
      notifyListeners();
    }
  }

  void openHelp() {
    showHelp = true;
    notifyListeners();
  }

  void closeHelp() {
    showHelp = false;
    notifyListeners();
  }

  String get bottomNavResolved {
    if (tab == 'job-tracker' || tab == 'quote-detail') return 'my-jobs';
    if (tab == 'earnings' || tab == 'edit-profile' || tab == 'payment-methods') return 'profile';
    return tab;
  }
}
