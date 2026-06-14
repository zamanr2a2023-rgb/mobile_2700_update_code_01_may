import 'dart:math' as math;

/// Fleet operator row from `GET /api/v1/users/me` for the Profile tab.
class FleetMeProfileUi {
  FleetMeProfileUi({
    required this.email,
    required this.companyName,
    required this.regNumber,
    required this.vatNumber,
    required this.fleetSize,
    required this.contactName,
    required this.contactRole,
    required this.contactPhone,
    required this.cardDisplay,
    required this.expiryDisplay,
    required this.billingAddress,
    this.profileIsComplete = false,
    this.profileMissing = const [],
  });

  final String email;
  final String companyName;
  final String regNumber;
  final String vatNumber;
  final String fleetSize;
  final String contactName;
  final String contactRole;
  final String contactPhone;
  final String cardDisplay;
  final String expiryDisplay;
  final String billingAddress;
  final bool profileIsComplete;
  final List<String> profileMissing;

  String get headerTitle {
    final c = companyName.trim();
    if (c.isEmpty) return 'Fleet account';
    return c;
  }

  String get avatarInitials {
    final c = companyName.trim();
    if (c.isEmpty) {
      final e = email.trim();
      if (e.isNotEmpty) return e.substring(0, math.min(2, e.length)).toUpperCase();
      return '?';
    }
    final parts = c.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return c.substring(0, math.min(2, c.length)).toUpperCase();
  }

  static FleetMeProfileUi fromApiBody(Map<String, dynamic> body) {
    final root = _unwrapRoot(body);
    final fp = _asMap(root['fleetProfile'] ?? root['fleet_profile']);
    final pay = _asMap(root['paymentSummary'] ?? root['payment_summary']);

    final email = _str(root['email']);
    final companyName = _str(fp['companyName'] ?? fp['company_name']);
    final regNumber = _str(fp['regNumber'] ?? fp['reg_number']);
    final vatNumber = _str(fp['vatNumber'] ?? fp['vat_number']);
    var fleetSize = _str(fp['fleetSize'] ?? fp['fleet_size']);
    fleetSize = fleetSize.replaceAll('-', '–');

    final contactName = _str(fp['contactName'] ?? fp['contact_name']);
    final contactRole = _str(fp['contactRole'] ?? fp['contact_role']);
    final contactPhone = _str(fp['phone'] ?? fp['contactPhone'] ?? fp['contact_phone']);

    final cardLabel = _str(pay['cardLabel'] ?? pay['card_label']);
    final cardDisplay = _formatCardLabel(cardLabel);

    final expM = pay['expMonth'] ?? pay['exp_month'];
    final expY = pay['expYear'] ?? pay['exp_year'];
    final expiryDisplay = _formatExpiry(expM, expY);

    var bill = _str(pay['billingAddress'] ?? pay['billing_address']);
    if (bill.isEmpty) {
      bill = _str(fp['billingAddress'] ?? fp['billing_address']);
    }

    final completion = _asMap(root['profileCompletion'] ?? root['profile_completion']);
    final profileIsComplete = completion['isComplete'] == true;
    final missingRaw = completion['missing'];
    final profileMissing = missingRaw is List
        ? missingRaw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList()
        : const <String>[];

    return FleetMeProfileUi(
      email: email.isEmpty ? '—' : email,
      companyName: companyName.isEmpty ? '—' : companyName,
      regNumber: regNumber.isEmpty ? '—' : regNumber,
      vatNumber: vatNumber.isEmpty ? '—' : vatNumber,
      fleetSize: fleetSize.isEmpty ? '—' : fleetSize,
      contactName: contactName.isEmpty ? '—' : contactName,
      contactRole: contactRole.isEmpty ? '—' : contactRole,
      contactPhone: contactPhone.isEmpty ? '—' : contactPhone,
      cardDisplay: cardDisplay.isEmpty ? '—' : cardDisplay,
      expiryDisplay: expiryDisplay.isEmpty ? '—' : expiryDisplay,
      billingAddress: bill.isEmpty ? '—' : bill,
      profileIsComplete: profileIsComplete,
      profileMissing: profileMissing,
    );
  }

  static Map<String, dynamic> _unwrapRoot(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
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

  static String _formatCardLabel(String raw) {
    if (raw.isEmpty) return '';
    final t = raw.trim();
    if (t.toUpperCase() == 'MANUAL') return t;
    // e.g. "visa .... 4242" -> "VISA •••• 4242"
    final lower = t.toLowerCase();
    final last4 = RegExp(r'(\d{4})\s*$').firstMatch(t)?.group(1);
    if (lower.contains('visa')) {
      return last4 != null ? 'VISA •••• $last4' : _capitalize(t);
    }
    if (lower.contains('master')) {
      return last4 != null ? 'Mastercard •••• $last4' : _capitalize(t);
    }
    return _capitalize(t);
  }

  static String _capitalize(String t) {
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + (t.length > 1 ? t.substring(1) : '');
  }

  static String _formatExpiry(dynamic month, dynamic year) {
    final m = month is num ? month.toInt() : int.tryParse(month?.toString() ?? '');
    final y = year is num ? year.toInt() : int.tryParse(year?.toString() ?? '');
    if (m == null || y == null || m < 1 || m > 12) return '';
    final yy = y >= 100 ? y % 100 : y;
    return '${m.toString().padLeft(2, '0')} / ${yy.toString().padLeft(2, '0')}';
  }
}
