// Parsed `GET /api/v1/fleet/vehicles/:id` — `data.vehicle` + `data.recentJobs` + `meta`.

import 'vehicle.dart';

String _str(dynamic v) => v == null ? '' : '$v'.trim();

String _formatJobDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return '';
  }
}

/// One row from `data.recentJobs[]`.
class FleetVehicleRecentJob {
  const FleetVehicleRecentJob({
    required this.id,
    required this.jobCode,
    required this.title,
    required this.statusLabel,
    required this.statusTone,
    required this.subtitleLine,
  });

  final String id;
  final String jobCode;
  final String title;
  final String statusLabel;
  /// API `statusUi.tone`: `green` | `amber` | `yellow` | `red` | …
  final String statusTone;
  /// e.g. `15 May 2026 · James Mitchell` or date-only.
  final String subtitleLine;

  static FleetVehicleRecentJob? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = _str(m['_id']);
    if (id.isEmpty) return null;
    final title = _str(m['title']);
    final jobCode = _str(m['jobCode']);
    final su = m['statusUi'] is Map<String, dynamic> ? m['statusUi'] as Map<String, dynamic> : null;
    final statusLabel = su != null ? _str(su['label']) : _str(m['status']);
    final statusTone = su != null ? _str(su['tone']) : '';

    final mechMap = m['assignedMechanic'] is Map<String, dynamic> ? m['assignedMechanic'] as Map<String, dynamic> : null;
    final fromNested = mechMap != null ? _str(mechMap['displayName']) : '';
    final mechanic = fromNested.isNotEmpty ? fromNested : _str(m['mechanicName']);

    final completed = _str(m['completedAt']);
    final posted = _str(m['postedAt']);
    final dateIso = completed.isNotEmpty ? completed : posted;
    final dateLabel = _formatJobDate(dateIso.isEmpty ? null : dateIso);
    String subtitle;
    if (dateLabel.isNotEmpty && mechanic.isNotEmpty) {
      subtitle = '$dateLabel · $mechanic';
    } else if (dateLabel.isNotEmpty) {
      subtitle = dateLabel;
    } else if (mechanic.isNotEmpty) {
      subtitle = mechanic;
    } else {
      subtitle = jobCode.isNotEmpty ? jobCode : '—';
    }

    return FleetVehicleRecentJob(
      id: id,
      jobCode: jobCode,
      title: title.isEmpty ? 'Job' : title,
      statusLabel: statusLabel.isEmpty ? '—' : statusLabel.toUpperCase(),
      statusTone: statusTone.isEmpty ? 'amber' : statusTone.toLowerCase(),
      subtitleLine: subtitle,
    );
  }
}

class FleetVehicleDetailPayload {
  const FleetVehicleDetailPayload({
    required this.vehicle,
    required this.recentJobs,
    this.recentJobsTotal,
    this.recentJobsLimit,
  });

  final Vehicle vehicle;
  final List<FleetVehicleRecentJob> recentJobs;
  final int? recentJobsTotal;
  final int? recentJobsLimit;

  static FleetVehicleDetailPayload? tryParse(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) return null;
    final vRaw = data['vehicle'];
    if (vRaw is! Map<String, dynamic>) return null;
    final vehicleMap = Map<String, dynamic>.from(vRaw);
    final vehicle = Vehicle.fromFleetVehicleJson(vehicleMap);

    final jobsRaw = data['recentJobs'];
    final jobs = <FleetVehicleRecentJob>[];
    if (jobsRaw is List<dynamic>) {
      for (final e in jobsRaw) {
        final row = FleetVehicleRecentJob.tryParse(e);
        if (row != null) jobs.add(row);
      }
    }

    final meta = envelope['meta'];
    int? total;
    int? limit;
    if (meta is Map<String, dynamic>) {
      final t = meta['recentJobsTotal'];
      final l = meta['recentJobsLimit'];
      if (t is num) total = t.toInt();
      if (l is num) limit = l.toInt();
    }

    return FleetVehicleDetailPayload(
      vehicle: vehicle,
      recentJobs: jobs,
      recentJobsTotal: total,
      recentJobsLimit: limit,
    );
  }
}
