/// Fleet vehicle shown in Profile → My Fleet and post-job picker.
///
/// Prefer [make]/[model] from [`GET /api/v1/fleet/vehicles`](…) when present; [label]
/// backs older flows and subtitles when API omits splits.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.label,
    required this.plate,
    this.type,
    this.categoryBadge,
    this.lastService,
    this.photoUrl,
    this.photoUrlSecondary,
    this.make,
    this.model,
    this.year,
    this.vin,
    this.currentMileageKm,
  });

  final String id;

  /// Make + model display line (subtitle on cards).
  final String label;
  final String plate;
  final String? type;

  /// Badge text (typically uppercase fleet type).
  final String? categoryBadge;

  /// List row footer (API maps `createdAt` until real last-service exists).
  final String? lastService;

  final String? photoUrl;
  final String? photoUrlSecondary;

  /// When set (fleet API), detail screen shows these instead of splitting [label].
  final String? make;
  final String? model;
  final int? year;
  final String? vin;

  /// From fleet vehicle APIs when present (`currentMileageKm`).
  final int? currentMileageKm;

  static String _formatShortDateUtc(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  static String? _trimOrNull(dynamic v) {
    if (v is! String) return null;
    final s = v.trim();
    return s.isEmpty ? null : s;
  }

  /// Parses `GET /api/v1/fleet/vehicles` envelope `data` (array of vehicle objects).
  static List<Vehicle> listFromFleetApiData(dynamic data, {bool activeOnly = true}) {
    if (data is! List) return const [];
    final out = <Vehicle>[];
    for (final e in data) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      if (activeOnly && m['isActive'] == false) continue;
      out.add(Vehicle.fromFleetVehicleJson(m));
    }
    out.sort((a, b) => a.plate.toLowerCase().compareTo(b.plate.toLowerCase()));
    return out;
  }

  /// One row from `GET /api/v1/fleet/vehicles` `data[]`.
  factory Vehicle.fromFleetVehicleJson(Map<String, dynamic> json) {
    final id = (_trimOrNull(json['_id'])) ?? '';
    final plate = (_trimOrNull(json['registration'])) ?? '';
    final make = _trimOrNull(json['make']);
    final model = _trimOrNull(json['model']);
    final type = _trimOrNull(json['type']);
    final vin = _trimOrNull(json['vin']);
    final year = json['year'] is num ? (json['year'] as num).toInt() : int.tryParse('${json['year']}');
    final kmRaw = json['currentMileageKm'];
    final int? currentMileageKm = kmRaw is num ? kmRaw.toInt() : int.tryParse('$kmRaw');

    final labelParts = <String>[
      if (make != null) make,
      if (model != null) model,
    ];
    var label = labelParts.join(' ').trim();
    if (label.isEmpty && type != null) {
      label = type;
    }
    if (label.isEmpty) {
      label = plate.isEmpty ? 'Vehicle' : plate;
    }

    final badge = type?.toUpperCase();
    final last = _formatShortDateUtc(_trimOrNull(json['createdAt']));

    return Vehicle(
      id: id.isNotEmpty ? id : 'veh-${plate.isEmpty ? 'unknown' : plate}',
      label: label,
      plate: plate.isEmpty ? '—' : plate,
      type: type,
      categoryBadge: badge,
      lastService: last.isEmpty ? null : last,
      make: make,
      model: model,
      year: year,
      vin: vin,
      currentMileageKm: currentMileageKm,
    );
  }
}
