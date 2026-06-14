import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/job_photo_bytes.dart';
import '../../../data/services/google_places_service.dart';
import '../../../data/services/jobs_api_service.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../../categories/job_categories.dart';
import '../viewmodel/fleet_viewmodel.dart';

/// Fleet Post Job — profile gate + full form (`PostJob` / `check.tsx`).
class FleetPostJobScreen extends StatefulWidget {
  const FleetPostJobScreen({
    super.key,
    required this.profileComplete,
    required this.prefilled,
    required this.onSubmit,
    required this.onContinueToJobForm,
  });

  final bool profileComplete;
  final String? prefilled;
  final VoidCallback onSubmit;

  /// Opens edit profile or unlocks the form when the backend profile is complete.
  final Future<void> Function() onContinueToJobForm;

  @override
  State<FleetPostJobScreen> createState() => _FleetPostJobScreenState();
}

enum _FleetJobMode { emergency, schedulable }

class _FleetPostJobScreenState extends State<FleetPostJobScreen> {
  static const Color _bg = Color(0xFF080808);
  static const Color _fieldFill = Color(0xFF111111);

  /// Labels stay bright; hints are deliberately softer so they read as placeholders.
  static const Color _fieldLabelColor = Color(0xFFE5E7EB);
  static const Color _fieldHintColor = Color(0xFF6B7280);
  static const Color _captionColor = Color(0xFF9CA3AF);
  static const double _fieldLabelSize = 12;
  static const double _fieldHintSize = 13;
  static const double _captionSize = 12;
  static const double _sectionTitleSize = 12;

  _FleetJobMode _jobMode = _FleetJobMode.emergency;

  // Payment pre-auth selector (UI only for now).
  static const double _preAuthMin = 50;
  static const double _preAuthMax = 450;
  static const double _preAuthStep = 10;
  double _preAuthAmount = 220;
  bool _submittingJob = false;

  final _vehicleReg = TextEditingController();
  final _vehicleMake = TextEditingController();
  final _trailerMake = TextEditingController();

  String? _jobCategoryLabel;
  String? _jobCategoryEmoji;
  bool _jobCategoryOpen = false;

  final _locationQuery = TextEditingController();
  final _locationFocus = FocusNode();
  String _selectedLocation = '';
  bool _locationFocused = false;

  final _tyreSize = TextEditingController();
  final _tyreAxle = TextEditingController();
  String _tyreSide = '';

  final _driverName = TextEditingController();
  final _driverNumber = TextEditingController();
  final _notes = TextEditingController();

  final _schedFromDate = TextEditingController();
  final _schedFromTime = TextEditingController();
  final _schedToDate = TextEditingController();
  final _schedToTime = TextEditingController();

  final GooglePlacesService _placesService = GooglePlacesService();
  Timer? _placesDebounce;
  List<PlaceAutocompleteResult> _placeSuggestions = [];
  bool _placesSearching = false;
  GoogleMapController? _mapController;
  LatLng? _breakdownLatLng;
  String _gpsSubtitle = 'Tap to use your GPS location';
  bool _locating = false;

  static const LatLng _defaultMapTarget = LatLng(-26.2041, 28.0473);
  static const int _maxJobPhotos = 5;

  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _jobPhotos = [];

  @override
  void initState() {
    super.initState();
    if (widget.prefilled != null && widget.prefilled!.isNotEmpty) {
      _vehicleMake.text = widget.prefilled!;
    }
    _locationFocus.addListener(() {
      setState(() => _locationFocused = _locationFocus.hasFocus);
    });
    _locationQuery.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _vehicleReg.dispose();
    _vehicleMake.dispose();
    _trailerMake.dispose();
    _locationQuery.dispose();
    _locationFocus.dispose();
    _tyreSize.dispose();
    _tyreAxle.dispose();
    _driverName.dispose();
    _driverNumber.dispose();
    _notes.dispose();
    _schedFromDate.dispose();
    _schedFromTime.dispose();
    _schedToDate.dispose();
    _schedToTime.dispose();
    _placesDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  bool get _isTyreJob => _jobCategoryLabel == 'Flat / Damaged Tyre';

  String _gbp(num v) => '£${v.toStringAsFixed(0)}';

  void _bumpPreAuth(int direction) {
    setState(() {
      final next = (_preAuthAmount + direction * _preAuthStep)
          .clamp(_preAuthMin, _preAuthMax);
      // Snap to step.
      _preAuthAmount = (next / _preAuthStep).round() * _preAuthStep;
    });
  }

  void _onLocationQueryChanged(String _) {
    if (_selectedLocation.isNotEmpty) {
      setState(() => _selectedLocation = '');
    }
    _placesDebounce?.cancel();
    final q = _locationQuery.text.trim();
    if (q.length < 2) {
      if (_placeSuggestions.isNotEmpty || _placesSearching) {
        setState(() {
          _placeSuggestions = [];
          _placesSearching = false;
        });
      }
      return;
    }
    _placesDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _placesSearching = true);
      try {
        final list = await _placesService.autocomplete(input: q);
        if (!mounted) return;
        setState(() {
          _placeSuggestions = list;
          _placesSearching = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _placeSuggestions = [];
          _placesSearching = false;
        });
        // Show the real reason (REQUEST_DENIED, API key restrictions, billing, etc.)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    });
  }

  Future<void> _selectGooglePlace(PlaceAutocompleteResult p) async {
    try {
      final details = await _placesService.placeDetails(placeId: p.placeId);
      if (!mounted) return;
      if (details == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load that place.')),
        );
        return;
      }
      final display = (details.formattedAddress ?? p.description).trim();
      _locationQuery.value = TextEditingValue(
        text: display,
        selection: TextSelection.collapsed(offset: display.length),
      );
      if (!mounted) return;
      setState(() {
        _breakdownLatLng = details.latLng;
        _selectedLocation = display;
        _placeSuggestions = [];
        _gpsSubtitle =
            'GPS · ${details.latLng.latitude.toStringAsFixed(4)}°, ${details.latLng.longitude.toStringAsFixed(4)}°';
      });
      _locationFocus.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mapController != null && _breakdownLatLng != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_breakdownLatLng!, 15),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool> _ensureLocationPermission() async {
    // Use Geolocator for the OS prompt: it talks to CLLocationManager / FusedLocationProvider
    // directly. (permission_handler on iOS requires PERMISSION_* macros in the Podfile; if those
    // are missing, location requests there can fail without showing the system sheet.)
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Location is turned off for this app. Open Settings to allow access.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return false;
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location permission is required to use GPS for this job.')),
        );
      }
      return false;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please turn on Location Services.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () async {
                await Geolocator.openLocationSettings();
              },
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _useMyCurrentLocation() async {
    if (_locating) return;
    final ok = await _ensureLocationPermission();
    if (!ok) return;
    setState(() => _locating = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      final addr = await _placesService.reverseGeocode(latLng);
      if (!mounted) return;
      final display = (addr ??
              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}')
          .trim();
      _locationQuery.value = TextEditingValue(
        text: display,
        selection: TextSelection.collapsed(offset: display.length),
      );
      if (!mounted) return;
      setState(() {
        _breakdownLatLng = latLng;
        _selectedLocation = display;
        _placeSuggestions = [];
        _gpsSubtitle =
            'GPS · ${pos.latitude.toStringAsFixed(4)}°, ${pos.longitude.toStringAsFixed(4)}°';
      });
      _locationFocus.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Widget _buildBreakdownMap() {
    final target = _breakdownLatLng ?? _defaultMapTarget;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 160,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: target,
            zoom: _breakdownLatLng != null ? 14 : 11,
          ),
          onMapCreated: (c) => _mapController = c,
          markers: {
            if (_breakdownLatLng != null)
              Marker(
                markerId: const MarkerId('breakdown'),
                position: _breakdownLatLng!,
              ),
          },
          // Avoid requiring runtime location permission just to render the map.
          // We request location only when user taps "Use my current location".
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
      ),
    );
  }

  String _tyreSideForApi(String id) {
    return switch (id) {
      'NS' => 'NEAR_SIDE',
      'OS' => 'OFF_SIDE',
      'BOTH' => 'BOTH',
      _ => id,
    };
  }

  Map<String, String> _buildJobFields() {
    final reg = _vehicleReg.text.trim();
    final title = _jobCategoryLabel?.trim().isNotEmpty == true
        ? '${_jobCategoryLabel!} — ${reg.isEmpty ? 'Truck' : reg}'
        : 'Breakdown — ${reg.isEmpty ? 'Truck' : reg}';

    // API `issueType` is a coarse enum; tyre jobs use TYRES + issueSubtype FLAT_DAMAGED_TYRE (see Postman).
    final issueType = JobCategories.apiIssueTypeForLabel(
      (_jobCategoryLabel?.trim().isNotEmpty == true)
          ? _jobCategoryLabel!.trim()
          : 'Breakdown (Unknown Issue)',
    );

    final mode =
        _jobMode == _FleetJobMode.emergency ? 'EMERGENCY' : 'SCHEDULABLE';
    final urgency = _jobMode == _FleetJobMode.emergency ? 'HIGH' : 'MEDIUM';

    final locationAddress = (_selectedLocation.isNotEmpty
            ? _selectedLocation
            : _locationQuery.text.trim())
        .trim();

    final lat = _breakdownLatLng?.latitude ?? _defaultMapTarget.latitude;
    final lng = _breakdownLatLng?.longitude ?? _defaultMapTarget.longitude;
    final locationJson = jsonEncode({
      'coordinates': [lng, lat],
      'address': locationAddress.isEmpty ? 'Unknown' : locationAddress,
    });

    final problemDescription = _notes.text.trim();

    final fields = <String, String>{
      'title': title,
      'description': problemDescription,
      'notes': problemDescription,
      'issueType': issueType,
      'mode': mode,
      'urgency': urgency,
      'registration': reg,
      'vehicleType': 'Truck',
      'vehicleMake': _vehicleMake.text.trim(),
      'vehicleModel': _vehicleMake.text.trim(),
      'trailerMakeModel': _trailerMake.text.trim(),
      'estimatedPayout': _preAuthAmount.toStringAsFixed(0),
      'location': locationJson,
      'driverName': _driverName.text.trim(),
      'driverPhone': _driverNumber.text.trim(),
    };

    if (_isTyreJob) {
      fields['issueSubtype'] = 'FLAT_DAMAGED_TYRE';
      final tyreMap = <String, dynamic>{
        'size': _tyreSize.text.trim(),
        'side': _tyreSide.isNotEmpty ? _tyreSideForApi(_tyreSide) : '',
        'axlePosition': _tyreAxle.text.trim(),
      };
      fields['tyreDetails'] = jsonEncode(tyreMap);
    }

    fields.removeWhere((_, v) => v.trim().isEmpty);

    final window = _buildAvailabilityWindowJson();
    if (window != null) fields['availabilityWindow'] = window;
    return fields;
  }

  DateTime? _parseLocalDateTime(String dateStr, String timeStr) {
    try {
      final partsD = dateStr.split('-').map((x) => int.parse(x)).toList();
      final partsT = timeStr.split(':').map((x) => int.parse(x)).toList();
      return DateTime(partsD[0], partsD[1], partsD[2], partsT[0], partsT[1]);
    } catch (_) {
      return null;
    }
  }

  /// Schedulable-only: user-facing validation before POST (matches backend rules).
  String? _schedulableAvailabilityError() {
    if (_jobMode != _FleetJobMode.schedulable) return null;
    final fd = _schedFromDate.text.trim();
    final ft = _schedFromTime.text.trim();
    if (fd.isEmpty || ft.isEmpty) {
      return 'Please choose when the truck is available (FROM date & time).';
    }
    final from = _parseLocalDateTime(fd, ft);
    if (from == null) return 'Invalid FROM date or time.';
    final td = _schedToDate.text.trim();
    final tt = _schedToTime.text.trim();
    if (td.isEmpty && tt.isEmpty) return null;
    if (td.isEmpty || tt.isEmpty) {
      return 'Set both TO date and time, or clear both for an open-ended window.';
    }
    final to = _parseLocalDateTime(td, tt);
    if (to == null) return 'Invalid TO date or time.';
    if (!to.isAfter(from)) {
      return 'End time must be after start time.';
    }
    return null;
  }

  String? _buildAvailabilityWindowJson() {
    if (_jobMode != _FleetJobMode.schedulable) return null;
    final fromDate = _schedFromDate.text.trim();
    final fromTime = _schedFromTime.text.trim();
    if (fromDate.isEmpty || fromTime.isEmpty) return null;

    final from = _parseLocalDateTime(fromDate, fromTime);
    if (from == null) return null;

    final toDate = _schedToDate.text.trim();
    final toTime = _schedToTime.text.trim();
    final parsedTo = (toDate.isNotEmpty && toTime.isNotEmpty)
        ? _parseLocalDateTime(toDate, toTime)
        : null;
    // API rejects equal times and any end before start ("to must be after from").
    final DateTime? to =
        (parsedTo != null && parsedTo.isAfter(from)) ? parsedTo : null;

    return jsonEncode({
      'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    });
  }

  bool get _needsRuntimeMediaPermission =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<bool> _ensureCameraPermission() async {
    if (!_needsRuntimeMediaPermission) return true;
    final status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (!mounted) return false;
    final msg = status.isPermanentlyDenied
        ? 'Camera is blocked. Enable it in app settings.'
        : 'Camera permission is needed to take photos.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    if (status.isPermanentlyDenied) await openAppSettings();
    return false;
  }

  Future<bool> _ensurePhotosPermission() async {
    if (!_needsRuntimeMediaPermission) return true;
    final perm = Platform.isAndroid ? Permission.storage : Permission.photos;

    final status = await perm.request();
    if (status.isGranted || status.isLimited) return true;

    // Android: if user previously denied with “Don't ask again”, request() returns denied
    // and rationale is false. In that case, take them to Settings.
    final shouldShow =
        Platform.isAndroid ? await perm.shouldShowRequestRationale : true;
    final blocked = status.isPermanentlyDenied ||
        status.isRestricted ||
        (Platform.isAndroid && !shouldShow);

    if (!mounted) return false;
    final msg = blocked
        ? 'Photo access is blocked. Enable it in app settings.'
        : 'Photo access is needed to attach images.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    if (blocked) await openAppSettings();
    return false;
  }

  Future<void> _pickFromCamera() async {
    if (_jobPhotos.length >= _maxJobPhotos) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can add up to $_maxJobPhotos photos.')),
      );
      return;
    }
    if (!await _ensureCameraPermission()) return;
    try {
      final x = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 960,
        maxHeight: 960,
        imageQuality: 70,
      );
      if (x != null && mounted) {
        setState(() => _jobPhotos.add(x));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _pickFromGallery() async {
    final remaining = _maxJobPhotos - _jobPhotos.length;
    if (remaining <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can add up to $_maxJobPhotos photos.')),
      );
      return;
    }
    if (!await _ensurePhotosPermission()) return;
    try {
      List<XFile> list;
      try {
        list = await _imagePicker.pickMultiImage(
          maxWidth: 960,
          maxHeight: 960,
          imageQuality: 70,
        );
      } on PlatformException {
        final single = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 960,
          maxHeight: 960,
          imageQuality: 70,
        );
        list = single != null ? <XFile>[single] : <XFile>[];
      }
      if (list.isEmpty || !mounted) return;
      setState(() {
        for (final x in list) {
          if (_jobPhotos.length >= _maxJobPhotos) break;
          _jobPhotos.add(x);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _removeJobPhoto(int index) {
    setState(() => _jobPhotos.removeAt(index));
  }

  /// Flat tyre jobs must send tyreDetails (validated before submit).
  String? _tyreJobValidationError() {
    if (!_isTyreJob) return null;
    if (_tyreSize.text.trim().isEmpty) {
      return 'Please enter tyre size (e.g. 295/80 R22.5).';
    }
    if (_tyreSide.isEmpty) {
      return 'Please select tyre side (Near side / Off side / Both).';
    }
    if (_tyreAxle.text.trim().isEmpty) {
      return 'Please enter axle position (e.g. Drive 1, Steer).';
    }
    return null;
  }

  static const String _bankCardRequiredMessage =
      'Please add a bank card to be able to create a job.';

  Future<void> _submitJob() async {
    if (_submittingJob) return;
    if (_jobCategoryLabel == null || _jobCategoryLabel!.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a job category.')),
      );
      return;
    }
    final tyreErr = _tyreJobValidationError();
    if (tyreErr != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tyreErr)));
      return;
    }
    final schedErr = _schedulableAvailabilityError();
    if (schedErr != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(schedErr)));
      return;
    }
    if (_notes.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please describe the problem in Notes before posting your job.'),
        ),
      );
      return;
    }
    final fleetVm = context.read<FleetViewModel>();
    final auth = context.read<AuthViewModel>();
    await fleetVm.tryUnlockPostJobFormFromGate();
    if (!mounted) return;
    if (!fleetVm.profileComplete) {
      final reason = fleetVm.postJobProfileBlockReason ??
          'Complete your profile and add a payment card under Profile → Edit Profile.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
      fleetVm.openFleetEditProfile(fromPostJobGate: true);
      return;
    }
    await fleetVm.loadBillingPaymentMethods(silent: true);
    if (!mounted) return;
    if (fleetVm.billingPaymentMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_bankCardRequiredMessage)),
      );
      fleetVm.openFleetEditProfile(fromPostJobGate: true);
      return;
    }
    setState(() => _submittingJob = true);
    try {
      final token = auth.session?.accessToken;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Missing access token. Please login again.');
      }

      final photoParts = <http.MultipartFile>[];
      const maxPhotoBytes = 750 * 1024;
      for (var i = 0; i < _jobPhotos.length; i++) {
        final x = _jobPhotos[i];
        var bytes = await prepareJobPhotoBytesForUpload(await x.readAsBytes());
        if (bytes.length > maxPhotoBytes) {
          throw Exception(
            'Photo "${x.name}" is still too large after compression. Remove it or use a smaller image.',
          );
        }
        photoParts.add(
          buildJobPhotoMultipartPart(
            bytes: bytes,
            originalName: x.name.replaceAll(RegExp(r'\.[^.]+$'), '.jpg'),
            index: i,
          ),
        );
      }

      await JobsApiService().createJob(
        accessToken: token,
        fields: _buildJobFields(),
        photos: photoParts,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job posted successfully')),
      );
      widget.onSubmit();
    } catch (e) {
      if (!mounted) return;
      final msg = e is JobsApiException
          ? e.message
          : JobsApiException.userMessage(
              e.toString().replaceFirst('Exception: ', ''));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _submittingJob = false);
    }
  }

  bool get _showLocationDropdown =>
      _locationFocused && _selectedLocation.isEmpty;

  InputDecoration _dec({String? hint, Widget? prefix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: _fieldHintColor,
        fontSize: _fieldHintSize,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefix,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border2)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border2)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: AppColors.primary.withValues(alpha: 0.55)),
      ),
    );
  }

  Widget _smallFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: _fieldLabelColor,
          fontSize: _fieldLabelSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: _sectionTitleSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _requiredSectionRow(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.red.withValues(alpha: 0.60), width: 2),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style:
                    TextStyle(color: _captionColor, fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIncompleteProfileBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Post Job',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2),
              ),
              const SizedBox(height: 4),
              Text(
                'Get mechanics responding in minutes',
                style: TextStyle(color: _captionColor, fontSize: 12),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.primary.withValues(alpha: 0.10),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.30)),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Text(
                      '!',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Continue to your job',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2),
                ),
                const SizedBox(height: 10),
                Text(
                  'Before you can post a job, complete company details, contact info, billing address, and save a payment card in Profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _captionColor, fontSize: 12, height: 1.45),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: const Text(
                          'REQUIRED BEFORE POSTING',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Column(
                          children: [
                            _requiredSectionRow('Company Details',
                                'Company name, Reg number, VAT number'),
                            const Divider(height: 20, color: AppColors.border),
                            _requiredSectionRow(
                                'Contact Person', 'Name, role, phone, email'),
                            const Divider(height: 20, color: AppColors.border),
                            _requiredSectionRow('Billing & Payment',
                                'Billing address + saved card (Profile → Edit Profile)'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onContinueToJobForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'COMPLETE PROFILE',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.8),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.black, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Opens the job form on this tab. Use Profile to add or edit fleet & payment details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _captionColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _jobModeCard({
    required _FleetJobMode mode,
    required String emoji,
    required String title,
    required String subtitle,
    required bool emergencyStyle,
  }) {
    final on = _jobMode == mode;
    final borderColor = on
        ? (emergencyStyle ? AppColors.red : AppColors.primary)
        : const Color(0xFF1E1E1E);
    final bg = on
        ? (emergencyStyle
            ? AppColors.red.withValues(alpha: 0.10)
            : AppColors.primary.withValues(alpha: 0.10))
        : const Color(0xFF0F0F0F);
    final titleColor = on
        ? (emergencyStyle ? AppColors.red : AppColors.primary)
        : AppColors.textSecondary;
    final subColor = on
        ? (emergencyStyle
            ? AppColors.red.withValues(alpha: 0.70)
            : AppColors.primary.withValues(alpha: 0.70))
        : AppColors.textSecondary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _jobMode = mode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: on ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                    color: titleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: subColor, fontSize: 9, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(
      BuildContext context, void Function(String) onPick) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
              primary: AppColors.primary, surface: _fieldFill),
        ),
        child: child!,
      ),
    );
    if (d != null) {
      onPick(
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _pickTime(
      BuildContext context, void Function(String) onPick) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
              primary: AppColors.primary, surface: _fieldFill),
        ),
        child: child!,
      ),
    );
    if (t != null) {
      onPick(
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    }
  }

  Widget _schedulableWindow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'TRUCK AVAILABLE WINDOW',
            style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          Text('FROM',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  readOnly: true,
                  onTap: () => _pickDate(
                      context, (s) => setState(() => _schedFromDate.text = s)),
                  controller: _schedFromDate,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: _dec(hint: 'Date').copyWith(
                    prefixIcon: const Icon(Icons.calendar_today_outlined,
                        color: AppColors.textMuted, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  readOnly: true,
                  onTap: () => _pickTime(
                      context, (s) => setState(() => _schedFromTime.text = s)),
                  controller: _schedFromTime,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: _dec(hint: 'Time').copyWith(
                    prefixIcon: const Icon(Icons.schedule_rounded,
                        color: AppColors.textMuted, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'TO',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1),
              ),
              const SizedBox(width: 6),
              Text(
                '(optional)',
                style: TextStyle(color: _captionColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  readOnly: true,
                  onTap: () => _pickDate(
                      context, (s) => setState(() => _schedToDate.text = s)),
                  controller: _schedToDate,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: _dec(hint: 'Date').copyWith(
                    prefixIcon: const Icon(Icons.calendar_today_outlined,
                        color: AppColors.textMuted, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  readOnly: true,
                  onTap: () => _pickTime(
                      context, (s) => setState(() => _schedToTime.text = s)),
                  controller: _schedToTime,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: _dec(hint: 'Time').copyWith(
                    prefixIcon: const Icon(Icons.schedule_rounded,
                        color: AppColors.textMuted, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'If you set an end time, it must be after the start. Leave date/time empty for open-ended.',
            style: TextStyle(
              color: _captionColor,
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobFormBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Post Job',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2),
              ),
              const SizedBox(height: 4),
              const Text(
                'Fill in details to find a mechanic fast',
                style:
                    TextStyle(color: _captionColor, fontSize: 13, height: 1.35),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle('Job Mode'),
                Row(
                  children: [
                    Expanded(
                      child: _jobModeCard(
                        mode: _FleetJobMode.emergency,
                        emoji: '🚨',
                        title: 'Emergency',
                        subtitle: 'Dispatch now',
                        emergencyStyle: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _jobModeCard(
                        mode: _FleetJobMode.schedulable,
                        emoji: '📅',
                        title: 'Schedulable',
                        subtitle: 'Pick date & time',
                        emergencyStyle: false,
                      ),
                    ),
                  ],
                ),
                if (_jobMode == _FleetJobMode.schedulable) ...[
                  const SizedBox(height: 10),
                  _schedulableWindow(),
                ],
                const SizedBox(height: 20),
                _sectionTitle('Vehicle Details'),
                _smallFieldLabel('Registration'),
                TextField(
                  controller: _vehicleReg,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textCapitalization: TextCapitalization.characters,
                  decoration: _dec(hint: 'e.g. CA 456-789'),
                ),
                const SizedBox(height: 12),
                _smallFieldLabel('Vehicle Make & Model'),
                TextField(
                  controller: _vehicleMake,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration:
                      _dec(hint: 'e.g. Mercedes Actros 2645, Volvo FH16…'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _smallFieldLabel('Trailer Make & Model')),
                    Text(
                      'Optional',
                      style: TextStyle(color: _captionColor, fontSize: 12),
                    ),
                  ],
                ),
                TextField(
                  controller: _trailerMake,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration:
                      _dec(hint: 'e.g. Henred Fruehauf, SA Truck Bodies…'),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Job Category'),
                Material(
                  color: _fieldFill,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () =>
                        setState(() => _jobCategoryOpen = !_jobCategoryOpen),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _jobCategoryOpen
                              ? AppColors.primary.withValues(alpha: 0.55)
                              : AppColors.border2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _jobCategoryLabel == null
                                  ? 'Select job category…'
                                  : '${_jobCategoryEmoji ?? ''}  $_jobCategoryLabel',
                              style: TextStyle(
                                color: _jobCategoryLabel == null
                                    ? _fieldHintColor
                                    : Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          AnimatedRotation(
                            turns: _jobCategoryOpen ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(Icons.expand_more_rounded,
                                color: AppColors.textMuted, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_jobCategoryOpen) ...[
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: _fieldFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0;
                            i < JobCategories.postJobCategories.length;
                            i++)
                          InkWell(
                            onTap: () {
                              final t = JobCategories.postJobCategories[i];
                              setState(() {
                                _jobCategoryLabel = t.$2;
                                _jobCategoryEmoji = t.$1;
                                _jobCategoryOpen = false;
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: i ==
                                      JobCategories.postJobCategories.length - 1
                                  ? null
                                  : const BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(
                                              color: Color(0xFF1A1A1A))),
                                    ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                        JobCategories.postJobCategories[i].$1,
                                        style: const TextStyle(fontSize: 16)),
                                  ),
                                  Expanded(
                                    child: Text(
                                      JobCategories.postJobCategories[i].$2,
                                      style: TextStyle(
                                        color: _jobCategoryLabel ==
                                                JobCategories
                                                    .postJobCategories[i].$2
                                            ? AppColors.primary
                                            : AppColors.textMuted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (_jobCategoryLabel ==
                                      JobCategories.postJobCategories[i].$2)
                                    const Icon(Icons.check_rounded,
                                        color: AppColors.primary, size: 18),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (_isTyreJob) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.20)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '🛞 TYRE DETAILS',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1),
                        ),
                        const SizedBox(height: 12),
                        _smallFieldLabel('Tyre Size'),
                        TextField(
                          controller: _tyreSize,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration:
                              _dec(hint: 'e.g. 295/80 R22.5, 315/70 R22.5…'),
                        ),
                        const SizedBox(height: 12),
                        _smallFieldLabel('Side'),
                        Row(
                          children: [
                            Expanded(
                                child: _tyreSideChip(
                                    'NS', 'Near Side', 'Left / Kerb')),
                            const SizedBox(width: 6),
                            Expanded(
                                child: _tyreSideChip(
                                    'OS', 'Off Side', 'Right / Road')),
                            const SizedBox(width: 6),
                            Expanded(
                                child:
                                    _tyreSideChip('BOTH', 'Both', 'NS & OS')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _smallFieldLabel('Axle Position'),
                        TextField(
                          controller: _tyreAxle,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: _dec(
                              hint:
                                  'e.g. Steer, Drive 1, Drive 2, Tag, Trailer 1…'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Type the axle — e.g. "Drive 1", "Steer", "Trailer 2"',
                          style: TextStyle(color: _captionColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _sectionTitle('Breakdown Location'),
                TextField(
                  controller: _locationQuery,
                  focusNode: _locationFocus,
                  onChanged: _onLocationQueryChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _dec(hint: 'Type a street, highway or landmark…')
                      .copyWith(
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textMuted, size: 20),
                    suffixIcon: _locationQuery.text.isNotEmpty
                        ? IconButton(
                            icon:
                                Icon(Icons.close_rounded, color: _captionColor),
                            onPressed: () {
                              setState(() {
                                _locationQuery.clear();
                                _selectedLocation = '';
                                _placeSuggestions = [];
                              });
                            },
                          )
                        : null,
                  ),
                ),
                if (_showLocationDropdown) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: _fieldFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Builder(
                      builder: (context) {
                        final q = _locationQuery.text.trim();
                        if (q.length < 2) {
                          return Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              'Keep typing — suggestions come from Google Maps',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12),
                            ),
                          );
                        }
                        if (_placesSearching) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        if (_placeSuggestions.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              'No Google Places results — try another search',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12),
                            ),
                          );
                        }
                        return ListView(
                          shrinkWrap: true,
                          children: _placeSuggestions
                              .map(
                                (p) => InkWell(
                                  onTap: () => _selectGooglePlace(p),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(
                                              color: Color(0xFF1A1A1A))),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.place_outlined,
                                            size: 16,
                                            color: AppColors.textMuted),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            p.description,
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Material(
                  color: const Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _locating ? null : _useMyCurrentLocation,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E1E1E)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.20)),
                            ),
                            child: const Icon(Icons.my_location_rounded,
                                color: AppColors.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Use my current location',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _locating
                                      ? 'Getting location…'
                                      : _gpsSubtitle,
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildBreakdownMap(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _sectionTitle('Driver Details')),
                    Text(
                      'Optional',
                      style: TextStyle(color: _captionColor, fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _driverName,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _dec(hint: 'Driver name').copyWith(
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: AppColors.textMuted, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _driverNumber,
                        keyboardType: TextInputType.phone,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _dec(hint: '+27 82 000 0000').copyWith(
                          prefixIcon: const Icon(Icons.phone_outlined,
                              color: AppColors.textMuted, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _sectionTitle('Photos')),
                    Text(
                      'Optional · up to 5',
                      style: TextStyle(color: _captionColor, fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFromCamera,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          side: const BorderSide(color: Color(0xFF1E1E1E)),
                          backgroundColor: const Color(0xFF0F0F0F),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.photo_camera_outlined,
                            color: AppColors.primary, size: 18),
                        label: const Text('Camera',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFromGallery,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          side: const BorderSide(color: Color(0xFF1E1E1E)),
                          backgroundColor: const Color(0xFF0F0F0F),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.image_outlined,
                            color: AppColors.primary, size: 18),
                        label: const Text('Gallery',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E1E1E)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _jobPhotos.isEmpty
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_outlined,
                                color: _captionColor, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'No photos added yet',
                              style:
                                  TextStyle(color: _captionColor, fontSize: 11),
                            ),
                          ],
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          itemCount: _jobPhotos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: FutureBuilder<Uint8List>(
                                    future: _jobPhotos[i].readAsBytes(),
                                    builder: (context, snap) {
                                      if (!snap.hasData) {
                                        return Container(
                                          width: 68,
                                          height: 68,
                                          color: const Color(0xFF1A1A1A),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            ),
                                          ),
                                        );
                                      }
                                      return Image.memory(
                                        snap.data!,
                                        width: 68,
                                        height: 68,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Material(
                                    color: Colors.black87,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      onTap: () => _removeJobPhoto(i),
                                      customBorder: const CircleBorder(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.close,
                                            size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                Text(
                  'Helps mechanics diagnose before arriving on site',
                  style: TextStyle(color: _captionColor, fontSize: 12),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Notes (required)'),
                TextField(
                  controller: _notes,
                  maxLines: 4,
                  maxLength: 500,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _dec(
                    hint:
                        'Describe the problem in detail — symptoms, warning lights, sounds, what happened before breakdown…',
                  ),
                  buildCounter: (context,
                      {required currentLength, required isFocused, maxLength}) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '$currentLength / ${maxLength ?? 500}',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: _captionColor, fontSize: 12),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Payment Pre-Auth',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            onPressed: _preAuthAmount <= _preAuthMin
                                ? null
                                : () => _bumpPreAuth(-1),
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 20),
                            color: AppColors.textMuted,
                          ),
                          Text(
                            _gbp(_preAuthAmount),
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w900),
                          ),
                          IconButton(
                            onPressed: _preAuthAmount >= _preAuthMax
                                ? null
                                : () => _bumpPreAuth(1),
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.keyboard_arrow_up_rounded,
                                size: 20),
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: const Color(0xFF1A1A1A),
                          thumbColor: AppColors.primary,
                          overlayColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                        ),
                        child: Slider(
                          value: _preAuthAmount,
                          min: _preAuthMin,
                          max: _preAuthMax,
                          divisions:
                              ((_preAuthMax - _preAuthMin) / _preAuthStep)
                                  .round(),
                          onChanged: (v) => setState(() {
                            _preAuthAmount =
                                (v / _preAuthStep).round() * _preAuthStep;
                          }),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_gbp(_preAuthMin),
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                          Text(_gbp(_preAuthMax),
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          final cardLabel =
                              context.watch<FleetViewModel>().defaultPaymentCardLabel;
                          return Row(
                            children: [
                              Icon(Icons.credit_card_rounded,
                                  size: 16, color: AppColors.textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  cardLabel,
                                  style: TextStyle(
                                      color: AppColors.textMuted
                                          .withValues(alpha: 0.95),
                                      fontSize: 11),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _submittingJob ? null : _submitJob,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _jobMode == _FleetJobMode.emergency ? '🚨' : '📅',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _submittingJob
                          ? 'POSTING…'
                          : (_jobMode == _FleetJobMode.emergency
                              ? 'POST EMERGENCY JOB'
                              : 'SCHEDULE JOB'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _jobMode == _FleetJobMode.emergency
                    ? 'Mechanics will respond within minutes. Your job is now live.'
                    : 'Mechanics will be notified and can quote on your scheduled window.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _captionColor, fontSize: _captionSize, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tyreSideChip(String id, String title, String sub) {
    final on = _tyreSide == id;
    return Material(
      color: on ? AppColors.primary.withValues(alpha: 0.10) : _fieldFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _tyreSide = id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: on ? AppColors.primary : AppColors.border2),
          ),
          child: Column(
            children: [
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: on ? AppColors.primary : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: on
                        ? AppColors.primary.withValues(alpha: 0.75)
                        : AppColors.textSecondary,
                    fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: widget.profileComplete
          ? _buildJobFormBody(context)
          : _buildIncompleteProfileBody(),
    );
  }
}
