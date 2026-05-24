/// Parsed `GET /api/v1/jobs/:id` (or `data` envelope) for mechanic job tracker.
class MechanicWorkflowStepUi {
  const MechanicWorkflowStepUi({
    required this.key,
    required this.label,
    required this.done,
    required this.active,
  });

  final String key;
  final String label;
  final bool done;
  final bool active;
}

class MechanicJobDetailParsed {
  MechanicJobDetailParsed._(this.raw);

  final Map<String, dynamic> raw;

  static MechanicJobDetailParsed? tryParse(Map<String, dynamic> envelope) {
    final data = (envelope['data'] is Map<String, dynamic>)
        ? envelope['data'] as Map<String, dynamic>
        : envelope;
    final id = (data['_id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return null;
    return MechanicJobDetailParsed._(Map<String, dynamic>.from(data));
  }

  String get id => (raw['_id'] as String?)?.trim() ?? '';
  String get jobCode => (raw['jobCode'] as String?)?.trim() ?? '';
  String get title => (raw['title'] as String?)?.trim() ?? '';

  String get statusUpper => (raw['status'] as String?)?.trim().toUpperCase() ?? '';

  List<MechanicWorkflowStepUi> get workflowSteps {
    final w = raw['workflow'] as Map<String, dynamic>?;
    final list = (w?['steps'] as List<dynamic>?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => MechanicWorkflowStepUi(
            key: '${e['key'] ?? ''}'.trim(),
            label: '${e['label'] ?? e['key'] ?? ''}'.trim(),
            done: e['done'] == true,
            active: e['active'] == true,
          ),
        )
        .toList(growable: false);
  }

  /// Index into the 5-step UI (Journey → Done), driven by `workflow.steps`.
  int get uiStepIndex {
    final steps = workflowSteps;
    if (steps.isEmpty) return 0;
    for (var i = 0; i < steps.length; i++) {
      if (steps[i].active) return i.clamp(0, steps.length - 1);
    }
    for (var i = 0; i < steps.length; i++) {
      if (!steps[i].done) return i.clamp(0, steps.length - 1);
    }
    return steps.length - 1;
  }

  bool get showCompletedSummary {
    final s = statusUpper;
    return s == 'COMPLETED' || s == 'AWAITING_APPROVAL';
  }

  String get vehicleLine {
    final vehicle = raw['vehicle'] as Map<String, dynamic>?;
    if (vehicle != null) {
      final vType = (vehicle['type'] as String?)?.trim() ?? '';
      final vReg = (vehicle['registration'] as String?)?.trim() ?? '';
      final line = [vType, vReg].where((e) => e.isNotEmpty).join(' · ');
      if (line.isNotEmpty) return line;
    }
    return (raw['vehicleDisplay'] as String?)?.trim() ?? '—';
  }

  String get fleetName {
    final fleet = raw['fleet'] as Map<String, dynamic>?;
    return (fleet?['companyName'] as String?)?.trim() ?? '';
  }

  String get fleetPhone {
    final fleet = raw['fleet'] as Map<String, dynamic>?;
    return (fleet?['phone'] as String?)?.trim() ?? '';
  }

  String get headerSubtitle {
    final f = fleetName;
    if (f.isEmpty) return jobCode;
    return '$jobCode · $f';
  }

  /// GeoJSON Point: `[lng, lat]`
  ({double lng, double lat})? get mechanicLngLat {
    final loc = raw['mechanicLocation'] as Map<String, dynamic>?;
    final point = loc?['point'] as Map<String, dynamic>?;
    return _pointCoords(point);
  }

  ({double lng, double lat})? get jobOriginLngLat {
    final map = raw['map'] as Map<String, dynamic>?;
    final origin = map?['origin'] as Map<String, dynamic>?;
    return _pointCoords(origin);
  }

  /// Breakdown site / destination (`map.destination` GeoJSON Point + optional address).
  ({double lng, double lat})? get jobDestinationLngLat {
    final map = raw['map'] as Map<String, dynamic>?;
    final dest = map?['destination'];
    if (dest is Map<String, dynamic>) return _pointCoords(dest);
    return null;
  }

  /// Coordinates for map UI: breakdown/destination, then origin, then root `location`.
  ({double lng, double lat})? get mapBreakdownLngLat =>
      jobDestinationLngLat ?? jobOriginLngLat ?? _locationRootCoords;

  ({double lng, double lat})? get _locationRootCoords {
    final loc = raw['location'] as Map<String, dynamic>?;
    if (loc == null) return null;
    final c = loc['coordinates'];
    if (c is List && c.length >= 2) {
      final lng = (c[0] as num?)?.toDouble();
      final lat = (c[1] as num?)?.toDouble();
      if (lng != null && lat != null) return (lng: lng, lat: lat);
    }
    return null;
  }

  String get description => (raw['description'] as String?)?.trim() ?? '';

  /// Human-readable issue category (e.g. `FLAT_DAMAGED_TYRE` → words).
  String get issueTypeLabel {
    final t = (raw['issueType'] as String?)?.trim();
    if (t == null || t.isEmpty) return '—';
    return t.replaceAll('_', ' ');
  }

  /// Vehicle line for quote detail: `Make Model`, falling back to `type`.
  String get vehicleMakeModel {
    final vehicle = raw['vehicle'] as Map<String, dynamic>?;
    if (vehicle == null) return '—';
    final make = (vehicle['make'] as String?)?.trim() ?? '';
    final model = (vehicle['model'] as String?)?.trim() ?? '';
    final combined = '$make $model'.trim();
    if (combined.isNotEmpty) return combined;
    return (vehicle['type'] as String?)?.trim() ?? '—';
  }

  String get vehicleRegistration {
    final vehicle = raw['vehicle'] as Map<String, dynamic>?;
    return (vehicle?['registration'] as String?)?.trim() ?? '';
  }

  List<String> get photoUrls {
    final p = raw['photos'];
    if (p is! List<dynamic>) return const [];
    return p
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// Prefer `location.address`, then `map.destination.address`, else formatted coords.
  String get locationDisplayAddress {
    final loc = raw['location'] as Map<String, dynamic>?;
    final a = (loc?['address'] as String?)?.trim();
    if (a != null && a.isNotEmpty) return a;
    final map = raw['map'] as Map<String, dynamic>?;
    final dest = map?['destination'] as Map<String, dynamic>?;
    final da = (dest?['address'] as String?)?.trim();
    if (da != null && da.isNotEmpty) return da;
    final p = mapBreakdownLngLat;
    if (p != null) return '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}';
    return '—';
  }

  String get postedAgoText =>
      (raw['postedAgoLabel'] as String?)?.trim() ??
      ((raw['summary'] as Map<String, dynamic>?)?['postedAgoLabel'] as String?)?.trim() ??
      '';

  String get urgencyUpper => (raw['urgency'] as String?)?.trim().toUpperCase() ?? '';

  String get currencyCode => (raw['currency'] as String?)?.trim().toUpperCase() ?? 'GBP';

  String get currencySymbol => switch (currencyCode) {
        'GBP' => '£',
        'USD' => r'$',
        'EUR' => '€',
        _ => '$currencyCode ',
      };

  double? get estimatedPayout => (raw['estimatedPayout'] as num?)?.toDouble();

  /// UI hint under quote amount (±25% around `estimatedPayout`).
  String? get suggestedQuoteRangeLabel {
    final p = estimatedPayout;
    if (p == null || p <= 0) return null;
    final low = (p * 0.75).round();
    final high = (p * 1.25).round();
    return 'Suggested range: $currencySymbol$low – $currencySymbol$high';
  }

  /// Subtitle under map: distance from mechanic when API provides `summary.distanceMiles`.
  String? get distanceFromYouLine {
    final sum = raw['summary'] as Map<String, dynamic>?;
    final miles = sum?['distanceMiles'];
    if (miles is num && miles > 0) {
      return '${miles.toStringAsFixed(1)} mi from your location';
    }
    final km = sum?['distanceKm'];
    if (km is num && km > 0) {
      return '${km.toStringAsFixed(1)} km from your location';
    }
    return null;
  }

  bool get hasAcceptedQuote {
    final qc = raw['quoteContext'];
    if (qc is! Map<String, dynamic>) return false;
    return ((qc['status'] as String?) ?? '').toUpperCase() == 'ACCEPTED';
  }

  /// Whether the mechanic should be able to submit a **new** quote from this screen.
  bool get canSubmitNewQuote {
    final s = statusUpper;
    const blocked = {
      'AWAITING_APPROVAL',
      'COMPLETED',
      'CANCELLED',
      'CANCELLED_BY_FLEET',
      'CANCELLED_BY_MECHANIC',
    };
    if (blocked.contains(s)) return false;
    if (hasAcceptedQuote) return false;
    return true;
  }

  static ({double lng, double lat})? _pointCoords(Map<String, dynamic>? point) {
    final c = point?['coordinates'];
    if (c is List && c.length >= 2) {
      final lng = (c[0] as num?)?.toDouble();
      final lat = (c[1] as num?)?.toDouble();
      if (lng != null && lat != null) return (lng: lng, lat: lat);
    }
    return null;
  }

  double get labourRatePerHour =>
      (raw['labourRatePerHour'] as num?)?.toDouble() ??
      (raw['acceptedLabourRatePerHour'] as num?)?.toDouble() ??
      65.0;
}

Map<String, dynamic>? mechanicWorkCompleteData(Map<String, dynamic>? envelope) {
  if (envelope == null) return null;
  final d = envelope['data'];
  if (d is Map<String, dynamic>) return d;
  return envelope;
}

Map<String, dynamic>? mechanicJobSummaryFromComplete(Map<String, dynamic>? completeData) {
  final d = completeData;
  if (d == null) return null;
  final js = d['jobSummary'];
  return js is Map<String, dynamic> ? js : null;
}

/// Line items from `completionInvoice` after work complete, if present.
List<({String label, double amount})> mechanicCompletionLineAmounts(Map<String, dynamic>? completeData) {
  final d = completeData;
  if (d == null) return const [];
  final inv = d['completionInvoice'] as Map<String, dynamic>?;
  final items = (inv?['lineItems'] as List<dynamic>?) ?? const [];
  final out = <({String label, double amount})>[];
  for (final raw in items) {
    if (raw is! Map<String, dynamic>) continue;
    final label = (raw['label'] as String?)?.trim() ?? (raw['description'] as String?)?.trim() ?? '';
    final amt = (raw['totalAmount'] as num?)?.toDouble() ?? (raw['amount'] as num?)?.toDouble() ?? 0;
    if (label.isEmpty && amt == 0) continue;
    out.add((label: label.isEmpty ? 'Item' : label, amount: amt));
  }
  return out;
}

double mechanicCompletionSubtotal(Map<String, dynamic>? completeData) {
  final d = completeData;
  if (d == null) return 0;
  final inv = d['completionInvoice'] as Map<String, dynamic>?;
  final sub = (inv?['subtotal'] as num?)?.toDouble();
  if (sub != null && sub > 0) return sub;
  return mechanicCompletionLineAmounts(d).fold<double>(0, (s, e) => s + e.amount);
}
