import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../data/models/fleet_billing_payment_method.dart';
import '../../../data/models/job_offer.dart';
import '../../../data/models/mechanic_job_detail.dart';
import '../../../data/models/mechanic_me_profile.dart';
import '../../../data/models/job_chat_models.dart';
import '../models/mechanic_profile_extras.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/services/mechanic_api_service.dart';
import '../../../data/services/chat_api_service.dart';
// ignore: unused_import
import '../../../features/categories/job_taxonomy.dart';

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

// ─── Earnings jobs list (`GET /api/v1/earnings/jobs`) ───────────────────────

class MechanicEarningsJobsListMeta {
  const MechanicEarningsJobsListMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  static MechanicEarningsJobsListMeta? maybeParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    int toI(dynamic v) => (v is num) ? v.toInt() : (int.tryParse('$v') ?? 0);
    return MechanicEarningsJobsListMeta(
      page: toI(raw['page']),
      limit: toI(raw['limit']),
      total: toI(raw['total']),
      totalPages: toI(raw['totalPages']),
    );
  }
}

class MechanicCompletedEarningJob {
  const MechanicCompletedEarningJob({
    required this.id,
    required this.jobCode,
    required this.dateLabel,
    required this.vehicleLine,
    required this.issueLine,
    required this.customerName,
    required this.durationLabel,
    required this.rating,
    required this.netEarnedDisplay,
    required this.grossDisplay,
    required this.feeDisplay,
    required this.netDisplay,
    required this.platformFeePercent,
    required this.grossAmount,
    required this.platformFeeAmount,
    required this.netAmount,
    required this.currency,
    required this.invoiceNo,
    required this.invoiceDownloadPath,
  });

  final String id;
  final String jobCode;
  final String dateLabel;
  final String vehicleLine;
  final String issueLine;
  final String customerName;
  final String durationLabel;
  final int rating;
  final String netEarnedDisplay;
  final String grossDisplay;
  final String feeDisplay;
  final String netDisplay;
  final int platformFeePercent;
  final double grossAmount;
  final double platformFeeAmount;
  final double netAmount;
  final String currency;
  final String invoiceNo;
  final String invoiceDownloadPath;

  static String _s(dynamic v) => v == null ? '' : v.toString().trim();

  static double _d(dynamic x) => (x is num) ? x.toDouble() : (double.tryParse('$x') ?? 0);

  static String _moneyLabel(double amount, String currency) {
    final c = currency.toUpperCase().trim().isEmpty ? 'GBP' : currency.trim().toUpperCase();
    final sym = c == 'GBP' ? '£' : (c == 'USD' ? r'$' : '$c ');
    if (amount == amount.roundToDouble()) return '$sym${amount.round()}';
    return '$sym${amount.toStringAsFixed(2)}';
  }

  factory MechanicCompletedEarningJob.fromJson(Map<String, dynamic> json) {
    final job = (json['job'] as Map<String, dynamic>?) ?? {};
    final inv = (json['invoice'] as Map<String, dynamic>?) ?? {};
    final ui = (json['ui'] as Map<String, dynamic>?) ?? {};
    final bd = (ui['breakdown'] as Map<String, dynamic>?) ?? {};
    final primary = (ui['primaryAction'] as Map<String, dynamic>?) ?? {};

    final currency = _s(ui['currency']).isNotEmpty
        ? _s(ui['currency'])
        : (_s(json['currency']).isNotEmpty ? _s(json['currency']) : 'GBP');

    var grossAmount = _d(json['grossAmount']);
    if (grossAmount == 0) grossAmount = _d(bd['grossAmount']);
    if (grossAmount == 0) grossAmount = _d(inv['totalAmount']);

    var netAmount = _d(json['netAmount']);
    if (netAmount == 0) netAmount = _d(bd['netAmount']);

    var platformFeeAmount = _d(json['platformFee']);
    if (platformFeeAmount == 0) platformFeeAmount = _d(bd['platformFeeAmount']);

    final pctRaw = (json['platformFeePercent'] as num?)?.toDouble() ??
        (bd['platformFeePercent'] as num?)?.toDouble() ??
        12;
    final platformFeePercent = pctRaw.round();

    var grossDisplay = _s(ui['grossLabel']);
    if (grossDisplay.isEmpty) grossDisplay = _moneyLabel(grossAmount, currency);

    var netEarnedDisplay = _s(ui['netEarnedLabel']);
    if (netEarnedDisplay.isEmpty) netEarnedDisplay = _moneyLabel(netAmount, currency);

    var netDisplay = _s(ui['netLabel']);
    if (netDisplay.isEmpty) netDisplay = netEarnedDisplay;

    var feeDisplay = _s(ui['platformFeeWholeLabel']);
    if (feeDisplay.isEmpty) feeDisplay = _s(ui['platformFeeLabel']);
    if (feeDisplay.isEmpty) {
      feeDisplay = '-${_moneyLabel(platformFeeAmount, currency)}'.replaceFirst('--', '-');
    }

    var issueLine = _s(ui['issueLine']);
    if (issueLine.isEmpty) issueLine = _s(job['issueSummary']);
    if (issueLine.isEmpty) issueLine = _s(job['completionSummary']);
    if (issueLine.isEmpty) issueLine = _s(job['description']);
    if (issueLine.isEmpty) issueLine = _s(json['notes']);

    final path = _s(primary['path']).isNotEmpty ? _s(primary['path']) : _s(inv['downloadPath']);

    return MechanicCompletedEarningJob(
      id: _s(json['_id']),
      jobCode: _s(ui['jobCode']).isNotEmpty ? _s(ui['jobCode']) : _s(job['jobCode']),
      dateLabel: _s(ui['headlineDateLabel']).isNotEmpty ? _s(ui['headlineDateLabel']) : _s(job['completedAtLabel']),
      vehicleLine: _s(ui['vehicleLine']).isNotEmpty ? _s(ui['vehicleLine']) : _s(job['vehicleDisplay']),
      issueLine: issueLine,
      customerName: _s(ui['customerName']).isNotEmpty ? _s(ui['customerName']) : _s(job['customerName']),
      durationLabel: _s(ui['durationLabel']).isNotEmpty ? _s(ui['durationLabel']) : _s(job['durationLabel']),
      rating: ((ui['rating'] as num?)?.toInt() ?? (job['rating'] as num?)?.toInt() ?? 0).clamp(0, 5),
      netEarnedDisplay: netEarnedDisplay,
      grossDisplay: grossDisplay,
      feeDisplay: feeDisplay,
      netDisplay: netDisplay,
      platformFeePercent: platformFeePercent,
      grossAmount: grossAmount,
      platformFeeAmount: platformFeeAmount,
      netAmount: netAmount,
      currency: currency,
      invoiceNo: _s(inv['invoiceNo']),
      invoiceDownloadPath: path,
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
  final ChatApiService _chat = ChatApiService();

  String tab = 'feed';
  bool online = true;
  int radiusMi = 15;
  int? maxDistMi;
  String postcode = 'M1 1AE';
  String city = 'Manchester';
  bool showHelp = false;

  // Job Feed
  List<JobOffer> feedJobs = [];
  bool feedLoading = false;
  String? feedError;

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

  /// `GET /api/v1/earnings/jobs` — completed jobs for Earnings & Invoices list.
  List<MechanicCompletedEarningJob> earningsJobs = [];
  MechanicEarningsJobsListMeta? earningsJobsMeta;
  bool earningsJobsLoading = false;
  String? earningsJobsError;

  /// Parsed `GET /api/v1/users/me` payload for mechanic Profile tab.
  MechanicMeProfile? meProfile;
  bool meProfileLoading = false;
  String? meProfileError;
  bool meProfilePatchBusy = false;
  String? meProfilePatchError;

  /// `GET /api/v1/billing/payment-methods` (same billing API as fleet).
  List<FleetBillingPaymentMethod> billingPaymentMethods = const [];
  bool billingPaymentMethodsLoading = false;
  String? billingPaymentMethodsError;

  /// Active job tracker (`GET/PATCH /api/v1/jobs/:id`).
  String? selectedJobTrackerId;
  MechanicJobDetailParsed? jobTrackerDetail;
  Map<String, dynamic>? jobWorkCompleteEnvelope;
  bool jobTrackerLoading = false;
  String? jobTrackerError;
  bool jobTrackerActionBusy = false;

  /// Job detail / quote flow: opened from feed (`GET /api/v1/jobs/:id`).
  String? selectedQuoteJobId;
  MechanicJobDetailParsed? jobQuoteDetail;
  bool jobQuoteDetailLoading = false;
  String? jobQuoteDetailError;
  bool quoteSubmitBusy = false;

  /// Profile → Messages (`GET /api/v1/chat/threads`).
  List<MechanicMessageThread> messageThreads = [];
  bool messageThreadsLoading = false;
  String? messageThreadsError;

  MechanicMessageThread? activeChatPeer;

  List<JobOffer> get rawJobs => _jobs.mechanicJobsNearby();

  Future<void> loadMessageThreads() async {
    messageThreadsLoading = true;
    messageThreadsError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Missing access token. Please login again.');
      }
      final env = await _chat.fetchThreads(accessToken: token);
      final rows = ChatApiService.parseThreadsEnvelope(env);
      messageThreads = rows
          .map(
            (r) => MechanicMessageThread(
              jobId: r.conversationId,
              title: r.title,
              subtitle: r.subtitle,
              photoUrl: r.counterpartyPhotoUrl,
              preview: r.preview,
              timeLabel: formatChatThreadTime(r.sortTimeIso),
            ),
          )
          .toList();
    } catch (e) {
      messageThreadsError = e.toString();
    } finally {
      messageThreadsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMeProfile() async {
    meProfileLoading = true;
    meProfileError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Missing access token. Please login again.');
      }
      final body = await _api.fetchMe(accessToken: token);
      meProfile = MechanicMeProfile.fromUsersMeEnvelope(body);
    } catch (e) {
      meProfileError = e.toString();
    } finally {
      meProfileLoading = false;
      notifyListeners();
    }
  }

  /// `PATCH /api/v1/users/me` — partial updates; refreshes [meProfile] from the response envelope.
  Future<void> patchUsersMe(Map<String, dynamic> payload) async {
    final session = await _auth.getSession();
    final token = session?.accessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Missing access token. Please login again.');
    }
    meProfilePatchBusy = true;
    meProfilePatchError = null;
    notifyListeners();
    try {
      final body = await _api.updateMe(accessToken: token, payload: payload);
      meProfile = MechanicMeProfile.fromUsersMeEnvelope(body);
      meProfileError = null;
    } catch (e) {
      meProfilePatchError = e.toString();
      rethrow;
    } finally {
      meProfilePatchBusy = false;
      notifyListeners();
    }
  }

  /// Notification toggles + alert radius — `PATCH /api/v1/users/me` with nested `preferences`
  /// (matches `GET /users/me` shape: `preferences.pushEnabled`, `preferences.notifications`, …).
  Future<void> patchMechanicNotificationSettings({
    required bool pushEnabled,
    required int alertRadiusMiles,
    required bool newBreakdownJobs,
    required bool jobAcceptedDeclined,
    required bool paymentReceived,
    required bool systemAlerts,
    required bool appAlerts,
  }) {
    return patchUsersMe({
      'preferences': {
        'pushEnabled': pushEnabled,
        'alertRadiusMiles': alertRadiusMiles,
        'notifications': {
          'newBreakdownJobs': newBreakdownJobs,
          'jobAcceptedDeclined': jobAcceptedDeclined,
          'paymentReceived': paymentReceived,
          'systemAlerts': systemAlerts,
          'appAlerts': appAlerts,
        },
      },
    });
  }

  /// Full mechanic profile edit (personal, rates, bank/VAT) while preserving coverage + notification prefs.
  Future<void> saveMechanicProfileFromEdit({
    required String displayName,
    required String email,
    required String phone,
    required int hourlyRate,
    int? emergencyRate,
    required String bankDisplayName,
    required String bankAccountField,
    required String bankSortCode,
    required String billingAddress,
    required String vatNumber,
    required bool vatRegistered,
  }) async {
    final p = meProfile;
    if (p == null) {
      throw Exception('Profile is still loading. Try again in a moment.');
    }

    final callOut = p.callOutFee ?? 35;
    final serviceRadius = p.serviceRadiusMiles ?? 50;
    final baseLocationText = p.baseLocationText;
    final basePostcode = p.basePostcode;

    final trimmedAcct = bankAccountField.trim();
    final digits = trimmedAcct.replaceAll(RegExp(r'\D'), '');
    String? bankAccountMasked;
    if (trimmedAcct.contains('*')) {
      bankAccountMasked = trimmedAcct;
    } else if (digits.length >= 4) {
      bankAccountMasked = '**** **** ${digits.substring(digits.length - 4)}';
    } else if (digits.isNotEmpty) {
      bankAccountMasked = digits;
    } else {
      bankAccountMasked = p.bankAccountMasked;
    }

    final payload = <String, dynamic>{
      'displayName': displayName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'hourlyRate': hourlyRate,
      'callOutFee': callOut,
      'serviceRadiusMiles': serviceRadius.round(),
      'baseLocationText': baseLocationText.trim(),
      'basePostcode': basePostcode.trim(),
      if (emergencyRate != null) 'emergencyRate': emergencyRate,
      'bankDisplayName': bankDisplayName.trim(),
      if (bankAccountMasked != null && bankAccountMasked.isNotEmpty) 'bankAccountMasked': bankAccountMasked,
      'bankSortCode': bankSortCode.trim(),
      'billingAddress': billingAddress.trim(),
      'vatNumber': vatNumber.trim(),
      'vatRegistered': vatRegistered,
      'preferences': {
        'pushEnabled': p.pushEnabled,
        'alertRadiusMiles': p.alertRadiusMiles,
        'notifications': {
          'newBreakdownJobs': p.notifNewBreakdownJobs,
          'jobAcceptedDeclined': p.notifJobAcceptedDeclined,
          'paymentReceived': p.notifPaymentReceived,
          'systemAlerts': p.notifSystemAlerts,
          'appAlerts': p.notifAppAlerts,
        },
      },
    };

    await patchUsersMe(payload);
  }

  List<JobOffer> filteredJobs() {
    var list = rawJobs.where((j) => j.distanceMi <= radiusMi);
    if (maxDistMi != null) {
      list = list.where((j) => j.distanceMi <= maxDistMi!);
    }
    return list.toList()..sort((a, b) => a.distanceMi.compareTo(b.distanceMi));
  }

  void setTab(String t) {
    if (tab == 'quote-detail' && t != 'quote-detail') {
      clearJobQuoteDetail();
    }
    if (tab == 'profile-messages-chat' && t != 'profile-messages-chat') {
      activeChatPeer = null;
    }
    tab = t;
    notifyListeners();
    if (t == 'profile') {
      loadMeProfile();
    }
    if (t == 'profile-messages') {
      loadMessageThreads();
    }
    if (t == 'edit-profile' && meProfile == null && !meProfileLoading) {
      loadMeProfile();
    }
  }

  void openMessageChat(MechanicMessageThread thread) {
    activeChatPeer = thread;
    tab = 'profile-messages-chat';
    notifyListeners();
  }

  void closeMessageChat() {
    activeChatPeer = null;
    tab = 'profile-messages';
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

  /// `availabilityStatus` on each job (or `assignedMechanic`) reflects mechanic availability in feed responses.
  static bool? _readAvailabilityFromFeedRows(List<Map<String, dynamic>> rows) {
    for (final m in rows) {
      final top = '${m['availabilityStatus'] ?? ''}'.trim().toUpperCase();
      if (top == 'ONLINE') return true;
      if (top == 'OFFLINE') return false;
      final am = m['assignedMechanic'];
      if (am is Map<String, dynamic>) {
        final s = '${am['availabilityStatus'] ?? ''}'.trim().toUpperCase();
        if (s == 'ONLINE') return true;
        if (s == 'OFFLINE') return false;
      }
    }
    return null;
  }

  Future<void> loadJobFeed() async {
    feedLoading = true;
    feedError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Missing access token. Please login again.');
      }
      final coords = await _getRealCoordsOrFallback();
      final body = await _api.fetchJobFeed(
        accessToken: token,
        lat: coords.lat,
        lng: coords.lng,
        radiusMiles: radiusMi,
      );
      final list = (body['data'] as List<dynamic>?) ?? [];
      final rows = list.whereType<Map<String, dynamic>>().toList();
      feedJobs = rows.map(JobOffer.fromJson).toList();
      final fromApi = MechanicViewModel._readAvailabilityFromFeedRows(rows);
      if (fromApi != null) {
        online = fromApi;
      }
    } catch (e) {
      feedError = e.toString();
    } finally {
      feedLoading = false;
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

  Future<void> loadEarningsJobs({int page = 1, int limit = 20}) async {
    earningsJobsLoading = true;
    earningsJobsError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Missing access token. Please login again.');
      }
      final body = await _api.fetchEarningsJobs(accessToken: token, page: page, limit: limit);
      earningsJobsMeta = MechanicEarningsJobsListMeta.maybeParse(body['meta']);
      final raw = body['data'];
      earningsJobs = raw is List<dynamic>
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(MechanicCompletedEarningJob.fromJson)
              .toList()
          : <MechanicCompletedEarningJob>[];
    } catch (e) {
      earningsJobsError = e.toString();
    } finally {
      earningsJobsLoading = false;
      notifyListeners();
    }
  }

  /// GET helper for invoice paths (`ui.primaryAction.path` / `invoice.downloadPath`).
  Future<Map<String, dynamic>> fetchMechanicAuthorizedGet(String path) async {
    final session = await _auth.getSession();
    final token = session?.accessToken;
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    final rel = path.trim();
    if (rel.isEmpty) throw Exception('Invalid link');
    return _api.fetchMechanicAuthorizedGet(
      accessToken: token,
      path: rel.startsWith('/') ? rel : '/$rel',
    );
  }

  Future<void> loadBillingPaymentMethods({bool silent = false}) async {
    final session = await _auth.getSession();
    final token = session?.accessToken;
    if (token == null || token.trim().isEmpty) {
      billingPaymentMethodsError = 'Not signed in';
      billingPaymentMethods = const [];
      notifyListeners();
      return;
    }
    if (!silent) {
      billingPaymentMethodsLoading = true;
      billingPaymentMethodsError = null;
      notifyListeners();
    }
    try {
      final body = await _api.fetchBillingPaymentMethods(accessToken: token);
      final raw = body['data'];
      final list = raw is List ? raw : const [];
      billingPaymentMethods = list
          .whereType<Map>()
          .map((m) => FleetBillingPaymentMethod.maybeFromJson(m.cast<String, dynamic>()))
          .whereType<FleetBillingPaymentMethod>()
          .where((p) => p.isActive)
          .toList(growable: false);
      billingPaymentMethodsError = null;
    } catch (e) {
      if (!silent) {
        billingPaymentMethodsError = e.toString();
        billingPaymentMethods = const [];
      } else {
        billingPaymentMethodsError = e.toString();
      }
    } finally {
      if (!silent) {
        billingPaymentMethodsLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> setDefaultBillingPaymentMethod(String paymentMethodId) async {
    final session = await _auth.getSession();
    final token = session?.accessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Not signed in');
    }
    final id = paymentMethodId.trim();
    if (id.isEmpty) {
      throw Exception('Invalid payment method');
    }
    await _api.setBillingPaymentMethodDefault(accessToken: token, methodId: id);
    billingPaymentMethodsError = null;
    await loadBillingPaymentMethods(silent: true);
    if (billingPaymentMethodsError != null && billingPaymentMethodsError!.trim().isNotEmpty) {
      throw Exception(billingPaymentMethodsError);
    }
  }

  Future<void> deleteBillingPaymentMethod(String paymentMethodId) async {
    final session = await _auth.getSession();
    final token = session?.accessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Not signed in');
    }
    final id = paymentMethodId.trim();
    if (id.isEmpty) {
      throw Exception('Invalid payment method');
    }
    await _api.deleteBillingPaymentMethod(accessToken: token, methodId: id);
    billingPaymentMethodsError = null;
    await loadBillingPaymentMethods(silent: true);
    if (billingPaymentMethodsError != null && billingPaymentMethodsError!.trim().isNotEmpty) {
      throw Exception(billingPaymentMethodsError);
    }
  }

  Future<void> createBillingPaymentMethod({
    required String cardBrandLower,
    required String last4,
    required int expMonth,
    required int expYear,
  }) async {
    final session = await _auth.getSession();
    final token = session?.accessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Not signed in');
    }
    final l4 = last4.trim();
    if (l4.length != 4 || int.tryParse(l4) == null) {
      throw Exception('Invalid card number (need last 4 digits)');
    }
    if (expMonth < 1 || expMonth > 12) {
      throw Exception('Invalid expiry month');
    }
    if (expYear < 2000) {
      throw Exception('Invalid expiry year');
    }
    await _api.postBillingPaymentMethod(
      accessToken: token,
      methodType: 'CARD',
      provider: 'MANUAL',
      providerMethodId: 'pm_manual_${DateTime.now().millisecondsSinceEpoch}',
      cardBrand: cardBrandLower,
      last4: l4,
      expMonth: expMonth,
      expYear: expYear,
    );
    billingPaymentMethodsError = null;
    await loadBillingPaymentMethods(silent: true);
    if (billingPaymentMethodsError != null && billingPaymentMethodsError!.trim().isNotEmpty) {
      throw Exception(billingPaymentMethodsError);
    }
  }

  void selectJobForTracker(String jobId) {
    final id = jobId.trim();
    selectedJobTrackerId = id.isEmpty ? null : id;
    jobTrackerDetail = null;
    jobWorkCompleteEnvelope = null;
    jobTrackerError = null;
    notifyListeners();
  }

  void clearJobTrackerSelection() {
    selectedJobTrackerId = null;
    jobTrackerDetail = null;
    jobWorkCompleteEnvelope = null;
    jobTrackerError = null;
    notifyListeners();
  }

  void openJobQuoteDetail(JobOffer job) {
    final id = job.backendId?.trim();
    if (id == null || id.isEmpty) {
      return;
    }
    selectedQuoteJobId = id;
    jobQuoteDetail = null;
    jobQuoteDetailError = null;
    tab = 'quote-detail';
    notifyListeners();
  }

  void clearJobQuoteDetail() {
    selectedQuoteJobId = null;
    jobQuoteDetail = null;
    jobQuoteDetailError = null;
    notifyListeners();
  }

  Future<void> loadJobQuoteDetail({bool silent = false}) async {
    final id = selectedQuoteJobId;
    if (id == null || id.isEmpty) {
      jobQuoteDetailError = 'No job selected';
      jobQuoteDetail = null;
      if (!silent) {
        jobQuoteDetailLoading = false;
      }
      notifyListeners();
      return;
    }
    if (!silent) {
      jobQuoteDetailLoading = true;
      jobQuoteDetailError = null;
      notifyListeners();
    }
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Missing access token. Please login again.');
      }
      final body = await _api.fetchJobById(accessToken: token, jobId: id);
      jobQuoteDetail = MechanicJobDetailParsed.tryParse(body);
      if (jobQuoteDetail == null) {
        throw Exception('Invalid job response');
      }
      jobQuoteDetailError = null;
    } catch (e) {
      jobQuoteDetailError = e.toString();
      if (!silent) {
        jobQuoteDetail = null;
      }
    } finally {
      if (!silent) {
        jobQuoteDetailLoading = false;
      }
      notifyListeners();
    }
  }

  /// Maps mechanic quote UI to `POST /api/v1/jobs/:id/quotes`.
  Future<String?> submitJobQuote({
    required double amount,
    required String notes,
    required String availabilityUi,
    String? scheduledDateKey,
    String? scheduledTime,
  }) async {
    final id = selectedQuoteJobId;
    if (id == null || id.isEmpty) return 'No job selected';
    if (amount <= 0) return 'Enter a valid quote amount';

    var availabilityType = 'NOW';
    var etaMinutes = 10;
    String? scheduledAtIso;

    switch (availabilityUi) {
      case 'In 30 min':
        etaMinutes = 30;
        break;
      case 'In 1 hr':
        etaMinutes = 60;
        break;
      case 'Scheduled':
        availabilityType = 'SCHEDULED';
        etaMinutes = 0;
        if (scheduledDateKey != null &&
            scheduledDateKey.trim().isNotEmpty &&
            scheduledTime != null &&
            scheduledTime.trim().isNotEmpty) {
          final dp = scheduledDateKey.trim().split('-');
          final tp = scheduledTime.trim().split(':');
          if (dp.length == 3 && tp.length >= 2) {
            final y = int.tryParse(dp[0]);
            final mo = int.tryParse(dp[1]);
            final da = int.tryParse(dp[2]);
            final h = int.tryParse(tp[0]);
            final mi = int.tryParse(tp[1]);
            if (y != null && mo != null && da != null && h != null && mi != null) {
              scheduledAtIso = DateTime(y, mo, da, h, mi).toUtc().toIso8601String();
            }
          }
        }
        if (scheduledAtIso == null) {
          return 'Pick a date and time for a scheduled quote';
        }
        break;
      case 'Available Now':
      default:
        etaMinutes = 10;
        availabilityType = 'NOW';
        break;
    }

    quoteSubmitBusy = true;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) return 'Not signed in';
      await _api.postJobQuote(
        accessToken: token,
        jobId: id,
        amount: amount,
        etaMinutes: etaMinutes,
        notes: notes,
        availabilityType: availabilityType,
        scheduledAt: scheduledAtIso,
      );
      await loadJobFeed();
      await loadMyQuotes();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      quoteSubmitBusy = false;
      notifyListeners();
    }
  }

  Future<void> loadJobTrackerDetail({bool silent = false}) async {
    final id = selectedJobTrackerId;
    if (id == null || id.isEmpty) {
      jobTrackerError = 'No job selected';
      jobTrackerDetail = null;
      if (!silent) {
        jobTrackerLoading = false;
      }
      notifyListeners();
      return;
    }
    if (!silent) {
      jobTrackerLoading = true;
      jobTrackerError = null;
      notifyListeners();
    }
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Missing access token. Please login again.');
      }
      final body = await _api.fetchJobById(accessToken: token, jobId: id);
      jobTrackerDetail = MechanicJobDetailParsed.tryParse(body);
      if (jobTrackerDetail == null) {
        throw Exception('Invalid job response');
      }
      jobTrackerError = null;
    } catch (e) {
      jobTrackerError = e.toString();
      if (!silent) {
        jobTrackerDetail = null;
      }
    } finally {
      if (!silent) {
        jobTrackerLoading = false;
      }
      notifyListeners();
    }
  }

  Future<String?> patchJobTrackerJourneyStart() async {
    final id = selectedJobTrackerId;
    if (id == null || id.isEmpty) return 'No job selected';
    jobTrackerActionBusy = true;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) return 'Not signed in';
      await _api.patchJobJourneyStart(accessToken: token, jobId: id);
      await loadJobTrackerDetail(silent: true);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      jobTrackerActionBusy = false;
      notifyListeners();
    }
  }

  Future<String?> patchJobTrackerArrive() async {
    final id = selectedJobTrackerId;
    if (id == null || id.isEmpty) return 'No job selected';
    jobTrackerActionBusy = true;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) return 'Not signed in';
      await _api.patchJobArrive(accessToken: token, jobId: id);
      await loadJobTrackerDetail(silent: true);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      jobTrackerActionBusy = false;
      notifyListeners();
    }
  }

  Future<String?> patchJobTrackerWorkStart() async {
    final id = selectedJobTrackerId;
    if (id == null || id.isEmpty) return 'No job selected';
    jobTrackerActionBusy = true;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) return 'Not signed in';
      await _api.patchJobWorkStart(accessToken: token, jobId: id);
      await loadJobTrackerDetail(silent: true);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      jobTrackerActionBusy = false;
      notifyListeners();
    }
  }

  Future<String?> patchJobWorkComplete({
    required String repairNotes,
    required Map<String, dynamic> invoice,
    required double finalAmount,
    List<http.MultipartFile> photos = const [],
  }) async {
    final id = selectedJobTrackerId;
    if (id == null || id.isEmpty) return 'No job selected';
    jobTrackerActionBusy = true;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) return 'Not signed in';
      final totalStr = finalAmount.toString();
      final body = await _api.patchJobWorkCompleteMultipart(
        accessToken: token,
        jobId: id,
        repairNotes: repairNotes.trim(),
        invoiceJson: jsonEncode(invoice),
        finalAmount: totalStr,
        totalAmount: totalStr,
        photos: photos,
      );
      jobWorkCompleteEnvelope = body;
      await loadJobTrackerDetail(silent: true);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      jobTrackerActionBusy = false;
      notifyListeners();
    }
  }

  /// `POST /api/v1/jobs/:id/reviews/fleet` — star rating + optional comment for the fleet operator.
  Future<String?> submitJobFleetReview({
    required int rating,
    String comment = '',
  }) async {
    final id = selectedJobTrackerId;
    if (id == null || id.isEmpty) return 'No job selected';
    if (rating < 1 || rating > 5) return 'Select a star rating';
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) return 'Not signed in';
      await _api.postJobFleetReview(
        accessToken: token,
        jobId: id,
        rating: rating,
        comment: comment,
      );
      await loadJobTrackerDetail(silent: true);
      return null;
    } catch (e) {
      return e.toString();
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
    if (tab == 'job-tracker') return 'my-jobs';
    if (tab == 'quote-detail') return 'feed';
    if (tab == 'earnings' ||
        tab == 'edit-profile' ||
        tab == 'payment-methods' ||
        tab == 'profile-messages' ||
        tab == 'profile-messages-chat') {
      return 'profile';
    }
    return tab;
  }
}
