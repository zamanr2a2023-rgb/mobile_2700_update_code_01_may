import 'package:flutter/foundation.dart';

import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/api_auth_repository.dart';
import '../../../data/models/job_chat_models.dart';
import '../../../data/services/chat_api_service.dart';
import '../../../data/services/company_api_service.dart';
import '../../../data/services/users_api_service.dart';
import '../../mechanic/models/mechanic_profile_extras.dart';

// ─── Team (`GET /api/v1/company/team`) ───────────────────────────────────────

class CompanyTeamWorkStatusUi {
  const CompanyTeamWorkStatusUi({
    required this.key,
    required this.label,
    required this.tone,
    required this.dotTone,
  });

  final String key;
  final String label;
  final String tone;
  final String dotTone;

  factory CompanyTeamWorkStatusUi.fromJson(Map<String, dynamic> json) {
    return CompanyTeamWorkStatusUi(
      key: ((json['key'] as String?) ?? '').trim().toLowerCase(),
      label: ((json['label'] as String?) ?? '').trim(),
      tone: ((json['tone'] as String?) ?? '').trim().toLowerCase(),
      dotTone: ((json['dotTone'] as String?) ?? (json['tone'] as String?) ?? '').trim().toLowerCase(),
    );
  }
}

class CompanyTeamCardAction {
  const CompanyTeamCardAction({required this.label, required this.icon, required this.href});

  final String label;
  final String icon;
  final String href;

  factory CompanyTeamCardAction.fromJson(Map<String, dynamic> json) {
    return CompanyTeamCardAction(
      label: ((json['label'] as String?) ?? 'More').trim(),
      icon: ((json['icon'] as String?) ?? '').trim(),
      href: ((json['href'] as String?) ?? '').trim(),
    );
  }
}

class CompanyTeamMember {
  const CompanyTeamMember({
    required this.mongoId,
    required this.employeeId,
    required this.email,
    required this.displayName,
    required this.phone,
    required this.profilePhotoUrl,
    required this.workStatusUi,
    required this.rating,
    required this.ratingCount,
    required this.skillsLabels,
    required this.jobsCompleted,
    required this.activeJobs,
    required this.joinedMonthLabel,
    required this.jobTitle,
    required this.cardAction,
  });

  final String mongoId;
  final String employeeId;
  final String email;
  final String displayName;
  final String phone;
  final String profilePhotoUrl;
  final CompanyTeamWorkStatusUi workStatusUi;
  final double rating;
  final int ratingCount;
  final List<String> skillsLabels;
  final int jobsCompleted;
  final int activeJobs;
  final String joinedMonthLabel;
  final String jobTitle;
  final CompanyTeamCardAction? cardAction;

  String get ratingDisplay {
    final r = rating;
    return (r == r.roundToDouble()) ? '${r.round()}' : r.toStringAsFixed(1);
  }

  factory CompanyTeamMember.fromJson(Map<String, dynamic> json) {
    final ws = (json['workStatusUi'] is Map<String, dynamic>)
        ? CompanyTeamWorkStatusUi.fromJson(json['workStatusUi'] as Map<String, dynamic>)
        : const CompanyTeamWorkStatusUi(key: '', label: '', tone: 'neutral', dotTone: 'grey');
    final skillsRaw = json['skillsLabels'];
    final skills = <String>[];
    if (skillsRaw is List<dynamic>) {
      for (final e in skillsRaw) {
        final s = '$e'.trim();
        if (s.isNotEmpty) skills.add(s);
      }
    }
    final card = (json['cardAction'] is Map<String, dynamic>)
        ? CompanyTeamCardAction.fromJson(json['cardAction'] as Map<String, dynamic>)
        : null;
    return CompanyTeamMember(
      mongoId: (json['_id'] as String?) ?? '',
      employeeId: ((json['id'] as String?) ?? (json['employeeDisplayRef'] as String?) ?? '').trim(),
      email: ((json['email'] as String?) ?? '').trim(),
      displayName: ((json['displayName'] as String?) ?? '').trim(),
      phone: ((json['phone'] as String?) ?? '').trim(),
      profilePhotoUrl: ((json['profilePhotoUrl'] as String?) ?? '').trim(),
      workStatusUi: ws,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      skillsLabels: skills,
      jobsCompleted: (json['jobsCompleted'] as num?)?.toInt() ?? 0,
      activeJobs: (json['activeJobs'] as num?)?.toInt() ?? 0,
      joinedMonthLabel: ((json['joinedMonthLabel'] as String?) ?? '').trim(),
      jobTitle: ((json['jobTitle'] as String?) ?? '').trim(),
      cardAction: card,
    );
  }
}

class CompanyTeamPendingInvite {
  const CompanyTeamPendingInvite({required this.email, required this.expiresAtIso, required this.status});

  final String email;
  final String expiresAtIso;
  final String status;

  factory CompanyTeamPendingInvite.fromJson(Map<String, dynamic> json) {
    return CompanyTeamPendingInvite(
      email: ((json['email'] as String?) ?? '').trim(),
      expiresAtIso: ((json['expiresAt'] as String?) ?? '').trim(),
      status: ((json['status'] as String?) ?? '').trim(),
    );
  }
}

class CompanyTeamInviteAction {
  const CompanyTeamInviteAction({required this.method, required this.path, required this.bodyFields});

  final String method;
  final String path;
  final List<String> bodyFields;

  factory CompanyTeamInviteAction.fromJson(Map<String, dynamic> json) {
    final fields = <String>[];
    final raw = json['bodyFields'];
    if (raw is List<dynamic>) {
      for (final e in raw) {
        final s = '$e'.trim();
        if (s.isNotEmpty) fields.add(s);
      }
    }
    return CompanyTeamInviteAction(
      method: ((json['method'] as String?) ?? 'POST').trim().toUpperCase(),
      path: ((json['path'] as String?) ?? '/api/v1/company/team/invitations').trim(),
      bodyFields: fields,
    );
  }
}

class CompanyTeamMeta {
  const CompanyTeamMeta({
    required this.pendingReviewCount,
    required this.jobsNavBadgeCount,
    required this.memberCount,
    required this.pendingInviteCount,
  });

  final int pendingReviewCount;
  final int jobsNavBadgeCount;
  final int memberCount;
  final int pendingInviteCount;

  factory CompanyTeamMeta.fromJson(Map<String, dynamic> json) {
    return CompanyTeamMeta(
      pendingReviewCount: (json['pendingReviewCount'] as num?)?.toInt() ?? 0,
      jobsNavBadgeCount: (json['jobsNavBadgeCount'] as num?)?.toInt() ?? 0,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      pendingInviteCount: (json['pendingInviteCount'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Model ──────────────────────────────────────────────────────────────────

class CompanyQuote {
  const CompanyQuote({
    required this.quoteId,
    required this.jobBackendId,
    required this.jobCode,
    required this.vehicle,
    required this.issueTitle,
    required this.notes,
    required this.location,
    required this.distanceKm,
    required this.amount,
    required this.currency,
    required this.status,
    required this.statusLabel,
    required this.statusTone,
    required this.summaryLine,
    required this.canOpenActiveJob,
    required this.canAmend,
    required this.canWithdraw,
    required this.canResubmit,
    required this.createdAt,
    required this.quotedAgoLabel,
    required this.assignedMechanicId,
  });

  final String quoteId;
  final String jobBackendId;
  final String jobCode;

  /// e.g. "Scania R450"
  final String vehicle;

  /// Job title from `job.title` — main grey line under vehicle.
  final String issueTitle;

  /// Quote notes from API; optional second grey line under [issueTitle].
  final String notes;
  final String location;
  final double? distanceKm;
  final num amount;
  final String currency;
  final String status;
  final String statusLabel;
  final String statusTone;
  final String summaryLine;
  final bool canOpenActiveJob;
  final bool canAmend;
  final bool canWithdraw;
  final bool canResubmit;
  final DateTime? createdAt;

  /// Pre-formatted `"2 hrs ago"` from API (`quotedAgoLabel`).
  final String quotedAgoLabel;

  /// `job.assignedMechanic`: id string when assigned, otherwise null.
  final String? assignedMechanicId;

  // ── Derived display helpers ──────────────────────────────────────────────

  String get amountDisplay {
    final sym = switch (currency.toUpperCase()) {
      'GBP' => '£',
      'USD' => r'$',
      'EUR' => '€',
      _ => '',
    };
    return '$sym${amount.round()}';
  }

  String get timeSubmittedLabel =>
      quotedAgoLabel.trim().isNotEmpty ? quotedAgoLabel : _fallbackTimeAgo();

  bool get showsAssignMechanicBanner =>
      status.toUpperCase() == 'ACCEPTED' && assignedMechanicId == null;

  String _fallbackTimeAgo() {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    if (diff.inDays == 1) return '1 day ago';
    return '${diff.inDays} days ago';
  }

  factory CompanyQuote.fromJson(Map<String, dynamic> json) {
    final job = (json['job'] is Map<String, dynamic>)
        ? json['job'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final vehicleMap = (job['vehicle'] is Map<String, dynamic>)
        ? job['vehicle'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final locationMap = (job['location'] is Map<String, dynamic>)
        ? job['location'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final statusUi = (json['statusUi'] is Map<String, dynamic>)
        ? json['statusUi'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final actions = (json['actions'] is Map<String, dynamic>)
        ? json['actions'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final make = (vehicleMap['make'] as String?) ?? '';
    final model = (vehicleMap['model'] as String?) ?? '';
    final vehicleStr = [make, model].where((s) => s.isNotEmpty).join(' ');

    final title = ((job['title'] as String?) ?? '').trim();
    final notesRaw = ((json['notes'] as String?) ?? '').trim();

    final addr = (locationMap['address'] as String?) ?? '';

    final assignRaw = job['assignedMechanic'];
    String? mechanicId;
    if (assignRaw is String && assignRaw.isNotEmpty) {
      mechanicId = assignRaw;
    } else if (assignRaw is Map<String, dynamic>) {
      mechanicId = assignRaw['_id'] as String?;
    }

    DateTime? createdAt;
    try {
      final raw = json['createdAt'] as String?;
      if (raw != null) createdAt = DateTime.parse(raw);
    } catch (_) {}

    final dist = json['distanceKm'];
    double? distanceKm;
    if (dist is num) distanceKm = dist.toDouble();

    return CompanyQuote(
      quoteId: (json['_id'] as String?) ?? '',
      jobBackendId: (job['_id'] as String?) ?? '',
      jobCode: (job['jobCode'] as String?) ?? '',
      vehicle: vehicleStr,
      issueTitle: title,
      notes: notesRaw,
      location: addr,
      distanceKm: distanceKm,
      amount: (json['amount'] as num?) ?? 0,
      currency: (json['currency'] as String?) ?? 'GBP',
      status: (json['status'] as String?) ?? '',
      statusLabel: ((statusUi['label'] as String?) ?? '').trim(),
      statusTone: ((statusUi['tone'] as String?) ?? '').trim().toLowerCase(),
      summaryLine: ((json['summaryLine'] as String?) ?? '').trim(),
      canOpenActiveJob: (actions['canOpenActiveJob'] as bool?) ?? false,
      canAmend: (actions['canAmend'] as bool?) ?? false,
      canWithdraw: (actions['canWithdraw'] as bool?) ?? false,
      canResubmit: (actions['canResubmit'] as bool?) ?? false,
      createdAt: createdAt,
      quotedAgoLabel: ((json['quotedAgoLabel'] as String?) ?? '').trim(),
      assignedMechanicId: mechanicId,
    );
  }
}

// ─── Dashboard (GET /api/v1/company/dashboard) ─────────────────────────────

class CompanyRecentActivityRow {
  const CompanyRecentActivityRow({
    required this.title,
    required this.detail,
    required this.relativeTimeLabel,
    required this.icon,
    this.createdAt,
  });

  final String title;
  final String detail;
  /// API `relativeTime`, e.g. "26 min ago".
  final String relativeTimeLabel;
  final String icon;
  final DateTime? createdAt;

  factory CompanyRecentActivityRow.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    try {
      final raw = json['createdAt'] as String?;
      if (raw != null) createdAt = DateTime.parse(raw).toLocal();
    } catch (_) {}
    return CompanyRecentActivityRow(
      title: ((json['title'] as String?) ?? '').trim(),
      detail: ((json['detail'] as String?) ?? '').trim(),
      relativeTimeLabel: ((json['relativeTime'] as String?) ?? '').trim(),
      icon: ((json['icon'] as String?) ?? '').trim(),
      createdAt: createdAt,
    );
  }

  String get displayTimeLabel {
    if (relativeTimeLabel.isNotEmpty) return relativeTimeLabel;
    final d = createdAt;
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays == 1) return '1 day ago';
    return '${diff.inDays} days ago';
  }
}

class CompanyDashboardData {
  const CompanyDashboardData({
    required this.companyName,
    required this.contactName,
    required this.phone,
    required this.activeJobs,
    required this.mechanics,
    required this.onlineMechanics,
    required this.monthRevenue,
    required this.monthRevenueChangePercent,
    required this.averageRating,
    required this.ratingReviewCount,
    required this.pendingInvites,
    required this.unassignedJobsCount,
    required this.recentActivity,
  });

  final String companyName;
  final String contactName;
  final String phone;
  final int activeJobs;
  final int mechanics;
  final int onlineMechanics;
  final int monthRevenue;
  final int monthRevenueChangePercent;
  final double averageRating;
  final int ratingReviewCount;
  final int pendingInvites;
  final int unassignedJobsCount;
  final List<CompanyRecentActivityRow> recentActivity;

  /// Assigned active jobs (`active − unassigned`, clamped to ≥ 0).
  int get assignedActiveJobs {
    if (activeJobs <= 0) return 0;
    final assigned = activeJobs - unassignedJobsCount;
    return assigned < 0 ? 0 : assigned;
  }

  static CompanyDashboardData? tryParse(dynamic root) {
    if (root is! Map<String, dynamic>) return null;
    Map<String, dynamic> data = root;
    if (root.containsKey('data')) {
      final inner = root['data'];
      if (inner is! Map<String, dynamic>) return null;
      data = inner;
    }
    final company = (data['company'] is Map<String, dynamic>)
        ? data['company'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final cards = (data['cards'] is Map<String, dynamic>)
        ? data['cards'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final quick = (data['quickActions'] is Map<String, dynamic>)
        ? data['quickActions'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final uaList = data['unassignedJobs'];
    int unassigned = (data['unassignedJobsCount'] as num?)?.toInt() ?? 0;
    if ((unassigned == 0 || data['unassignedJobsCount'] == null) && uaList is List<dynamic>) {
      unassigned = uaList.length;
    }

    final rawAct = data['recentActivity'];
    final activity = <CompanyRecentActivityRow>[];
    if (rawAct is List<dynamic>) {
      for (final e in rawAct) {
        if (e is Map<String, dynamic>) {
          activity.add(CompanyRecentActivityRow.fromJson(e));
        }
      }
    }

    return CompanyDashboardData(
      companyName: ((company['companyName'] as String?) ?? '').trim(),
      contactName: ((company['contactName'] as String?) ?? '').trim(),
      phone: ((company['phone'] as String?) ?? '').trim(),
      activeJobs: (cards['activeJobs'] as num?)?.toInt() ?? 0,
      mechanics: (cards['mechanics'] as num?)?.toInt() ?? 0,
      onlineMechanics: (cards['onlineMechanics'] as num?)?.toInt() ?? 0,
      monthRevenue: (cards['monthRevenue'] as num?)?.toInt() ?? 0,
      monthRevenueChangePercent: (cards['monthRevenueChangePercent'] as num?)?.toInt() ?? 0,
      averageRating: (cards['averageRating'] as num?)?.toDouble() ?? 0,
      ratingReviewCount: (cards['ratingReviewCount'] as num?)?.toInt() ?? 0,
      pendingInvites: (quick['pendingInvites'] as num?)?.toInt() ?? 0,
      unassignedJobsCount: unassigned,
      recentActivity: activity,
    );
  }
}

/// Formats whole-currency GBP revenue for dashboard cards (`18400` → `£18.4k`).
String formatCompanyMonthRevenueGbp(int amount) {
  if (amount.abs() >= 1000000) {
    final v = amount / 1000000;
    return '£${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}M';
  }
  if (amount.abs() >= 1000) {
    final k = amount / 1000;
    return '£${k.toStringAsFixed(k == k.roundToDouble() ? 0 : 1)}k';
  }
  return '£$amount';
}

// ─── Company earnings summary (`GET /api/v1/company/earnings/summary`) ─────

/// Top summary amounts for the earnings screen.
class CompanyEarningsCards {
  const CompanyEarningsCards({
    required this.monthGross,
    required this.monthNet,
    required this.allTimeGross,
    required this.allTimeNet,
    required this.completedJobs,
  });

  final double monthGross;
  final double monthNet;
  final double allTimeGross;
  final double allTimeNet;
  final int completedJobs;

  static CompanyEarningsCards? maybeParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final monthGross = raw['monthGross'];
    final monthNet = raw['monthNet'];
    if (monthGross is! num || monthNet is! num) return null;
    return CompanyEarningsCards(
      monthGross: monthGross.toDouble(),
      monthNet: monthNet.toDouble(),
      allTimeGross: (raw['allTimeGross'] as num?)?.toDouble() ?? 0,
      allTimeNet: (raw['allTimeNet'] as num?)?.toDouble() ?? 0,
      completedJobs: (raw['completedJobs'] as num?)?.toInt() ?? 0,
    );
  }
}

class CompanyEarningsDisplay {
  const CompanyEarningsDisplay({
    required this.monthGrossLabel,
    required this.monthNetLabel,
    required this.monthGrossSubtext,
    required this.monthNetSubtext,
    required this.allTimeLabel,
    required this.allTimeSubtext,
  });

  final String monthGrossLabel;
  final String monthNetLabel;
  final String monthGrossSubtext;
  final String monthNetSubtext;
  final String allTimeLabel;
  final String allTimeSubtext;

  static CompanyEarningsDisplay maybeParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return const CompanyEarningsDisplay(
        monthGrossLabel: 'GROSS',
        monthNetLabel: 'NET',
        monthGrossSubtext: '',
        monthNetSubtext: '',
        allTimeLabel: 'ALL-TIME',
        allTimeSubtext: '',
      );
    }
    return CompanyEarningsDisplay(
      monthGrossLabel: ((raw['monthGrossLabel'] as String?) ?? 'GROSS').trim(),
      monthNetLabel: ((raw['monthNetLabel'] as String?) ?? 'NET').trim(),
      monthGrossSubtext: ((raw['monthGrossSubtext'] as String?) ?? '').trim(),
      monthNetSubtext: ((raw['monthNetSubtext'] as String?) ?? '').trim(),
      allTimeLabel: ((raw['allTimeLabel'] as String?) ?? 'ALL-TIME').trim(),
      allTimeSubtext: ((raw['allTimeSubtext'] as String?) ?? '').trim(),
    );
  }
}

class CompanyEarningsMonthDatum {
  const CompanyEarningsMonthDatum({
    required this.label,
    required this.year,
    required this.month,
    required this.grossAmount,
    required this.netAmount,
    required this.platformFeeRate,
    required this.isCurrentMonth,
  });

  final String label;
  final int year;
  final int month;
  final double grossAmount;
  final double netAmount;
  final double platformFeeRate;
  final bool isCurrentMonth;

  factory CompanyEarningsMonthDatum.fromJson(Map<String, dynamic> json) {
    final labelRaw = json['label'] as String? ?? '';
    return CompanyEarningsMonthDatum(
      label: labelRaw.trim(),
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      grossAmount: (json['grossAmount'] as num?)?.toDouble() ?? 0,
      netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0,
      platformFeeRate: (json['platformFeeRate'] as num?)?.toDouble() ?? 0,
      isCurrentMonth: json['isCurrentMonth'] == true,
    );
  }
}

class CompanyEarningsMonthlyNetIncome {
  const CompanyEarningsMonthlyNetIncome({
    required this.title,
    required this.rangeLabel,
    required this.footnote,
    required this.months,
  });

  final String title;
  final String rangeLabel;
  final String footnote;
  final List<CompanyEarningsMonthDatum> months;

  static CompanyEarningsMonthlyNetIncome maybeParse(dynamic raw) {
    final map = raw is Map<String, dynamic> ? raw : null;
    final rawMonths = map?['months'];
    final list = rawMonths is List<dynamic>
        ? rawMonths
            .whereType<Map<String, dynamic>>()
            .map(CompanyEarningsMonthDatum.fromJson)
            .toList()
        : <CompanyEarningsMonthDatum>[];
    return CompanyEarningsMonthlyNetIncome(
      title: ((map?['title'] as String?) ?? 'MONTHLY NET INCOME').trim(),
      rangeLabel: ((map?['rangeLabel'] as String?) ?? 'Last 6 months').trim(),
      footnote: ((map?['footnote'] as String?) ?? '').trim(),
      months: list,
    );
  }
}

class CompanyEarningsSummary {
  const CompanyEarningsSummary({
    required this.cards,
    required this.display,
    required this.monthlyNetIncome,
  });

  final CompanyEarningsCards cards;
  final CompanyEarningsDisplay display;
  final CompanyEarningsMonthlyNetIncome monthlyNetIncome;

  static CompanyEarningsSummary? tryParse(dynamic root) {
    if (root is! Map<String, dynamic>) return null;
    Map<String, dynamic> data = root;
    if (root.containsKey('data')) {
      final inner = root['data'];
      if (inner is! Map<String, dynamic>) return null;
      data = inner;
    }
    final cards = CompanyEarningsCards.maybeParse(data['cards']);
    if (cards == null) return null;
    return CompanyEarningsSummary(
      cards: cards,
      display: CompanyEarningsDisplay.maybeParse(data['display']),
      monthlyNetIncome: CompanyEarningsMonthlyNetIncome.maybeParse(data['monthlyNetIncome']),
    );
  }
}

// ─── Company earnings jobs list (`GET /api/v1/company/earnings/jobs`) ────────

class CompanyEarningsJobsListMeta {
  const CompanyEarningsJobsListMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  static CompanyEarningsJobsListMeta? maybeParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    return CompanyEarningsJobsListMeta(
      page: (raw['page'] as num?)?.toInt() ?? 1,
      limit: (raw['limit'] as num?)?.toInt() ?? 20,
      total: (raw['total'] as num?)?.toInt() ?? 0,
      totalPages: (raw['totalPages'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Mechanic snippet on earning job rows (`mechanic` from `…/company/earnings/jobs`).
class CompanyEarningsCompletedJobMechanic {
  const CompanyEarningsCompletedJobMechanic({
    required this.mongoId,
    required this.displayName,
    required this.rating,
    required this.profilePhotoUrl,
  });

  final String mongoId;
  final String displayName;
  final double rating;
  final String profilePhotoUrl;

  static CompanyEarningsCompletedJobMechanic? maybeParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final name = (raw['displayName'] as String?)?.trim() ?? '';
    return CompanyEarningsCompletedJobMechanic(
      mongoId: ((raw['_id'] as String?) ?? '').trim(),
      displayName: name.isNotEmpty ? name : '—',
      rating: (raw['rating'] as num?)?.toDouble() ?? 0,
      profilePhotoUrl: ((raw['profilePhotoUrl'] as String?) ?? '').trim(),
    );
  }

  String get ratingDisplay =>
      rating == rating.roundToDouble() ? '${rating.round()}' : rating.toStringAsFixed(1);
}

class CompanyEarningsCompletedJobInvoice {
  const CompanyEarningsCompletedJobInvoice({
    required this.invoiceMongoId,
    required this.invoiceNo,
    required this.pdfUrl,
    required this.status,
    required this.paidAtIso,
  });

  final String? invoiceMongoId;
  final String invoiceNo;
  final String? pdfUrl;
  final String status;
  final String paidAtIso;

  static CompanyEarningsCompletedJobInvoice? maybeParse(dynamic raw) {
    if (raw == null || raw is! Map<String, dynamic>) return null;
    final invoiceNo = (raw['invoiceNo'] as String?)?.trim();
    if (invoiceNo == null || invoiceNo.isEmpty) return null;
    return CompanyEarningsCompletedJobInvoice(
      invoiceMongoId: (raw['_id'] as String?)?.trim(),
      invoiceNo: invoiceNo,
      pdfUrl: (raw['pdfUrl'] as String?)?.trim(),
      status: ((raw['status'] as String?) ?? '').trim(),
      paidAtIso: ((raw['paidAt'] as String?) ?? '').trim(),
    );
  }
}

class CompanyEarningsJobPrimaryAction {
  const CompanyEarningsJobPrimaryAction({
    required this.key,
    required this.label,
    required this.icon,
    this.invoiceId,
    this.href,
  });

  final String key;
  final String label;
  final String icon;
  final String? invoiceId;
  final String? href;

  static CompanyEarningsJobPrimaryAction? maybeParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final label = ((raw['label'] as String?) ?? '').trim();
    final href = ((raw['href'] as String?) ?? '').trim();
    if (label.isEmpty && href.isEmpty) return null;
    return CompanyEarningsJobPrimaryAction(
      key: ((raw['key'] as String?) ?? '').trim(),
      label: label.isNotEmpty ? label : 'Open',
      icon: ((raw['icon'] as String?) ?? '').trim(),
      invoiceId: ((raw['invoiceId'] as String?) ?? '').trim(),
      href: href.isNotEmpty ? href : null,
    );
  }
}

class CompanyEarningsCompletedJob {
  const CompanyEarningsCompletedJob({
    required this.id,
    required this.jobCode,
    required this.title,
    required this.description,
    required this.vehicleHeadline,
    required this.vehicleRegistration,
    required this.locationAddress,
    required this.completedDateLabel,
    required this.durationLabel,
    required this.platformFeePercent,
    required this.grossAmount,
    required this.platformFee,
    required this.netAmount,
    required this.currency,
    this.mechanic,
    this.fleetCompanyName,
    this.invoice,
    this.primaryAction,
  });

  final String id;
  final String jobCode;
  final String title;
  final String description;
  final String vehicleHeadline;
  final String vehicleRegistration;
  final String locationAddress;
  final String completedDateLabel;
  final String durationLabel;
  final double platformFeePercent;
  final double grossAmount;
  final double platformFee;
  final double netAmount;
  final String currency;
  final CompanyEarningsCompletedJobMechanic? mechanic;
  final String? fleetCompanyName;
  final CompanyEarningsCompletedJobInvoice? invoice;
  final CompanyEarningsJobPrimaryAction? primaryAction;

  /// Title line under header: headline + registration when helpful.
  String get vehicleSubtitleLine {
    final h = vehicleHeadline.trim();
    final reg = vehicleRegistration.trim();
    if (h.isEmpty && reg.isEmpty) return '—';
    if (reg.isEmpty) return h;
    if (h.isEmpty) return reg;
    if (h.toLowerCase().contains(reg.toLowerCase())) return h;
    return '$h · $reg';
  }

  factory CompanyEarningsCompletedJob.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'];
    String reg = '';
    if (vehicle is Map<String, dynamic>) {
      reg = ((vehicle['registration'] as String?) ?? '').trim();
    }
    final fleetRaw = json['fleet'];
    String? fleetName;
    if (fleetRaw is Map<String, dynamic>) {
      fleetName = (fleetRaw['companyName'] as String?)?.trim();
      if (fleetName != null && fleetName.isEmpty) fleetName = null;
    }

    return CompanyEarningsCompletedJob(
      id: ((json['_id'] as String?) ?? (json['id'] as String?) ?? '').trim(),
      jobCode: ((json['jobCode'] as String?) ?? '').trim(),
      title: ((json['title'] as String?) ?? '').trim(),
      description: ((json['description'] as String?) ?? '').trim(),
      vehicleHeadline: ((json['vehicleHeadline'] as String?) ?? '').trim(),
      vehicleRegistration: reg,
      locationAddress: _parseLocationAddress(json['location']),
      completedDateLabel: ((json['completedDateLabel'] as String?) ?? '').trim(),
      durationLabel: ((json['durationLabel'] as String?) ?? '').trim(),
      platformFeePercent: (json['platformFeePercent'] as num?)?.toDouble() ?? 0,
      grossAmount: (json['grossAmount'] as num?)?.toDouble() ?? 0,
      platformFee: (json['platformFee'] as num?)?.toDouble() ?? 0,
      netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0,
      currency: ((json['currency'] as String?) ?? 'GBP').trim(),
      mechanic: CompanyEarningsCompletedJobMechanic.maybeParse(json['mechanic']),
      fleetCompanyName: fleetName,
      invoice: CompanyEarningsCompletedJobInvoice.maybeParse(json['invoice']),
      primaryAction: CompanyEarningsJobPrimaryAction.maybeParse(json['primaryAction']),
    );
  }

  static String _parseLocationAddress(dynamic raw) {
    if (raw is! Map<String, dynamic>) return '';
    return ((raw['address'] as String?) ?? '').trim();
  }
}

// ─── Company jobs list (`GET /api/v1/company/jobs`) ──────────────────────────

class CompanyJobUiBadge {
  const CompanyJobUiBadge({required this.label, required this.tone});

  final String label;
  final String tone;

  factory CompanyJobUiBadge.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CompanyJobUiBadge(label: '', tone: 'neutral');
    }
    return CompanyJobUiBadge(
      label: ((json['label'] as String?) ?? '').trim(),
      tone: ((json['tone'] as String?) ?? 'neutral').trim(),
    );
  }
}

class CompanyManagementJobMechanic {
  const CompanyManagementJobMechanic({
    required this.displayName,
    required this.workStatusLine,
    required this.profilePhotoUrl,
    this.rating,
  });

  final String displayName;
  final String workStatusLine;
  final String profilePhotoUrl;
  final double? rating;

  static CompanyManagementJobMechanic? maybeParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final name = (raw['displayName'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;
    return CompanyManagementJobMechanic(
      displayName: name,
      workStatusLine: ((raw['workStatusLine'] as String?) ?? '').trim(),
      profilePhotoUrl: ((raw['profilePhotoUrl'] as String?) ?? '').trim(),
      rating: (raw['rating'] as num?)?.toDouble(),
    );
  }
}

/// Line on a job invoice (`parts[]` from API → `PATCH .../complete/approve` body).
class CompanyInvoiceLineItem {
  const CompanyInvoiceLineItem({
    required this.description,
    required this.amount,
  });

  final String description;
  final double amount;
}

class CompanyManagementJobInvoice {
  const CompanyManagementJobInvoice({
    required this.label,
    required this.totalAmount,
    required this.currency,
    this.invoiceNo,
    this.status,
    this.callOutCharge,
    this.labourHours,
    this.labourRatePerHour,
    this.partsLines = const [],
  });

  final String label;
  final double? totalAmount;
  final String currency;
  final String? invoiceNo;
  final String? status;
  final double? callOutCharge;
  final double? labourHours;
  final double? labourRatePerHour;
  final List<CompanyInvoiceLineItem> partsLines;

  static List<CompanyInvoiceLineItem> _parseParts(dynamic raw) {
    if (raw is! List<dynamic>) return const [];
    final out = <CompanyInvoiceLineItem>[];
    for (final e in raw) {
      if (e is! Map<String, dynamic>) continue;
      final desc = ((e['description'] as String?) ?? (e['name'] as String?) ?? '').trim();
      final amt = (e['amount'] as num?)?.toDouble() ?? (e['cost'] as num?)?.toDouble() ?? 0.0;
      if (desc.isEmpty && amt == 0) continue;
      out.add(CompanyInvoiceLineItem(description: desc, amount: amt));
    }
    return out;
  }

  static CompanyManagementJobInvoice? maybeParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    return CompanyManagementJobInvoice(
      label: ((raw['label'] as String?) ?? 'Total invoice').trim(),
      totalAmount: (raw['totalAmount'] as num?)?.toDouble(),
      currency: ((raw['currency'] as String?) ?? 'GBP').trim(),
      invoiceNo: (raw['invoiceNo'] as String?)?.trim(),
      status: (raw['status'] as String?)?.trim(),
      callOutCharge: (raw['callOutCharge'] as num?)?.toDouble() ?? (raw['callOut'] as num?)?.toDouble(),
      labourHours: (raw['labourHours'] as num?)?.toDouble(),
      labourRatePerHour: (raw['labourRatePerHour'] as num?)?.toDouble() ??
          (raw['hourlyRate'] as num?)?.toDouble() ??
          (raw['labourRate'] as num?)?.toDouble(),
      partsLines: _parseParts(raw['parts']),
    );
  }
}

class CompanyManagementJobAction {
  const CompanyManagementJobAction({
    required this.key,
    required this.label,
    required this.icon,
    required this.method,
    this.path,
  });

  final String key;
  final String label;
  final String icon;
  final String method;
  final String? path;

  static CompanyManagementJobAction? maybeParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final label = (raw['label'] as String?)?.trim() ?? '';
    final key = (raw['key'] as String?)?.trim() ?? '';
    if (label.isEmpty && key.isEmpty) return null;
    return CompanyManagementJobAction(
      key: key,
      label: label.isNotEmpty ? label : key,
      icon: ((raw['icon'] as String?) ?? '').trim(),
      method: ((raw['method'] as String?) ?? 'PATCH').trim().toUpperCase(),
      path: (raw['path'] as String?)?.trim(),
    );
  }
}

class CompanyManagementJob {
  const CompanyManagementJob({
    required this.id,
    required this.jobCode,
    required this.title,
    required this.statusRaw,
    required this.statusUi,
    required this.urgencyUi,
    required this.vehicleHeadline,
    required this.locationLabel,
    required this.timelineLabel,
    required this.completedAgoLabel,
    required this.postedAgoLabel,
    required this.mechanic,
    required this.fleetCompanyName,
    required this.invoice,
    required this.finalAmount,
    required this.acceptedAmount,
    required this.currency,
    required this.primaryAction,
  });

  final String id;
  final String jobCode;
  final String title;
  final String statusRaw;
  final CompanyJobUiBadge statusUi;
  final CompanyJobUiBadge? urgencyUi;
  final String vehicleHeadline;
  final String locationLabel;
  final String? timelineLabel;
  final String? completedAgoLabel;
  final String? postedAgoLabel;
  final CompanyManagementJobMechanic? mechanic;
  final String fleetCompanyName;
  final CompanyManagementJobInvoice? invoice;
  final double? finalAmount;
  final double? acceptedAmount;
  final String currency;
  final CompanyManagementJobAction? primaryAction;

  String get displayVehicle =>
      vehicleHeadline.isNotEmpty ? vehicleHeadline : (title.isNotEmpty ? title : '—');

  /// Amount shown on cards: invoice total, else final, else accepted.
  double? get displayAmount {
    final inv = invoice?.totalAmount;
    if (inv != null) return inv;
    if (finalAmount != null) return finalAmount;
    return acceptedAmount;
  }

  String get currencyDisplay => currency.isNotEmpty ? currency : 'GBP';

  String timeRowLabel() {
    final t = (completedAgoLabel ?? timelineLabel ?? postedAgoLabel ?? '').trim();
    return t;
  }

  factory CompanyManagementJob.fromJson(Map<String, dynamic> json) {
    final fu = json['fleet'];
    String fleetName = '';
    if (fu is Map<String, dynamic>) {
      fleetName = ((fu['companyName'] as String?) ?? '').trim();
    }
    return CompanyManagementJob(
      id: ((json['_id'] as String?) ?? (json['id'] as String?) ?? '').trim(),
      jobCode: ((json['jobCode'] as String?) ?? '').trim(),
      title: ((json['title'] as String?) ?? '').trim(),
      statusRaw: ((json['status'] as String?) ?? '').trim(),
      statusUi: CompanyJobUiBadge.fromJson(json['statusUi'] is Map<String, dynamic> ? json['statusUi'] as Map<String, dynamic> : null),
      urgencyUi: json['urgencyUi'] is Map<String, dynamic>
          ? CompanyJobUiBadge.fromJson(json['urgencyUi'] as Map<String, dynamic>)
          : null,
      vehicleHeadline: ((json['vehicleHeadline'] as String?) ?? '').trim(),
      locationLabel: ((json['locationLabel'] as String?) ?? '').trim(),
      timelineLabel: (json['timelineLabel'] as String?)?.trim(),
      completedAgoLabel: (json['completedAgoLabel'] as String?)?.trim(),
      postedAgoLabel: (json['postedAgoLabel'] as String?)?.trim(),
      mechanic: CompanyManagementJobMechanic.maybeParse(json['assignedMechanic']),
      fleetCompanyName: fleetName,
      invoice: CompanyManagementJobInvoice.maybeParse(json['invoice']),
      finalAmount: (json['finalAmount'] as num?)?.toDouble(),
      acceptedAmount: (json['acceptedAmount'] as num?)?.toDouble(),
      currency: ((json['currency'] as String?) ?? 'GBP').trim(),
      primaryAction: CompanyManagementJobAction.maybeParse(json['primaryAction']),
    );
  }
}

class CompanyJobsTabCounts {
  const CompanyJobsTabCounts({
    required this.all,
    required this.pendingReview,
    required this.unassigned,
    required this.assigned,
    required this.inProgress,
  });

  final int all;
  final int pendingReview;
  final int unassigned;
  final int assigned;
  final int inProgress;

  static CompanyJobsTabCounts? maybeParse(Map<String, dynamic>? m) {
    if (m == null) return null;
    return CompanyJobsTabCounts(
      all: (m['all'] as num?)?.toInt() ?? 0,
      pendingReview: (m['pendingReview'] as num?)?.toInt() ?? 0,
      unassigned: (m['unassigned'] as num?)?.toInt() ?? 0,
      assigned: (m['assigned'] as num?)?.toInt() ?? 0,
      inProgress: (m['inProgress'] as num?)?.toInt() ?? 0,
    );
  }

  int countForUiTab(String filterLabel) {
    switch (filterLabel) {
      case 'All':
        return all;
      case 'Pending Review':
        return pendingReview;
      case 'Unassigned':
        return unassigned;
      case 'Assigned':
        return assigned;
      case 'In Progress':
        return inProgress;
      default:
        return all;
    }
  }
}

class CompanyJobsMeta {
  const CompanyJobsMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.tab,
    required this.pendingReviewCount,
    this.tabCounts,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final String? tab;
  final int pendingReviewCount;
  final CompanyJobsTabCounts? tabCounts;

  static CompanyJobsMeta? maybeParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final tcRaw = raw['tabCounts'];
    Map<String, dynamic>? tcMap;
    if (tcRaw is Map<String, dynamic>) {
      tcMap = tcRaw;
    }
    return CompanyJobsMeta(
      page: (raw['page'] as num?)?.toInt() ?? 1,
      limit: (raw['limit'] as num?)?.toInt() ?? 20,
      total: (raw['total'] as num?)?.toInt() ?? 0,
      totalPages: (raw['totalPages'] as num?)?.toInt() ?? 1,
      tab: (raw['tab'] as String?)?.trim(),
      pendingReviewCount: (raw['pendingReviewCount'] as num?)?.toInt() ?? 0,
      tabCounts: CompanyJobsTabCounts.maybeParse(tcMap),
    );
  }
}

// ─── Company job feed `/api/v1/company/feed` ────────────────────────────────

class CompanyFeedMeta {
  const CompanyFeedMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.activeCount,
  });

  final int page;
  final int limit;
  final int total;
  final int activeCount;

  static CompanyFeedMeta? maybeParse(Map<String, dynamic>? meta) {
    if (meta == null) return null;
    return CompanyFeedMeta(
      page: (meta['page'] as num?)?.toInt() ?? 1,
      limit: (meta['limit'] as num?)?.toInt() ?? 20,
      total: (meta['total'] as num?)?.toInt() ?? 0,
      activeCount: (meta['activeCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class CompanyFeedJob {
  const CompanyFeedJob({
    required this.jobBackendId,
    required this.jobCode,
    required this.title,
    required this.description,
    required this.urgency,
    required this.vehicleLine,
    required this.locationAddress,
    required this.postedAgoLabel,
    this.fleetRating,
    this.distanceMiles,
    this.estimatedPayout,
    this.currency,
  });

  final String jobBackendId;
  final String jobCode;
  final String title;
  final String description;
  final String urgency;
  final String vehicleLine;
  final String locationAddress;
  final String postedAgoLabel;
  final double? fleetRating;
  final double? distanceMiles;
  final num? estimatedPayout;
  final String? currency;

  /// Card line under bold vehicle (`title`; falls back to `description`).
  String get subtitleLine =>
      title.isNotEmpty ? title : (description.isNotEmpty ? description : '—');

  String distanceMilesDisplay() {
    final d = distanceMiles;
    if (d == null) return '—';
    if (d == d.roundToDouble()) return '${d.round()} miles';
    return '${d.toStringAsFixed(1)} miles';
  }

  factory CompanyFeedJob.fromJson(Map<String, dynamic> j) {
    final vehicle = (j['vehicle'] is Map<String, dynamic>)
        ? j['vehicle'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final location = (j['location'] is Map<String, dynamic>)
        ? j['location'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final fleet = (j['fleet'] is Map<String, dynamic>)
        ? j['fleet'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final make = (vehicle['make'] as String?) ?? '';
    final model = (vehicle['model'] as String?) ?? '';
    final vehicleLine = [make, model].where((s) => s.trim().isNotEmpty).join(' ');

    double? dm;
    final dmRaw = j['distanceMiles'];
    if (dmRaw is num) dm = dmRaw.toDouble();

    double? rating;
    final rt = fleet['rating'];
    if (rt is num) rating = rt.toDouble();

    return CompanyFeedJob(
      jobBackendId: (j['_id'] as String?) ?? '',
      jobCode: (j['jobCode'] as String?) ?? '',
      title: ((j['title'] as String?) ?? '').trim(),
      description: ((j['description'] as String?) ?? '').trim(),
      urgency: ((j['urgency'] as String?) ?? 'MEDIUM').trim().toUpperCase(),
      vehicleLine: vehicleLine,
      locationAddress: ((location['address'] as String?) ?? '').trim(),
      postedAgoLabel: ((j['postedAgoLabel'] as String?) ?? '').trim(),
      fleetRating: rating,
      distanceMiles: dm,
      estimatedPayout: j['estimatedPayout'] as num?,
      currency: j['currency'] as String?,
    );
  }
}

// ─── Company `GET /api/v1/users/me` (company profile UI) ──────────────────────

/// Performance stats for company profile hero tiles (prefer `companyProfile.profileMetricsOverride`,
/// fallback `companySummary.profileMetrics`).
class CompanyMeProfileMetrics {
  const CompanyMeProfileMetrics({
    required this.totalJobs,
    required this.avgRating,
    required this.responseMinutesAvg,
  });

  final int totalJobs;
  final double avgRating;
  final int responseMinutesAvg;

  /// Filled stars 0–5 derived from rating (rounded up, min 1 when rating ≥ 1).
  int get starFilledCount {
    if (avgRating < 1) return (avgRating > 0) ? avgRating.ceil().clamp(1, 5) : 0;
    return avgRating.ceil().clamp(1, 5);
  }

  String get avgRatingLabel => avgRating == avgRating.roundToDouble() ? '${avgRating.round()}' : avgRating.toStringAsFixed(1);

  String get totalJobsLabel => '$totalJobs';

  String get responseLabel => responseMinutesAvg > 0 ? '$responseMinutesAvg min' : '—';
}

/// `companySummary.teamOverview` (preferred for Team Overview tiles).
class CompanyMeTeamOverview {
  const CompanyMeTeamOverview({
    required this.totalMechanics,
    required this.onlineNow,
    required this.activeJobs,
  });

  final int totalMechanics;
  final int onlineNow;
  final int activeJobs;

  static CompanyMeTeamOverview? maybe(Map<String, dynamic> companySummary) {
    if (companySummary.isEmpty) return null;
    Map<String, dynamic>? m;
    final rawOv = companySummary['teamOverview'];
    if (rawOv is Map<String, dynamic>) m = rawOv;

    final hasNested = rawOv is Map<String, dynamic>;
    final hasFlatFields = ['totalMechanics', 'onlineNow', 'activeJobs'].any((k) => companySummary.containsKey(k));
    if (!hasNested && !hasFlatFields) return null;

    int nestedOrFlat(String nestedKey, String flatKey) {
      if (m != null && m[nestedKey] is num) return (m[nestedKey] as num).toInt();
      final f = companySummary[flatKey];
      return (f is num) ? f.toInt() : 0;
    }

    return CompanyMeTeamOverview(
      totalMechanics: nestedOrFlat('totalMechanics', 'totalMechanics'),
      onlineNow: nestedOrFlat('onlineNow', 'onlineNow'),
      activeJobs: nestedOrFlat('activeJobs', 'activeJobs'),
    );
  }
}

/// Bank rows: `companySummary.bankBilling` overrides with `companyProfile` / `paymentSummary` fallback.
class CompanyMeBankBilling {
  const CompanyMeBankBilling({
    required this.bankName,
    required this.accountMasked,
    required this.sortCode,
    required this.billingAddress,
  });

  final String bankName;
  final String accountMasked;
  final String sortCode;
  final String billingAddress;

  /// Display masking similar to prototype (`•••• •••• 9876`).
  static String prettifyMasked(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '—';
    return t.replaceAll('*', '•');
  }

  factory CompanyMeBankBilling.merge(Map<String, dynamic> companyProfile, Map<String, dynamic> companySummary,
      Map<String, dynamic> paymentSummary) {
    final bb = companySummary['bankBilling'] is Map<String, dynamic>
        ? companySummary['bankBilling'] as Map<String, dynamic>
        : null;

    String pick(String bbKey, String cpKey, String psKey) {
      if (bb != null) {
        final vbb = bb[bbKey];
        if (vbb != null && '$vbb'.trim().isNotEmpty) return '$vbb'.trim();
      }
      final vcp = companyProfile[cpKey];
      if (vcp != null && '$vcp'.trim().isNotEmpty) return '$vcp'.trim();
      final vps = paymentSummary[psKey];
      return vps == null ? '' : '$vps'.trim();
    }

    return CompanyMeBankBilling(
      bankName: pick('bankName', 'bankDisplayName', 'bankName'),
      accountMasked: pick('accountMasked', 'bankAccountMasked', 'accountMasked'),
      sortCode: pick('sortCode', 'bankSortCode', 'sortCodeMasked'),
      billingAddress: pick('billingAddress', 'billingAddress', 'billingAddress'),
    );
  }

  String get accountDisplay =>
      prettifyMasked(accountMasked);
}

/// Parsed envelope for `/users/me` for company role Profile tab.
class CompanyMeSnapshot {
  const CompanyMeSnapshot({
    required this.email,
    required this.profilePhotoUrl,
    required this.profileCompleted,
    required this.companyName,
    required this.regNumber,
    required this.vatNumber,
    required this.baseLocationText,
    required this.serviceRadiusMiles,
    required this.metrics,
    required this.teamOverview,
    required this.bankBilling,
    required this.memberSinceLabel,
  });

  final String email;
  final String profilePhotoUrl;
  final bool profileCompleted;
  final String companyName;
  final String regNumber;
  final String vatNumber;
  final String baseLocationText;
  final int serviceRadiusMiles;

  /// Optional; when absent UI falls back to team list / dashboard.
  final CompanyMeTeamOverview? teamOverview;

  final CompanyMeProfileMetrics metrics;

  /// Always non-null merged block (possibly empty strings).
  final CompanyMeBankBilling bankBilling;

  final String memberSinceLabel;

  factory CompanyMeSnapshot.parse(Map<String, dynamic> envelope) {
    final data = envelope['data'] is Map<String, dynamic>
        ? envelope['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    Map<String, dynamic> asMap(dynamic v) => v is Map<String, dynamic> ? v : <String, dynamic>{};

    final cp = asMap(data['companyProfile']);
    final cs = asMap(data['companySummary']);
    final payment = asMap(data['paymentSummary']);

    String pickStr(dynamic a, dynamic b, [dynamic c]) {
      for (final v in [a, b, c]) {
        final s = v == null ? '' : '$v'.trim();
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    final companyName = pickStr(cp['companyName'], cs['companyName'], data['companyName']);

    final regNumber = pickStr(cp['regNumber'], cs['regNumber']);
    final vatNumber = pickStr(cp['vatNumber'], cs['vatNumber']);
    final baseLocationText = pickStr(cp['baseLocationText'], cs['baseLocationText']);
    final svc = cp['serviceRadiusMiles'];
    final svcFallback = cs['serviceRadiusMiles'];
    final serviceRadius = (svc is num)
        ? svc.toInt()
        : (svcFallback is num)
            ? svcFallback.toInt()
            : int.tryParse('${svcFallback ?? svc ?? ''}'.trim()) ?? 0;

    final email = pickStr(data['email'], '');
    final profilePhotoUrl = '${cp['profilePhotoUrl'] ?? ''}'.trim();
    final profileCompleted = cp['profileCompleted'] == true;

    final mv = cp['profileMetricsOverride'] ?? cs['profileMetrics'];
    final mm = asMap(mv);
    final totalJobs = (mm['totalJobs'] as num?)?.toInt() ?? 0;
    final avgRating = (mm['avgRating'] as num?)?.toDouble() ?? 0;
    final responseMin = (mm['responseMinutesAvg'] as num?)?.toInt() ?? 0;
    final metrics = CompanyMeProfileMetrics(
      totalJobs: totalJobs,
      avgRating: avgRating,
      responseMinutesAvg: responseMin,
    );

    CompanyMeTeamOverview? teamOverview;
    if (cs.isNotEmpty) teamOverview = CompanyMeTeamOverview.maybe(cs);

    final bank = CompanyMeBankBilling.merge(cp, cs, payment);

    final memberSinceLabel = CompanyMeSnapshot._memberSinceMonthYear(data['createdAt'] as String?);

    return CompanyMeSnapshot(
      email: email,
      profilePhotoUrl: profilePhotoUrl,
      profileCompleted: profileCompleted,
      companyName: companyName,
      regNumber: regNumber,
      vatNumber: vatNumber,
      baseLocationText: baseLocationText,
      serviceRadiusMiles: serviceRadius,
      metrics: metrics,
      teamOverview: teamOverview,
      bankBilling: bank,
      memberSinceLabel: memberSinceLabel,
    );
  }

  static String _memberSinceMonthYear(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[(d.month - 1).clamp(0, 11)]} ${d.year}';
  }
}

// ─── ViewModel ──────────────────────────────────────────────────────────────

class CompanyViewModel extends ChangeNotifier {
  CompanyViewModel({AuthRepository? auth, CompanyApiService? api, UsersApiService? usersApi, ChatApiService? chat})
      : _auth = auth ?? ApiAuthRepository(),
        _api = api ?? CompanyApiService(),
        _usersApi = usersApi ?? UsersApiService(),
        _chat = chat ?? ChatApiService();

  final AuthRepository _auth;
  final CompanyApiService _api;
  final UsersApiService _usersApi;
  final ChatApiService _chat;

  String screen = 'company-dashboard';

  // My Quotes
  List<CompanyQuote> myQuotes = [];
  bool myQuotesLoading = false;
  String? myQuotesError;

  /// Company job feed (`/api/v1/company/feed`).
  List<CompanyFeedJob> feedJobs = [];
  CompanyFeedMeta? feedMeta;
  bool feedLoading = false;
  String? feedError;

  /// Company dashboard (`/api/v1/company/dashboard`).
  CompanyDashboardData? dashboard;
  bool dashboardLoading = false;
  String? dashboardError;

  /// Mechanics & invites (`/api/v1/company/team`).
  List<CompanyTeamMember> teamMembers = [];
  List<CompanyTeamPendingInvite> teamPendingInvites = [];
  CompanyTeamInviteAction? teamInviteAction;
  CompanyTeamMeta? teamMeta;
  bool teamLoading = false;
  String? teamError;
  bool teamInviteSending = false;
  String? teamInviteError;
  bool teamMemberRemoveLoading = false;
  String? teamMemberRemoveError;

  /// `/api/v1/company/earnings/summary` (cards + chart).
  CompanyEarningsSummary? companyEarningsSummary;
  bool companyEarningsLoading = false;
  String? companyEarningsError;

  /// `/api/v1/company/earnings/jobs` (completed earning rows + invoice CTAs).
  List<CompanyEarningsCompletedJob> companyEarningsJobs = [];
  CompanyEarningsJobsListMeta? companyEarningsJobsMeta;
  bool companyEarningsJobsLoading = false;
  String? companyEarningsJobsError;

  /// `/api/v1/company/jobs` (job management list).
  List<CompanyManagementJob> companyJobs = [];
  CompanyJobsMeta? companyJobsMeta;
  bool companyJobsLoading = false;
  String? companyJobsError;
  bool companyJobAssignBusy = false;
  String? _companyJobsTabQuery;

  CompanyMeSnapshot? companyMeSnapshot;
  bool companyMeLoading = false;
  String? companyMeError;

  /// Profile → Messages (`GET /api/v1/chat/threads`).
  List<MechanicMessageThread> companyMessageThreads = [];
  bool companyMessageThreadsLoading = false;
  String? companyMessageThreadsError;

  MechanicMessageThread? activeCompanyChatPeer;

  int get jobsTabBadge {
    final fromTeam = teamMeta?.jobsNavBadgeCount;
    if (fromTeam != null) return fromTeam;
    final pendingJobs = companyJobsMeta?.pendingReviewCount;
    if (pendingJobs != null && pendingJobs > 0) return pendingJobs;
    return dashboard == null ? 0 : dashboard!.unassignedJobsCount;
  }

  void setScreen(String s) {
    if (screen == 'company-messages-chat' && s != 'company-messages-chat') {
      activeCompanyChatPeer = null;
    }
    screen = s;
    notifyListeners();
    if (s == 'company-messages') {
      loadCompanyMessageThreads();
    }
  }

  Future<void> loadCompanyMessageThreads() async {
    companyMessageThreadsLoading = true;
    companyMessageThreadsError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Missing access token. Please login again.');
      }
      final env = await _chat.fetchThreads(accessToken: token);
      final rows = ChatApiService.parseThreadsEnvelope(env);
      companyMessageThreads = rows
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
      companyMessageThreadsError = e.toString();
    } finally {
      companyMessageThreadsLoading = false;
      notifyListeners();
    }
  }

  void openCompanyMessageChat(MechanicMessageThread thread) {
    activeCompanyChatPeer = thread;
    screen = 'company-messages-chat';
    notifyListeners();
  }

  void closeCompanyMessageChat() {
    activeCompanyChatPeer = null;
    screen = 'company-messages';
    notifyListeners();
  }

  String get bottomResolved {
    if (screen == 'company-earnings' ||
        screen == 'company-edit-profile' ||
        screen == 'company-messages' ||
        screen == 'company-messages-chat') {
      return 'company-profile';
    }
    return screen;
  }

  Future<void> loadDashboard() async {
    dashboardLoading = true;
    dashboardError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.isEmpty) throw Exception('Not authenticated');
      final body = await _api.fetchDashboard(accessToken: token);
      dashboard = CompanyDashboardData.tryParse(body);
      if (dashboard == null) throw Exception('Invalid dashboard response');
    } catch (e) {
      dashboardError = e.toString();
    } finally {
      dashboardLoading = false;
      notifyListeners();
    }
  }

  /// Company profile tiles from [`GET /api/v1/users/me`](…) (`companyProfile` + `companySummary`).
  Future<void> loadCompanyMe() async {
    companyMeLoading = true;
    companyMeError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.isEmpty) throw Exception('Not authenticated');
      final body = await _usersApi.fetchMe(accessToken: token);
      companyMeSnapshot = CompanyMeSnapshot.parse(body);
    } catch (e) {
      companyMeError = e.toString();
    } finally {
      companyMeLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCompanyFeed({int page = 1, int limit = 20}) async {
    feedLoading = true;
    feedError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.isEmpty) throw Exception('Not authenticated');
      final body = await _api.fetchCompanyFeed(accessToken: token, page: page, limit: limit);
      final raw = body['data'];
      final rows = raw is List<dynamic>
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(CompanyFeedJob.fromJson)
              .toList()
          : <CompanyFeedJob>[];
      feedJobs = rows;
      feedMeta =
          CompanyFeedMeta.maybeParse(body['meta'] is Map<String, dynamic> ? body['meta'] as Map<String, dynamic> : null);
    } catch (e) {
      feedError = e.toString();
    } finally {
      feedLoading = false;
      notifyListeners();
    }
  }

  /// `POST /api/v1/jobs/:jobId/quotes` then refreshes feed and my quotes.
  Future<String?> submitFeedJobQuote({
    required String jobBackendId,
    required double amount,
    required int etaMinutes,
    String notes = '',
  }) async {
    final session = await _auth.getSession();
    final token = session?.accessToken;
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    if (jobBackendId.isEmpty) throw Exception('Invalid job');
    final body = await _api.postJobQuote(
      accessToken: token,
      jobId: jobBackendId,
      amount: amount,
      etaMinutes: etaMinutes,
      notes: notes.trim(),
    );
    await loadCompanyFeed();
    await loadMyQuotes();
    final msg = (body['message'] as String?)?.trim();
    return msg != null && msg.isNotEmpty ? msg : null;
  }

  Future<void> loadMyQuotes() async {
    myQuotesLoading = true;
    myQuotesError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.isEmpty) throw Exception('Not authenticated');
      final body = await _api.fetchMyQuotes(accessToken: token, limit: 100);
      final raw = (body['quotes'] is List)
          ? body['quotes'] as List<dynamic>
          : (body['data'] is List)
              ? body['data'] as List<dynamic>
              : <dynamic>[];
      myQuotes = raw
          .whereType<Map<String, dynamic>>()
          .map(CompanyQuote.fromJson)
          .toList();
    } catch (e) {
      myQuotesError = e.toString();
    } finally {
      myQuotesLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCompanyEarningsSummary() async {
    companyEarningsLoading = true;
    companyEarningsError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.isEmpty) throw Exception('Not authenticated');
      final body = await _api.fetchCompanyEarningsSummary(accessToken: token);
      final parsed = CompanyEarningsSummary.tryParse(body);
      if (parsed == null) throw Exception('Invalid earnings summary response');
      companyEarningsSummary = parsed;
    } catch (e) {
      companyEarningsError = e.toString();
    } finally {
      companyEarningsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCompanyEarningsJobs({int page = 1, int limit = 20}) async {
    companyEarningsJobsLoading = true;
    companyEarningsJobsError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.isEmpty) throw Exception('Not authenticated');
      final body = await _api.fetchCompanyEarningsJobs(accessToken: token, page: page, limit: limit);
      companyEarningsJobsMeta = CompanyEarningsJobsListMeta.maybeParse(body['meta']);
      final raw = body['data'];
      companyEarningsJobs = raw is List<dynamic>
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(CompanyEarningsCompletedJob.fromJson)
              .toList()
          : <CompanyEarningsCompletedJob>[];
    } catch (e) {
      companyEarningsJobsError = e.toString();
    } finally {
      companyEarningsJobsLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadCompanyEarningsScreen() async {
    await Future.wait(<Future<void>>[
      loadCompanyEarningsSummary(),
      loadCompanyEarningsJobs(),
    ]);
  }

  /// GET helper for invoice links (`primaryAction.href` → `/api/v1/invoices/...`).
  Future<Map<String, dynamic>> fetchCompanyAuthorizedGet(String path) async {
    final session = await _auth.getSession();
    final token = session?.accessToken;
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    final rel = path.trim();
    if (rel.isEmpty) throw Exception('Invalid link');
    return _api.fetchCompanyAuthorizedGet(accessToken: token, path: rel.startsWith('/') ? rel : '/$rel');
  }

  Future<void> patchCompanyJobPath(String path, {Map<String, dynamic>? body}) async {
    final session = await _auth.getSession();
    final token = session?.accessToken;
    if (token == null || token.isEmpty) throw Exception('Not authenticated');
    await _api.patchCompanyJobPath(accessToken: token, path: path, body: body);
  }

  /// Assigns a mechanic to a job (`POST /api/v1/company/jobs/:jobId/assign` with `{ "mechanicId": … }`).
  Future<void> assignCompanyJobMechanic({required String jobId, required String mechanicId}) async {
    final j = jobId.trim();
    final m = mechanicId.trim();
    if (j.isEmpty || m.isEmpty) throw Exception('Invalid assignment');
    companyJobAssignBusy = true;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.isEmpty) throw Exception('Not authenticated');
      await _api.postCompanyJobAssign(accessToken: token, jobId: j, mechanicId: m);
    } finally {
      companyJobAssignBusy = false;
      notifyListeners();
    }
    await loadCompanyJobs(tab: _companyJobsTabQuery);
  }

  /// Re-fetches using the last [tab] query (see [loadCompanyJobs]).
  Future<void> reloadCompanyJobs() => loadCompanyJobs(tab: _companyJobsTabQuery);

  /// [tab] matches backend filters (`pending_review`, `unassigned`, `assigned`, `in_progress`, `all`).
  Future<void> loadCompanyJobs({String? tab, int page = 1, int limit = 20}) async {
    _companyJobsTabQuery = tab;
    companyJobsLoading = true;
    companyJobsError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.isEmpty) throw Exception('Not authenticated');
      final body = await _api.fetchCompanyJobs(accessToken: token, page: page, limit: limit, tab: tab);
      final raw = body['data'];
      companyJobs = raw is List<dynamic>
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(CompanyManagementJob.fromJson)
              .toList()
          : <CompanyManagementJob>[];
      companyJobsMeta = CompanyJobsMeta.maybeParse(body['meta']);
    } catch (e) {
      companyJobsError = e.toString();
    } finally {
      companyJobsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCompanyTeam() async {
    teamLoading = true;
    teamError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.isEmpty) throw Exception('Not authenticated');
      final body = await _api.fetchCompanyTeam(accessToken: token);
      final data = body['data'];
      if (data is! Map<String, dynamic>) throw Exception('Invalid team response');

      final rawMembers = data['members'];
      teamMembers = rawMembers is List<dynamic>
          ? rawMembers
              .whereType<Map<String, dynamic>>()
              .map(CompanyTeamMember.fromJson)
              .toList()
          : <CompanyTeamMember>[];

      final rawPending = data['pendingInvites'];
      teamPendingInvites = rawPending is List<dynamic>
          ? rawPending
              .whereType<Map<String, dynamic>>()
              .map(CompanyTeamPendingInvite.fromJson)
              .toList()
          : <CompanyTeamPendingInvite>[];

      final inv = data['inviteAction'];
      teamInviteAction = inv is Map<String, dynamic>
          ? CompanyTeamInviteAction.fromJson(inv)
          : const CompanyTeamInviteAction(method: 'POST', path: '/api/v1/company/team/invitations', bodyFields: ['email']);

      final metaRaw = data['meta'];
      teamMeta = metaRaw is Map<String, dynamic> ? CompanyTeamMeta.fromJson(metaRaw) : null;
    } catch (e) {
      teamError = e.toString();
    } finally {
      teamLoading = false;
      notifyListeners();
    }
  }

  Future<String?> sendCompanyTeamInvitation(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) throw Exception('Email required');
    teamInviteSending = true;
    teamInviteError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.isEmpty) throw Exception('Not authenticated');

      /// Ensure invite action from `/api/v1/company/team` is loaded when possible.
      if (teamInviteAction == null && !teamLoading) {
        await loadCompanyTeam();
      }

      final action = teamInviteAction;
      final method = (action?.method ?? 'POST').toUpperCase();
      if (method != 'POST') {
        throw Exception('Unsupported invite HTTP method ($method)');
      }

      final path = (action?.path ?? '/api/v1/company/team/invitations').trim();
      final fields = action?.bodyFields ?? const ['email'];
      final payload = <String, dynamic>{};
      for (final f in fields) {
        final key = f.trim();
        if (key.isEmpty) continue;
        if (key == 'email') {
          payload[key] = trimmed;
        }
      }
      if (!payload.containsKey('email')) {
        payload['email'] = trimmed;
      }

      final body = await _api.postCompanyTeamInvitation(accessToken: token, path: path, body: payload);
      await loadCompanyTeam();
      final msg = ((body['message'] as String?) ?? '').trim();
      return msg.isNotEmpty ? msg : null;
    } catch (e) {
      teamInviteError = e.toString();
      rethrow;
    } finally {
      teamInviteSending = false;
      notifyListeners();
    }
  }

  /// Resolves DELETE path: prefers [CompanyTeamMember.cardAction.href], else `/api/v1/company/team/members/{mongoId}`.
  String _removeTeamMemberPath(CompanyTeamMember member) {
    final href = member.cardAction?.href.trim() ?? '';
    if (href.isNotEmpty) return href;
    final id = member.mongoId.trim();
    if (id.isEmpty) return '';
    return '/api/v1/company/team/members/$id';
  }

  Future<void> removeCompanyTeamMember(CompanyTeamMember member) async {
    final path = _removeTeamMemberPath(member);
    if (path.isEmpty) throw Exception('Cannot remove: missing member reference');
    teamMemberRemoveLoading = true;
    teamMemberRemoveError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken;
      if (token == null || token.isEmpty) throw Exception('Not authenticated');
      await _api.deleteCompanyTeamByPath(accessToken: token, path: path);
      await loadCompanyTeam();
    } catch (e) {
      teamMemberRemoveError = e.toString();
      rethrow;
    } finally {
      teamMemberRemoveLoading = false;
      notifyListeners();
    }
  }
}
