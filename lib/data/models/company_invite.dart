/// Mechanic-facing company invitation (`GET /api/v1/users/me/company-invites`).
class CompanyInvite {
  const CompanyInvite({
    required this.id,
    required this.email,
    required this.status,
    this.companyName,
    this.companyId,
    this.expiresAt,
    this.createdAt,
    this.role,
  });

  final String id;
  final String email;
  final String status;
  final String? companyName;
  final String? companyId;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String? role;

  bool get isPending {
    final s = status.trim().toUpperCase();
    return s.isEmpty || s == 'PENDING' || s == 'SENT';
  }

  bool get isExpiredByDate {
    final e = expiresAt;
    if (e == null) return false;
    return e.isBefore(DateTime.now());
  }

  bool get isExpired {
    final s = status.trim().toUpperCase();
    if (s == 'EXPIRED') return true;
    return isExpiredByDate && isPending;
  }

  String get statusLabel {
    if (isExpired) return 'Expired';
    final s = status.trim().toUpperCase();
    return switch (s) {
      'PENDING' || 'SENT' || '' => 'Pending',
      'ACCEPTED' => 'Accepted',
      'DECLINED' => 'Declined',
      'CANCELLED' || 'CANCELED' => 'Cancelled',
      'EXPIRED' => 'Expired',
      _ => status.trim().isEmpty ? 'Unknown' : status.trim(),
    };
  }

  factory CompanyInvite.fromJson(Map<String, dynamic> json) {
    final id = _pickString(json, ['_id', 'id', 'inviteId', 'invitationId']) ?? '';
    final company = _asMap(json['company'] ?? json['companyProfile'] ?? json['invitingCompany']);
    final companyName = _pickString(json, ['companyName', 'company_name', 'organisationName']) ??
        _pickString(company, ['name', 'companyName', 'displayName']);
    final companyId = _pickString(json, ['companyId', 'company_id']) ??
        _pickString(company, ['_id', 'id']);

    return CompanyInvite(
      id: id,
      email: _pickString(json, ['email']) ?? '',
      status: _pickString(json, ['status']) ?? 'PENDING',
      companyName: companyName,
      companyId: companyId,
      expiresAt: _parseDate(json['expiresAt'] ?? json['expires_at']),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      role: _pickString(json, ['role', 'invitedRole']),
    );
  }

  static List<CompanyInvite> listFromEnvelope(Map<String, dynamic> body) {
    final data = body['data'];
    final List<dynamic> raw;
    if (data is List) {
      raw = data;
    } else if (data is Map) {
      final nested = data['invites'] ?? data['invitations'] ?? data['items'] ?? data['results'];
      raw = nested is List ? nested : const [];
    } else {
      final root = body['invites'] ?? body['invitations'];
      raw = root is List ? root : const [];
    }

    final out = <CompanyInvite>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        final invite = CompanyInvite.fromJson(e);
        if (invite.id.isNotEmpty) out.add(invite);
      } else if (e is Map) {
        final invite = CompanyInvite.fromJson(Map<String, dynamic>.from(e));
        if (invite.id.isNotEmpty) out.add(invite);
      }
    }
    return out;
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return const {};
  }

  static String? _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v != null && v is! Map && v is! List) {
        final s = '$v'.trim();
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String && v.trim().isNotEmpty) return DateTime.tryParse(v.trim());
    if (v is int) {
      if (v > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v > 1000000000) return DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    return null;
  }
}

/// Result of company sending an invitation (`POST /company/team/invitations`).
class CompanyInviteSendResult {
  const CompanyInviteSendResult({
    required this.existingAccount,
    required this.emailSent,
    this.message,
    this.inviteToken,
    this.signupUrl,
    this.expiresAt,
    this.status,
    this.inviteId,
    this.email,
  });

  final bool existingAccount;
  final bool emailSent;
  final String? message;
  final String? inviteToken;
  final String? signupUrl;
  final DateTime? expiresAt;
  final String? status;
  final String? inviteId;
  final String? email;

  factory CompanyInviteSendResult.fromEnvelope(Map<String, dynamic> body) {
    final data = body['data'];
    final map = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : body;

    bool asBool(dynamic v) {
      if (v is bool) return v;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' || s == '1' || s == 'yes';
      }
      if (v is num) return v != 0;
      return false;
    }

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = map[k] ?? body[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    DateTime? expires;
    final rawExp = map['expiresAt'] ?? map['expires_at'] ?? body['expiresAt'];
    if (rawExp is String) expires = DateTime.tryParse(rawExp);
    if (rawExp is DateTime) expires = rawExp;

    return CompanyInviteSendResult(
      existingAccount: asBool(map['existingAccount'] ?? map['existing_account'] ?? body['existingAccount']),
      emailSent: asBool(map['emailSent'] ?? map['email_sent'] ?? body['emailSent'] ?? true),
      message: pick(['message', 'msg']) ??
          ((body['message'] is String) ? (body['message'] as String).trim() : null),
      inviteToken: pick(['inviteToken', 'invite_token', 'token']),
      signupUrl: pick(['signupUrl', 'signup_url', 'inviteUrl', 'invite_url', 'url']),
      expiresAt: expires,
      status: pick(['status']),
      inviteId: pick(['_id', 'id', 'inviteId', 'invitationId']),
      email: pick(['email']),
    );
  }
}

/// Public invite validation (`GET /api/v1/public/invites/validate`).
class PublicInviteValidation {
  const PublicInviteValidation({
    required this.valid,
    required this.existingAccount,
    this.email,
    this.companyName,
    this.status,
    this.expiresAt,
    this.message,
    this.inviteToken,
    this.role,
  });

  final bool valid;
  final bool existingAccount;
  final String? email;
  final String? companyName;
  final String? status;
  final DateTime? expiresAt;
  final String? message;
  final String? inviteToken;
  final String? role;

  factory PublicInviteValidation.fromEnvelope(Map<String, dynamic> body) {
    final data = body['data'];
    final map = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : body;

    bool asBool(dynamic v, {bool fallback = false}) {
      if (v is bool) return v;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' || s == '1' || s == 'yes';
      }
      if (v is num) return v != 0;
      return fallback;
    }

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = map[k] ?? body[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    final company = map['company'];
    String? companyName = pick(['companyName', 'company_name']);
    if (companyName == null && company is Map) {
      final n = company['name'] ?? company['companyName'];
      if (n is String && n.trim().isNotEmpty) companyName = n.trim();
    }

    final status = pick(['status']);
    final statusUpper = (status ?? '').toUpperCase();
    final explicitValid = map.containsKey('valid') || body.containsKey('valid');
    final valid = explicitValid
        ? asBool(map['valid'] ?? body['valid'])
        : statusUpper.isEmpty ||
            statusUpper == 'PENDING' ||
            statusUpper == 'SENT' ||
            statusUpper == 'VALID';

    DateTime? expires;
    final rawExp = map['expiresAt'] ?? map['expires_at'];
    if (rawExp is String) expires = DateTime.tryParse(rawExp);

    return PublicInviteValidation(
      valid: valid,
      existingAccount: asBool(map['existingAccount'] ?? map['existing_account'] ?? body['existingAccount']),
      email: pick(['email']),
      companyName: companyName,
      status: status,
      expiresAt: expires,
      message: pick(['message', 'msg']) ??
          ((body['message'] is String) ? (body['message'] as String).trim() : null),
      inviteToken: pick(['inviteToken', 'invite_token', 'token']),
      role: pick(['role']),
    );
  }
}
