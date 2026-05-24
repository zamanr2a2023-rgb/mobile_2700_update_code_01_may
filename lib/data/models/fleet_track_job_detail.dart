/// Parsed fleet "Track job" detail from `GET /api/v1/jobs/:id`.
class FleetTrackJobDetailUi {
  const FleetTrackJobDetailUi({
    required this.backendId,
    required this.jobCode,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusTone,
    required this.timeline,
    required this.mechanicName,
    required this.mechanicPhone,
    this.mechanicProfilePhotoUrl,
    required this.mechanicRating,
    required this.etaMinutes,
    required this.locationAddress,
    required this.mapLat,
    required this.mapLng,
    required this.quoteAmount,
    required this.platformFee,
    required this.platformFeePctLabel,
    required this.preAuthHeld,
    required this.totalPayable,
    required this.cardLabel,
    required this.paymentStatusKey,
    required this.paymentStatusLabel,
    required this.currency,
    required this.cancellationCanCancel,
    required this.cancellationIsFree,
    required this.cancellationFee,
    required this.cancellationCurrency,
    required this.hasMechanic,
    required this.mechanicStartedJourney,
  });

  final String backendId;
  final String jobCode;
  final String title;
  /// e.g. "WC 234-567 · Flatbed · Fuel leak suspected"
  final String subtitle;
  final String statusLabel;
  final String statusTone;

  final List<FleetTrackTimelineStepUi> timeline;

  final String mechanicName;
  final String mechanicPhone;
  /// `assignedMechanic.profilePhotoUrl`
  final String? mechanicProfilePhotoUrl;
  final double? mechanicRating;
  final int? etaMinutes;

  final String locationAddress;
  final double? mapLat;
  final double? mapLng;

  final double quoteAmount;
  final double platformFee;
  final String platformFeePctLabel;
  final double preAuthHeld;
  final double totalPayable;
  final String cardLabel;
  /// authorised | paid | refunded | released
  final String paymentStatusKey;
  final String paymentStatusLabel;
  final String currency;

  final bool cancellationCanCancel;
  final bool cancellationIsFree;
  final double cancellationFee;
  final String cancellationCurrency;

  final bool hasMechanic;
  /// True once en-route or later (for showing contact CTA).
  final bool mechanicStartedJourney;

  static FleetTrackJobDetailUi fromApiBody(Map<String, dynamic> body) {
    final root = _unwrapData(body);
    final backendId = _str(root['_id']);
    final jobCode = _str(root['jobCode']);
    final title = _str(root['title']);
    final vehicle = _asMap(root['vehicle']);
    final reg = _str(vehicle['registration']);
    final vType = _str(vehicle['type']);
    final subtitle = [reg, vType, title].where((s) => s.isNotEmpty).join(' · ');

    final statusUi = _asMap(root['statusUi']);
    final fromUi = _str(statusUi['label']);
    final statusLabel = fromUi.isNotEmpty ? fromUi : _str(root['status']);
    final statusTone = _str(statusUi['tone']);

    final timeline = _buildTimeline(root);

    final mech = _asMap(root['assignedMechanic']);
    final mechanicName = _str(mech['displayName']);
    final mechanicPhone = _str(mech['phone']);
    final profilePhotoRaw = _str(mech['profilePhotoUrl']);
    final mechanicProfilePhotoUrl = profilePhotoRaw.isEmpty ? null : profilePhotoRaw;
    final mechanicRating = mech['rating'] is num ? (mech['rating'] as num).toDouble() : double.tryParse(mech['rating']?.toString() ?? '');

    final summary = _asMap(root['summary']);
    final mapBlock = _asMap(root['map']);
    final dest = _asMap(mapBlock['destination']);
    final loc = _asMap(root['location']);
    final address = _str(dest['address'].isNotEmpty ? dest['address'] : loc['address']);
    final coords = (dest['coordinates'] is List) ? dest['coordinates'] as List : (loc['coordinates'] is List ? loc['coordinates'] as List : const []);
    double? lat;
    double? lng;
    if (coords.length >= 2) {
      lng = (coords[0] is num) ? (coords[0] as num).toDouble() : double.tryParse(coords[0].toString());
      lat = (coords[1] is num) ? (coords[1] as num).toDouble() : double.tryParse(coords[1].toString());
    }

    final etaRaw = summary['etaMinutes'] ?? mapBlock['etaMinutes'];
    final etaMinutes = etaRaw is num ? etaRaw.toInt() : int.tryParse(etaRaw?.toString() ?? '');

    final pay = _asMap(root['paymentSummary']);
    final quoteAmount = _money(pay['quoteAmount']);
    final platformFee = _money(pay['platformFee']);
    final preAuthHeld = _money(pay['preAuthHeld']);
    final totalPayable = _money(pay['totalPayable']);
    final currency = _str(pay['currency'].isNotEmpty ? pay['currency'] : root['currency']).toUpperCase();
    final cardRaw = _str(pay['cardLabel'] ?? pay['card_label']);
    final cardLabel = _formatCardLabel(cardRaw);

    final pct = quoteAmount > 0 ? (platformFee / quoteAmount) * 100.0 : 0.0;
    final platformFeePctLabel = quoteAmount > 0 ? '${pct.round()}%' : '—';

    final payStatusRaw = _str(pay['status']).toUpperCase();
    final paymentPair = _normalizePaymentStatus(payStatusRaw);

    final actions = _asMap(root['actions']);
    final cancel = _asMap(actions['cancellation']);
    final cancellationCanCancel = cancel['canCancel'] == true;
    final cancellationIsFree = cancel['isFree'] == true;
    final cancellationFee = cancel['fee'] is num ? (cancel['fee'] as num).toDouble() : double.tryParse(cancel['fee']?.toString() ?? '') ?? 0;
    final cancellationCurrency = _str(cancel['currency'].isNotEmpty ? cancel['currency'] : currency);

    final hasMechanic = mechanicName.isNotEmpty;
    final mechanicStartedJourney = _mechanicStartedJourney(root);

    return FleetTrackJobDetailUi(
      backendId: backendId.isEmpty ? jobCode : backendId,
      jobCode: jobCode.isEmpty ? '—' : jobCode,
      title: title.isEmpty ? '—' : title,
      subtitle: subtitle.isEmpty ? '—' : subtitle,
      statusLabel: statusLabel.isEmpty ? '—' : statusLabel,
      statusTone: statusTone,
      timeline: timeline,
      mechanicName: mechanicName.isEmpty ? '—' : mechanicName,
      mechanicPhone: mechanicPhone,
      mechanicProfilePhotoUrl: mechanicProfilePhotoUrl,
      mechanicRating: mechanicRating,
      etaMinutes: etaMinutes,
      locationAddress: address.isEmpty ? '—' : address,
      mapLat: lat,
      mapLng: lng,
      quoteAmount: quoteAmount,
      platformFee: platformFee,
      platformFeePctLabel: platformFeePctLabel,
      preAuthHeld: preAuthHeld,
      totalPayable: totalPayable,
      cardLabel: cardLabel.isEmpty ? '—' : cardLabel,
      paymentStatusKey: paymentPair.$1,
      paymentStatusLabel: paymentPair.$2,
      currency: currency.isEmpty ? 'GBP' : currency,
      cancellationCanCancel: cancellationCanCancel,
      cancellationIsFree: cancellationIsFree,
      cancellationFee: cancellationFee,
      cancellationCurrency: cancellationCurrency.isEmpty ? currency : cancellationCurrency,
      hasMechanic: hasMechanic,
      mechanicStartedJourney: mechanicStartedJourney,
    );
  }

  static bool _mechanicStartedJourney(Map<String, dynamic> root) {
    final tl = _asMap(root['statusTimeline']);
    if (_parseIso(tl['enRouteAt']) != null) return true;
    if (_parseIso(tl['onSiteAt']) != null) return true;
    if (_parseIso(tl['inProgressAt']) != null) return true;
    final wf = _asMap(root['workflow']);
    final cur = _str(wf['currentStep']).toUpperCase();
    return cur.contains('EN_ROUTE') || cur.contains('ON_SITE') || cur.contains('IN_PROGRESS') || cur == 'COMPLETED';
  }

  static List<FleetTrackTimelineStepUi> _buildTimeline(Map<String, dynamic> root) {
    final tl = _asMap(root['statusTimeline']);
    final wf = _asMap(root['workflow']);
    final current = _str(wf['currentStep']).toUpperCase();
    final steps = wf['steps'];
    Map<String, Map<String, dynamic>> byKey = {};
    if (steps is List) {
      for (final s in steps) {
        final m = _asMap(s);
        final k = _str(m['key']).toUpperCase();
        if (k.isNotEmpty) byKey[k] = m;
      }
    }

    String timeFor(String isoKey) {
      final d = _parseIso(tl[isoKey]);
      if (d == null) return '';
      final local = d.toLocal();
      final h = local.hour.toString().padLeft(2, '0');
      final min = local.minute.toString().padLeft(2, '0');
      return '$h:$min';
    }

    bool rowDone(String flowKey) {
      switch (flowKey) {
        case 'posted':
          return _parseIso(tl['postedAt']) != null;
        case 'assigned':
          final st = byKey['ASSIGNED'];
          if (st != null && st['done'] == true) return true;
          return _parseIso(tl['assignedAt']) != null;
        case 'en_route':
          final st = byKey['EN_ROUTE'];
          if (st != null && st['done'] == true) return true;
          return _parseIso(tl['enRouteAt']) != null;
        case 'arrived':
          final st = byKey['ON_SITE'];
          if (st != null && st['done'] == true) return true;
          return _parseIso(tl['onSiteAt']) != null;
        case 'in_progress':
          final st = byKey['IN_PROGRESS'];
          if (st != null && st['done'] == true) return true;
          return _parseIso(tl['inProgressAt']) != null;
        case 'completed':
          final st = byKey['COMPLETED'];
          if (st != null && st['done'] == true) return true;
          return _parseIso(tl['completedAt']) != null;
        default:
          return false;
      }
    }

    bool rowActive(String flowKey) {
      switch (flowKey) {
        case 'posted':
          return current == 'POSTED';
        case 'assigned':
          return current == 'ASSIGNED';
        case 'en_route':
          return current == 'EN_ROUTE' || current.contains('EN ROUTE');
        case 'arrived':
          return current == 'ON_SITE' || current.contains('ON SITE');
        case 'in_progress':
          return current == 'IN_PROGRESS' || current.contains('IN PROGRESS');
        case 'completed':
          return current == 'COMPLETED';
        default:
          return false;
      }
    }

    String displayTime(String flowKey, String isoKey) {
      final t = timeFor(isoKey);
      if (t.isNotEmpty) return t;
      if (rowActive(flowKey)) return '—';
      return '—';
    }

    return [
      FleetTrackTimelineStepUi(flowKey: 'posted', label: 'Posted', time: displayTime('posted', 'postedAt'), done: rowDone('posted'), active: rowActive('posted')),
      FleetTrackTimelineStepUi(flowKey: 'assigned', label: 'Assigned', time: displayTime('assigned', 'assignedAt'), done: rowDone('assigned'), active: rowActive('assigned')),
      FleetTrackTimelineStepUi(flowKey: 'en_route', label: 'En Route', time: displayTime('en_route', 'enRouteAt'), done: rowDone('en_route'), active: rowActive('en_route')),
      FleetTrackTimelineStepUi(flowKey: 'arrived', label: 'Arrived', time: displayTime('arrived', 'onSiteAt'), done: rowDone('arrived'), active: rowActive('arrived')),
      FleetTrackTimelineStepUi(flowKey: 'in_progress', label: 'In Progress', time: displayTime('in_progress', 'inProgressAt'), done: rowDone('in_progress'), active: rowActive('in_progress')),
      FleetTrackTimelineStepUi(flowKey: 'completed', label: 'Completed', time: displayTime('completed', 'completedAt'), done: rowDone('completed'), active: rowActive('completed')),
    ];
  }

  static (String, String) _normalizePaymentStatus(String raw) {
    if (raw.contains('AUTH')) return ('authorised', 'Authorised');
    if (raw.contains('PAID')) return ('paid', 'Paid');
    if (raw.contains('REFUND')) return ('refunded', 'Refunded');
    if (raw.contains('RELEASE')) return ('released', 'Released');
    return ('authorised', raw.isEmpty ? 'Payment' : raw);
  }

  static Map<String, dynamic> _unwrapData(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return body;
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return const {};
  }

  static String _str(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    return v.toString().trim();
  }

  static double _money(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseIso(dynamic v) {
    if (v is! String || v.trim().isEmpty) return null;
    return DateTime.tryParse(v);
  }

  static String _formatCardLabel(String raw) {
    if (raw.isEmpty) return '';
    final t = raw.trim();
    if (t.toUpperCase() == 'MANUAL') return t;
    final lower = t.toLowerCase();
    final last4 = RegExp(r'(\d{4})\s*$').firstMatch(t)?.group(1);
    if (lower.contains('visa')) {
      return last4 != null ? 'VISA •••• $last4' : t;
    }
    if (lower.contains('master')) {
      return last4 != null ? 'Mastercard •••• $last4' : t;
    }
    return t;
  }
}

class FleetTrackTimelineStepUi {
  const FleetTrackTimelineStepUi({
    required this.flowKey,
    required this.label,
    required this.time,
    required this.done,
    required this.active,
  });

  final String flowKey;
  final String label;
  final String time;
  final bool done;
  final bool active;
}
