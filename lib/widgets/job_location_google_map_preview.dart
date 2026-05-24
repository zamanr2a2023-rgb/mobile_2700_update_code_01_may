import 'dart:math' as math;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme/app_colors.dart';

/// Embedded Google Map for job breakdown location (mechanic quote detail, etc.).
class JobLocationGoogleMapPreview extends StatelessWidget {
  const JobLocationGoogleMapPreview({
    super.key,
    required this.lat,
    required this.lng,
    this.height = 130,
    this.mechanicLat,
    this.mechanicLng,
  });

  final double lat;
  final double lng;
  final double height;

  /// Optional second marker + dashed-style polyline when both mechanic and job coords exist.
  final double? mechanicLat;
  final double? mechanicLng;

  static Set<Factory<OneSequenceGestureRecognizer>> _mapGestures() => <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      };

  @override
  Widget build(BuildContext context) {
    final job = LatLng(lat, lng);
    final mech = (mechanicLat != null && mechanicLng != null) ? LatLng(mechanicLat!, mechanicLng!) : null;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('breakdown'),
        position: job,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
      if (mech != null)
        Marker(
          markerId: const MarkerId('mechanic'),
          position: mech,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        ),
    };

    final polylines = <Polyline>{
      if (mech != null)
        Polyline(
          polylineId: const PolylineId('hint'),
          color: AppColors.primary.withValues(alpha: 0.85),
          width: 3,
          points: [mech, job],
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: job, zoom: mech != null ? 11 : 14),
          markers: markers,
          polylines: polylines,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          gestureRecognizers: _mapGestures(),
          onMapCreated: (c) async {
            if (mech == null) return;
            final minLat = math.min(job.latitude, mech.latitude);
            final maxLat = math.max(job.latitude, mech.latitude);
            final minLng = math.min(job.longitude, mech.longitude);
            final maxLng = math.max(job.longitude, mech.longitude);
            if ((maxLat - minLat).abs() < 1e-6 && (maxLng - minLng).abs() < 1e-6) {
              await c.animateCamera(CameraUpdate.newLatLngZoom(job, 14));
              return;
            }
            try {
              await c.moveCamera(
                CameraUpdate.newLatLngBounds(
                  LatLngBounds(
                    southwest: LatLng(minLat, minLng),
                    northeast: LatLng(maxLat, maxLng),
                  ),
                  44,
                ),
              );
            } catch (_) {
              if (context.mounted) {
                await c.animateCamera(CameraUpdate.newLatLngZoom(job, 12));
              }
            }
          },
        ),
      ),
    );
  }
}
