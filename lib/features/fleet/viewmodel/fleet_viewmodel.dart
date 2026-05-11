import 'package:flutter/material.dart';

import '../../../data/models/fleet_job_quote.dart';
import '../../../data/models/fleet_job_summary.dart';
import '../../../data/models/fleet_me_profile.dart';
import '../../../data/models/fleet_track_job_detail.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/services/fleet_api_service.dart';
import '../../../data/services/users_api_service.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../models/fleet_chat_session.dart';

class FleetCompletedJob {
  const FleetCompletedJob({
    required this.id,
    required this.truck,
    required this.issue,
    required this.mechanic,
    required this.rating,
    required this.completedDate,
    required this.total,
  });

  final String id;
  final String truck;
  final String issue;
  final String mechanic;
  final int rating;
  final String completedDate;
  final String total;
}

enum FleetTrackStatus { posted, assigned, enRoute, onSite, other }

class FleetTrackingJobUi {
  const FleetTrackingJobUi({
    required this.backendId,
    required this.id,
    required this.truck,
    required this.issue,
    required this.status,
    required this.statusLabel,
    required this.statusTone,
    required this.mechanic,
    required this.eta,
    required this.pay,
    required this.ago,
    required this.emergency,
    required this.quoteAgreed,
    required this.scheduledFor,
    required this.canTrack,
    required this.cancellationCanCancel,
    required this.cancellationIsFree,
    required this.cancellationFee,
    required this.currency,
  });

  final String backendId;
  final String id;
  final String truck;
  final String issue;

  final FleetTrackStatus status;
  final String statusLabel;
  final String statusTone; // red | yellow | green | amber | blue ...

  final String? mechanic;
  final String? eta;
  final String pay;
  final String ago;
  final bool emergency;
  final bool quoteAgreed;
  final DateTime? scheduledFor;

  final bool canTrack;
  final bool cancellationCanCancel;
  final bool cancellationIsFree;
  final num cancellationFee;
  final String currency;
}

class FleetViewModel extends ChangeNotifier {
  FleetViewModel(
    this._jobs,
    this._auth, {
    FleetApiService? api,
    UsersApiService? usersApi,
  })  : _api = api ?? FleetApiService(),
        _usersApi = usersApi ?? UsersApiService() {
    refresh();
  }

  final JobRepository _jobs;
  final AuthViewModel _auth;
  final FleetApiService _api;
  final UsersApiService _usersApi;

  String tab = 'dashboard';
  bool profileComplete = false;
  /// When opening edit-profile from the post-job gate, return here on save/cancel instead of profile.
  String? _returnTabAfterProfileEdit;
  Vehicle? selectedVehicle;
  Vehicle? prefilledVehicle;
  bool showHelp = false;
  bool showPaymentMethods = false;
  bool showVehicles = false;
  bool showChat = false;
  FleetChatSession? chatSession;
  bool showNotifications = false;

  List<Vehicle> get vehicles => _jobs.fleetVehicles();

  bool loading = false;
  String? loadError;
  bool hasLoadedOnce = false;

  int activeCount = 0;
  int awaitingCount = 0;
  int monthCompletedCount = 0;

  String spendMonth = '';
  double spendTotal = 0;
  String spendCurrency = 'GBP';
  double? spendBudget;
  double? spendUtilizationPct;

  List<FleetJobSummary> activeJobs = const [];
  List<FleetCompletedJob> completedJobs = const [];
  List<FleetTrackingJobUi> trackingJobs = const [];

  String? trackingDetailJobId;
  FleetTrackJobDetailUi? trackingJobDetail;
  bool trackingDetailLoading = false;
  String? trackingDetailError;

  FleetMeProfileUi? meProfile;
  bool meProfileLoading = false;
  String? meProfileError;

  /// Quotes for the dashboard job sheet (`GET .../jobs/:id/quotes`).
  List<FleetJobQuote> jobQuotes = const [];
  bool jobQuotesLoading = false;
  String? jobQuotesError;

  Future<void> loadJobQuotes(String? backendJobId) async {
    final id = (backendJobId ?? '').trim();
    if (id.isEmpty) {
      jobQuotes = const [];
      jobQuotesError = null;
      jobQuotesLoading = false;
      notifyListeners();
      return;
    }
    final token = _auth.session?.accessToken;
    if (token == null || token.trim().isEmpty) {
      jobQuotesError = 'Not signed in';
      jobQuotes = const [];
      notifyListeners();
      return;
    }
    jobQuotesLoading = true;
    jobQuotesError = null;
    notifyListeners();
    try {
      final res = await _api.fetchJobQuotes(accessToken: token, jobId: id);
      final raw = res['data'];
      final list = raw is List ? raw : const [];
      final parsed = list
          .whereType<Map>()
          .map((m) => FleetJobQuote.fromJson(m.cast<String, dynamic>()))
          .where((q) => q.id.isNotEmpty)
          .toList();
      parsed.sort((a, b) {
        final ae = a.etaMinutes ?? 1 << 20;
        final be = b.etaMinutes ?? 1 << 20;
        final c = ae.compareTo(be);
        if (c != 0) return c;
        return b.mechanicRating.compareTo(a.mechanicRating);
      });
      jobQuotes = parsed;
    } catch (e) {
      jobQuotesError = e.toString();
      jobQuotes = const [];
    } finally {
      jobQuotesLoading = false;
      notifyListeners();
    }
  }

  void clearJobQuotes() {
    jobQuotes = const [];
    jobQuotesError = null;
    jobQuotesLoading = false;
    notifyListeners();
  }

  /// `PATCH /api/v1/jobs/:jobId/complete/approve`
  Future<void> approveJobCompletion(String backendJobId) async {
    final token = _auth.session?.accessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Not signed in');
    }
    final id = backendJobId.trim();
    if (id.isEmpty) {
      throw Exception('Invalid job');
    }
    await _api.approveJobCompletion(accessToken: token, jobId: id);
  }

  /// `PATCH /api/v1/jobs/:jobId/cancel`
  Future<void> cancelFleetJob(String backendJobId) async {
    final token = _auth.session?.accessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Not signed in');
    }
    final id = backendJobId.trim();
    if (id.isEmpty) {
      throw Exception('Invalid job');
    }
    await _api.cancelJob(accessToken: token, jobId: id);
  }

  /// `PATCH /api/v1/quotes/:quoteId/accept`
  Future<void> acceptJobQuote(String quoteId) async {
    final token = _auth.session?.accessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Not signed in');
    }
    final id = quoteId.trim();
    if (id.isEmpty) {
      throw Exception('Invalid quote');
    }
    await _api.acceptQuote(accessToken: token, quoteId: id);
  }

  Future<void> loadMeProfile() async {
    final token = _auth.session?.accessToken;
    if (token == null || token.trim().isEmpty) {
      meProfileError = 'Not signed in';
      notifyListeners();
      return;
    }
    meProfileLoading = true;
    meProfileError = null;
    notifyListeners();
    try {
      final body = await _usersApi.fetchMe(accessToken: token);
      meProfile = FleetMeProfileUi.fromApiBody(body);
    } catch (e) {
      meProfileError = e.toString();
    } finally {
      meProfileLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateFleetOperatorProfile({
    required String companyName,
    required String regNumber,
    required String vatNumber,
    required String fleetSize,
    required String contactName,
    required String contactRole,
    required String contactPhone,
    required String email,
    required String billingAddress,
  }) async {
    final token = _auth.session?.accessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Not signed in');
    }

    meProfileLoading = true;
    meProfileError = null;
    notifyListeners();
    try {
      // Backend expects a flat body (same as Postman PATCH /api/v1/users/me).
      final bill = billingAddress.trim();
      final fleet = fleetSize.trim().replaceAll('–', '-');
      final payload = <String, dynamic>{
        'email': email.trim(),
        'companyName': companyName.trim(),
        'regNumber': regNumber.trim(),
        'vatNumber': vatNumber.trim(),
        'fleetSize': fleet,
        'contactName': contactName.trim(),
        'contactRole': contactRole.trim(),
        'phone': contactPhone.trim(),
        'billingAddress': bill,
        'defaultAddress': bill,
      };

      await _usersApi.updateMe(accessToken: token, payload: payload);
      final body = await _usersApi.fetchMe(accessToken: token);
      meProfile = FleetMeProfileUi.fromApiBody(body);
    } catch (e) {
      meProfileError = e.toString();
      rethrow;
    } finally {
      meProfileLoading = false;
      notifyListeners();
    }
  }

  Future<void> openTrackingJobDetail(String backendJobId) async {
    final id = backendJobId.trim();
    if (id.isEmpty) return;
    trackingDetailJobId = id;
    trackingJobDetail = null;
    trackingDetailError = null;
    tab = 'tracking-detail';
    notifyListeners();
    await loadTrackingJobDetail();
  }

  Future<void> loadTrackingJobDetail() async {
    final id = trackingDetailJobId;
    final token = _auth.session?.accessToken;
    if (id == null || id.isEmpty || token == null || token.trim().isEmpty) {
      return;
    }
    trackingDetailLoading = true;
    trackingDetailError = null;
    notifyListeners();
    try {
      final res = await _api.fetchJob(accessToken: token, jobId: id);
      trackingJobDetail = FleetTrackJobDetailUi.fromApiBody(res);
    } catch (e) {
      trackingDetailError = e.toString();
      trackingJobDetail = null;
    } finally {
      trackingDetailLoading = false;
      notifyListeners();
    }
  }

  void closeTrackingJobDetail() {
    trackingDetailJobId = null;
    trackingJobDetail = null;
    trackingDetailError = null;
    tab = 'tracking';
    notifyListeners();
  }

  Future<void> refresh() async {
    final session = _auth.session;
    final token = session?.accessToken;
    if (session == null || token == null || token.trim().isEmpty) {
      return;
    }

    loading = true;
    loadError = null;
    notifyListeners();

    try {
      final dash = await _api.fetchFleetDashboard(accessToken: token);
      final data = (dash['data'] is Map<String, dynamic>) ? dash['data'] as Map<String, dynamic> : <String, dynamic>{};
      final cards = (data['cards'] is Map<String, dynamic>) ? data['cards'] as Map<String, dynamic> : <String, dynamic>{};

      activeCount = (cards['activeCount'] is num) ? (cards['activeCount'] as num).toInt() : activeCount;
      awaitingCount = (cards['awaitingCount'] is num) ? (cards['awaitingCount'] as num).toInt() : awaitingCount;
      monthCompletedCount =
          (cards['monthCompletedCount'] is num) ? (cards['monthCompletedCount'] as num).toInt() : monthCompletedCount;

      final spend = (data['spend'] is Map<String, dynamic>) ? data['spend'] as Map<String, dynamic> : <String, dynamic>{};
      spendMonth = (spend['month'] as String?) ?? spendMonth;
      spendTotal = (spend['total'] is num) ? (spend['total'] as num).toDouble() : spendTotal;
      spendCurrency = (spend['currency'] as String?) ?? spendCurrency;
      spendBudget = (spend['budget'] is num) ? (spend['budget'] as num).toDouble() : null;
      spendUtilizationPct =
          (spend['utilizationPct'] is num) ? (spend['utilizationPct'] as num).toDouble() : null;

      // Fetch lists from /jobs for active + completed.
      final activeRes = await _api.fetchJobs(accessToken: token, tab: 'active', page: 1, limit: 20);
      final completedRes = await _api.fetchJobs(accessToken: token, tab: 'completed', page: 1, limit: 20);
      final trackingRes = await _api.fetchJobs(accessToken: token, tab: 'tracking', page: 1, limit: 20);

      activeJobs = _parseFleetJobSummaries(activeRes['data']);
      completedJobs = _parseCompletedJobs(completedRes['data']);
      trackingJobs = _parseTrackingJobs(trackingRes['data']);
      hasLoadedOnce = true;
    } catch (e) {
      loadError = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  static List<FleetJobSummary> _parseFleetJobSummaries(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .map(_mapFleetJob)
        .whereType<FleetJobSummary>()
        .toList(growable: false);
  }

  static List<FleetCompletedJob> _parseCompletedJobs(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .map(_mapCompletedJob)
        .whereType<FleetCompletedJob>()
        .toList(growable: false);
  }

  static List<FleetTrackingJobUi> _parseTrackingJobs(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .map(_mapTrackingJob)
        .whereType<FleetTrackingJobUi>()
        .toList(growable: false);
  }

  static FleetTrackingJobUi? _mapTrackingJob(Map<String, dynamic> j) {
    final backendId = ((j['_id'] as String?) ?? '').trim();
    final jobCode = (j['jobCode'] as String?) ?? '';
    if (jobCode.trim().isEmpty && backendId.isEmpty) return null;

    final title = (j['title'] as String?) ?? '';
    final postedAgoLabel = (j['postedAgoLabel'] as String?) ?? '';

    final vehicle = (j['vehicle'] is Map<String, dynamic>) ? j['vehicle'] as Map<String, dynamic> : const {};
    final reg = (vehicle['registration'] as String?) ?? '';
    final type = (vehicle['type'] as String?) ?? '';
    final truck = [type, reg].where((s) => s.trim().isNotEmpty).join(' · ');

    final statusUi = (j['statusUi'] is Map<String, dynamic>) ? j['statusUi'] as Map<String, dynamic> : const {};
    final rawStatus = ((j['status'] as String?) ?? '').trim();
    final statusLabel = ((statusUi['label'] as String?) ?? rawStatus).trim();
    final statusTone = ((statusUi['tone'] as String?) ?? '').trim();

    FleetTrackStatus statusFromApi() {
      final s = (rawStatus.isNotEmpty ? rawStatus : statusLabel).toUpperCase();
      if (s.contains('POSTED')) return FleetTrackStatus.posted;
      if (s.contains('ASSIGNED') || (j['assignedAt'] is String && (j['assignedAt'] as String).trim().isNotEmpty)) {
        return FleetTrackStatus.assigned;
      }
      if (s.contains('EN_ROUTE') || s.contains('EN ROUTE')) return FleetTrackStatus.enRoute;
      if (s.contains('ON_SITE') || s.contains('ON SITE')) return FleetTrackStatus.onSite;
      return FleetTrackStatus.other;
    }

    final assignedMechanic = (j['assignedMechanic'] is Map<String, dynamic>) ? j['assignedMechanic'] as Map<String, dynamic> : const {};
    final mechanicName = (assignedMechanic['displayName'] as String?)?.trim();

    final amount = (j['finalAmount'] as num?) ?? (j['acceptedAmount'] as num?) ?? (j['estimatedPayout'] as num?) ?? 0;
    final currency = (j['currency'] as String?) ?? 'GBP';

    DateTime? parseDate(String? s) {
      if (s == null || s.trim().isEmpty) return null;
      return DateTime.tryParse(s);
    }

    final scheduledFor = parseDate(j['scheduledFor'] as String?);
    final emergency = scheduledFor == null;
    final quoteAgreed = (j['acceptedAmount'] is num) || (j['finalAmount'] is num);

    final actions = (j['actions'] is Map<String, dynamic>) ? j['actions'] as Map<String, dynamic> : const {};
    final canTrack = actions['canTrack'] == true;
    final cancellation = (actions['cancellation'] is Map<String, dynamic>) ? actions['cancellation'] as Map<String, dynamic> : const {};
    final cancellationCanCancel = cancellation['canCancel'] == true;
    final cancellationIsFree = cancellation['isFree'] == true;
    final cancellationFee = (cancellation['fee'] is num) ? (cancellation['fee'] as num) : 0;

    return FleetTrackingJobUi(
      backendId: backendId.isNotEmpty ? backendId : jobCode,
      id: jobCode.isNotEmpty ? jobCode : backendId,
      truck: truck.isEmpty ? '—' : truck,
      issue: title.isEmpty ? '—' : title,
      status: statusFromApi(),
      statusLabel: statusLabel.isEmpty ? '—' : statusLabel,
      statusTone: statusTone,
      mechanic: (mechanicName == null || mechanicName.isEmpty) ? null : mechanicName,
      eta: null,
      pay: _formatMoney(amount.toDouble(), currency),
      ago: postedAgoLabel.isEmpty ? '—' : postedAgoLabel,
      emergency: emergency,
      quoteAgreed: quoteAgreed,
      scheduledFor: scheduledFor,
      canTrack: canTrack,
      cancellationCanCancel: cancellationCanCancel,
      cancellationIsFree: cancellationIsFree,
      cancellationFee: cancellationFee,
      currency: currency,
    );
  }

  static FleetCompletedJob? _mapCompletedJob(Map<String, dynamic> j) {
    final jobCode = (j['jobCode'] as String?) ?? (j['_id'] as String?) ?? '';
    if (jobCode.isEmpty) return null;
    final title = (j['title'] as String?) ?? '';

    final vehicle = (j['vehicle'] is Map<String, dynamic>) ? j['vehicle'] as Map<String, dynamic> : const {};
    final reg = (vehicle['registration'] as String?) ?? '';
    final type = (vehicle['type'] as String?) ?? '';
    final truck = [reg, type].where((s) => s.trim().isNotEmpty).join(' · ');

    final mech = (j['assignedMechanic'] is Map<String, dynamic>) ? j['assignedMechanic'] as Map<String, dynamic> : const {};
    final mechanic = (mech['displayName'] as String?) ?? '—';

    final amount = (j['finalAmount'] as num?) ?? (j['acceptedAmount'] as num?) ?? (j['estimatedPayout'] as num?) ?? 0;
    final currency = (j['currency'] as String?) ?? 'GBP';
    final total = _formatMoney(amount.toDouble(), currency);

    final completedAt = (j['completedAt'] as String?) ?? '';
    final completedDate = completedAt.isEmpty ? '—' : completedAt.split('T').first;

    return FleetCompletedJob(
      id: jobCode,
      truck: truck.isEmpty ? '—' : truck,
      issue: title,
      mechanic: mechanic,
      rating: 5,
      completedDate: completedDate,
      total: total,
    );
  }

  static String _formatMoney(double amount, String currency) {
    final sym = switch (currency.toUpperCase()) {
      'GBP' => '£',
      'USD' => r'$',
      'EUR' => '€',
      _ => '',
    };
    final rounded = amount.round();
    return '$sym$rounded';
  }

  static FleetJobSummary? _mapFleetJob(Map<String, dynamic> j) {
    final backendId = ((j['_id'] as String?) ?? '').trim();
    final code = ((j['jobCode'] as String?) ?? '').trim();
    final displayId = code.isNotEmpty ? code : backendId;
    if (displayId.isEmpty) return null;
    final title = (j['title'] as String?) ?? '';
    final urgency = (j['urgency'] as String?) ?? 'MEDIUM';

    final vehicle = (j['vehicle'] is Map<String, dynamic>) ? j['vehicle'] as Map<String, dynamic> : const {};
    final reg = (vehicle['registration'] as String?) ?? '';
    final type = (vehicle['type'] as String?) ?? '';
    final truck = [reg, type].where((s) => s.trim().isNotEmpty).join(' • ');

    final statusUi = (j['statusUi'] is Map<String, dynamic>) ? j['statusUi'] as Map<String, dynamic> : const {};
    final status = (statusUi['label'] as String?) ?? (j['status'] as String?) ?? '—';
    final tone = (statusUi['tone'] as String?) ?? '';

    final urgencyCfg = _urgencyColors(urgency);
    final statusCfg = _toneColors(tone, fallback: urgencyCfg.fg);

    return FleetJobSummary(
      id: displayId,
      backendId: backendId.isNotEmpty ? backendId : null,
      truck: truck.isEmpty ? '—' : truck,
      issue: title,
      status: status,
      urgency: urgency,
      urgencyColorHex: urgencyCfg.fg.toARGB32(),
      urgencyBgHex: urgencyCfg.bg.toARGB32(),
      statusColorHex: statusCfg.fg.toARGB32(),
      statusBgHex: statusCfg.bg.toARGB32(),
    );
  }

  static ({Color fg, Color bg}) _urgencyColors(String urgency) {
    final u = urgency.toUpperCase();
    if (u.contains('CRITICAL')) return (fg: const Color(0xFFEF4444), bg: const Color(0x33EF4444));
    if (u.contains('HIGH')) return (fg: const Color(0xFFFB923C), bg: const Color(0x33FB923C));
    return (fg: const Color(0xFF2563EB), bg: const Color(0x332563EB));
  }

  static ({Color fg, Color bg}) _toneColors(String tone, {required Color fallback}) {
    final t = tone.toLowerCase();
    return switch (t) {
      'red' => (fg: const Color(0xFFEF4444), bg: const Color(0x33EF4444)),
      'yellow' => (fg: const Color(0xFFFBBF24), bg: const Color(0x33FBBF24)),
      'green' => (fg: const Color(0xFF4ADE80), bg: const Color(0x334ADE80)),
      'amber' => (fg: const Color(0xFFFB923C), bg: const Color(0x33FB923C)),
      'blue' => (fg: const Color(0xFF60A5FA), bg: const Color(0x3360A5FA)),
      _ => (fg: fallback, bg: fallback.withValues(alpha: 0.20)),
    };
  }

  /// True while edit-profile was opened from the Post Job gate (save/cancel returns to Post Job).
  bool get isEditingProfileForPostJob => _returnTabAfterProfileEdit == 'post-job';

  void setTab(String value) {
    tab = value;
    notifyListeners();
    if (value == 'profile') {
      loadMeProfile();
    }
  }

  void openFleetEditProfile({required bool fromPostJobGate}) {
    _returnTabAfterProfileEdit = fromPostJobGate ? 'post-job' : null;
    tab = 'edit-profile';
    notifyListeners();
  }

  void cancelFleetEditProfile() {
    tab = _returnTabAfterProfileEdit ?? 'profile';
    _returnTabAfterProfileEdit = null;
    notifyListeners();
    if (tab == 'profile') loadMeProfile();
  }

  void markProfileComplete() {
    profileComplete = true;
    tab = _returnTabAfterProfileEdit ?? 'profile';
    _returnTabAfterProfileEdit = null;
    notifyListeners();
    if (tab == 'profile') loadMeProfile();
  }

  /// Post Job gate: advance to the full job form (same tab). Profile details remain editable under Profile.
  void unlockPostJobFormFromGate() {
    profileComplete = true;
    _returnTabAfterProfileEdit = null;
    tab = 'post-job';
    notifyListeners();
  }

  void selectVehicle(Vehicle v) {
    selectedVehicle = v;
    showVehicles = false;
    tab = 'vehicle-detail';
    notifyListeners();
  }

  void clearSelectedVehicle() {
    selectedVehicle = null;
    tab = 'profile';
    notifyListeners();
    loadMeProfile();
  }

  void requestServiceFromVehicle(Vehicle v) {
    prefilledVehicle = v;
    tab = 'post-job';
    notifyListeners();
  }

  void openVehicles() {
    showVehicles = true;
    notifyListeners();
  }

  void closeVehicles() {
    showVehicles = false;
    tab = 'profile';
    notifyListeners();
    loadMeProfile();
  }

  void openPayment() {
    showPaymentMethods = true;
    notifyListeners();
  }

  void closePayment() {
    showPaymentMethods = false;
    tab = 'profile';
    notifyListeners();
    loadMeProfile();
  }

  void openHelp() {
    showHelp = true;
    notifyListeners();
  }

  void closeHelp() {
    showHelp = false;
    notifyListeners();
  }

  void openJobChat(FleetChatSession session) {
    chatSession = session;
    showChat = true;
    notifyListeners();
  }

  void closeChat() {
    showChat = false;
    chatSession = null;
    notifyListeners();
  }

  void openNotifications() {
    showNotifications = true;
    notifyListeners();
  }

  void closeNotifications() {
    showNotifications = false;
    notifyListeners();
  }

  String get bottomNavActive {
    if (tab == 'tracking-detail' || tab == 'quote-received') return 'tracking';
    if (tab == 'edit-profile' && isEditingProfileForPostJob) return 'post-job';
    if (tab == 'edit-profile' || tab == 'payment-methods' || tab == 'vehicles' || tab == 'vehicle-detail') {
      return 'profile';
    }
    return tab;
  }
}
