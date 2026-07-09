import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../models/forgot_password_result.dart';
import '../models/session.dart';
import '../services/users_api_service.dart';
import 'app_repository.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? ApiConstants.baseUrl)
            .trim()
            .replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  Session? _session;
  static const _kSessionKey = 'truckfix.session.v1';

  @override
  Future<void> clearSession() async {
    _session = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);
  }

  @override
  Future<Session?> getSession() async {
    if (_session != null) return _session;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSessionKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final role = _parseRole(decoded['role']) ?? UserRole.fleet;
      final email = (decoded['email'] as String?) ?? '';
      if (email.trim().isEmpty) return null;
      final session = Session(
        email: email,
        role: role,
        displayName: decoded['displayName'] as String?,
        accessToken: decoded['accessToken'] as String?,
        refreshToken: decoded['refreshToken'] as String?,
      );
      _session = session;
      return session;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSession(Session session) async {
    _session = session;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kSessionKey,
      jsonEncode({
        'email': session.email,
        'role': session.role.name,
        'displayName': session.displayName,
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
      }),
    );
  }

  static UserRole? _parseRole(dynamic value) {
    final raw = (value is String) ? value.toLowerCase().trim() : null;
    return switch (raw) {
      'fleet' => UserRole.fleet,
      'mechanic' => UserRole.mechanic,
      'company' => UserRole.company,
      'employee' => UserRole.employee,
      // Backend: company-invited workshop mechanic (`POST /auth/register` with role MECHANIC_EMPLOYEE).
      'mechanic_employee' => UserRole.employee,
      _ => null,
    };
  }

  static String? _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  static Map<String, dynamic> _pickObject(
      Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is Map<String, dynamic>) return v;
    }
    return const {};
  }

  @override
  Future<Session> login({
    required String email,
    required String password,
    required UserRole roleHint,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.authLoginPath}');
    final res = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(res.body);
      body = (decoded is Map<String, dynamic>) ? decoded : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = _pickString(body, ['message', 'error', 'msg']) ??
          'Login failed (HTTP ${res.statusCode}).';
      throw AuthException(msg);
    }

    // Support common API shapes:
    // - { token: "...", user: { email, role, name } }
    // - { data: { token, user: {...} } }
    // - { accessToken: "...", role: "fleet", email: "..." }
    final session = _sessionFromAuthBody(
      body,
      fallbackEmail: email,
      roleHint: roleHint,
    );

    await saveSession(session);
    return session;
  }

  Session _sessionFromAuthBody(
    Map<String, dynamic> body, {
    required String fallbackEmail,
    required UserRole roleHint,
  }) {
    final data = _pickObject(body, ['data', 'result', 'payload', 'response']);
    final rootOrData = data.isNotEmpty ? data : body;
    final user = _pickObject(rootOrData, ['user', 'account', 'profile']);
    final mechanicProfile = _pickObject(user, ['mechanicProfile', 'mechanic_profile']);
    final fleetProfile = _pickObject(user, ['fleetProfile', 'fleet_profile']);
    final companyProfile = _pickObject(user, ['companyProfile', 'company_profile']);
    final employeeProfile = _pickObject(user, ['employeeProfile', 'employee_profile']);

    final accessToken = _pickString(
        rootOrData, ['accessToken', 'token', 'access_token', 'jwt']);
    final refreshToken = _pickString(rootOrData, ['refreshToken', 'refresh_token']) ??
        _pickString(body, ['refreshToken', 'refresh_token']);
    final role = _parseRole(rootOrData['role']) ??
        _parseRole(user['role']) ??
        _parseRole(mechanicProfile['role']) ??
        _parseRole(fleetProfile['role']) ??
        _parseRole(companyProfile['role']) ??
        _parseRole(employeeProfile['role']) ??
        roleHint;
    final resolvedEmail = _pickString(rootOrData, ['email']) ??
        _pickString(user, ['email']) ??
        fallbackEmail;
    final name = _pickString(rootOrData, ['name', 'displayName']) ??
        _pickString(user, ['name', 'displayName']) ??
        _pickString(fleetProfile, ['contactName', 'contact_name', 'companyName', 'company_name']) ??
        _pickString(mechanicProfile, ['displayName', 'display_name', 'fullName', 'full_name']);

    return Session(
      email: resolvedEmail,
      role: role,
      displayName: name ?? resolvedEmail.split('@').first,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  @override
  Future<void> deleteAccount({
    required String accessToken,
    required String password,
  }) async {
    await UsersApiService(baseUrl: _baseUrl, client: _client).deleteMe(
      accessToken: accessToken,
      password: password,
    );
    await clearSession();
  }

  @override
  Future<void> logout({String? accessToken, String? refreshToken}) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.authLogoutPath}');
    try {
      final bearer = accessToken?.trim();
      final rt = refreshToken?.trim();
      if (bearer != null && bearer.isNotEmpty) {
        final body = <String, dynamic>{};
        if (rt != null && rt.isNotEmpty) {
          body['refreshToken'] = rt;
        }
        await _client.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $bearer',
          },
          body: jsonEncode(body),
        );
      } else if (rt != null && rt.isNotEmpty) {
        await _client.post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'refreshToken': rt}),
        );
      }
    } catch (_) {
      // Best-effort; still clear locally below.
    } finally {
      await clearSession();
    }
  }

  @override
  Future<ForgotPasswordResult> forgotPassword({required String email}) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.authForgotPasswordPath}');
    final res = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email.trim()}),
    );

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(res.body);
      body = (decoded is Map<String, dynamic>) ? decoded : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = _pickString(body, ['message', 'error', 'msg']) ??
          'Could not send reset email (HTTP ${res.statusCode}).';
      throw AuthException(msg);
    }

    final data = _pickObject(body, ['data']);
    final resetToken = _pickString(data, ['resetToken', 'reset_token']);

    final message = _pickString(body, ['message', 'msg']) ??
        'If an account exists for this email, password reset instructions have been sent.';

    return ForgotPasswordResult(message: message, resetToken: resetToken);
  }

  @override
  Future<Session> registerFleetOperator({
    required String companyName,
    required String contactPerson,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.authRegisterPath}');
    final res = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'role': 'FLEET',
        'companyName': companyName,
        'contactPerson': contactPerson,
        'email': email,
        'password': password,
        'confirmPassword': confirmPassword,
      }),
    );

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(res.body);
      body = (decoded is Map<String, dynamic>) ? decoded : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = _pickString(body, ['message', 'error', 'msg']) ??
          'Registration failed (HTTP ${res.statusCode}).';
      throw AuthException(msg);
    }

    final session = _sessionFromAuthBody(
      body,
      fallbackEmail: email,
      roleHint: UserRole.fleet,
    );
    await saveSession(session);
    return session;
  }

  @override
  Future<void> registerServiceProvider({
    required String email,
    required String password,
    required String confirmPassword,
    required String fullName,
    required String phone,
    required String businessType,
    String? displayName,
    String? businessName,
    String? companyName,
    String? baseLocationText,
    String? basePostcode,
    num? hourlyRate,
    num? emergencyRate,
    num? emergencySurcharge,
    num? callOutFee,
    String? rateCurrency,
    num? coverageRadius,
    String? profilePhotoUrl,
    String? profilePhotoPath,
    List<String>? skills,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.authRegisterPath}');

    // Sole traders register as MECHANIC; companies register as COMPANY.
    final role = businessType == 'COMPANY' ? 'COMPANY' : 'MECHANIC';

    final fields = <String, String>{
      'email': email.trim(),
      'password': password,
      'confirmPassword': confirmPassword,
      'role': role,
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'businessType': businessType,
    };

    final dn = displayName?.trim();
    if (dn != null && dn.isNotEmpty) fields['displayName'] = dn;

    final bn = businessName?.trim();
    if (bn != null && bn.isNotEmpty) fields['businessName'] = bn;

    final cn = companyName?.trim();
    if (cn != null && cn.isNotEmpty) fields['companyName'] = cn;

    final blt = baseLocationText?.trim();
    if (blt != null && blt.isNotEmpty) fields['baseLocationText'] = blt;

    final bp = basePostcode?.trim();
    if (bp != null && bp.isNotEmpty) fields['basePostcode'] = bp;

    if (hourlyRate != null) fields['hourlyRate'] = '$hourlyRate';
    if (emergencyRate != null) fields['emergencyRate'] = '$emergencyRate';
    if (emergencySurcharge != null) fields['emergencySurcharge'] = '$emergencySurcharge';
    if (callOutFee != null) fields['callOutFee'] = '$callOutFee';

    final rc = rateCurrency?.trim();
    if (rc != null && rc.isNotEmpty) fields['rateCurrency'] = rc;

    if (coverageRadius != null) fields['coverageRadius'] = '$coverageRadius';

    fields['skills'] = jsonEncode(skills ?? const <String>[]);

    final pUrl = profilePhotoUrl?.trim();
    if (pUrl != null && pUrl.isNotEmpty) fields['profilePhotoUrl'] = pUrl;

    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..fields.addAll(fields);

    final photoPath = profilePhotoPath?.trim();
    if (photoPath != null && photoPath.isNotEmpty) {
      final f = File(photoPath);
      if (await f.exists()) {
        final filename = _normalizeRegisterPhotoFilename(photoPath);
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            photoPath,
            filename: filename,
            contentType: _registerImageMediaTypeForFilename(filename),
          ),
        );
      }
    }

    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(res.body);
      body = (decoded is Map<String, dynamic>) ? decoded : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = _pickString(body, ['message', 'error', 'msg']) ??
          'Registration failed (HTTP ${res.statusCode}).';
      throw AuthException(msg);
    }
  }

  @override
  Future<void> registerMechanicEmployee({
    required String email,
    required String password,
    required String confirmPassword,
    required String inviteToken,
    required String fullName,
    required String phone,
    required String displayName,
    required String baseLocationText,
    required List<String> skills,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.authRegisterPath}');
    final res = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
        'role': 'MECHANIC_EMPLOYEE',
        'inviteToken': inviteToken.trim(),
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'displayName': displayName.trim(),
        'baseLocationText': baseLocationText.trim(),
        'skills': skills,
      }),
    );

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(res.body);
      body = (decoded is Map<String, dynamic>) ? decoded : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = _pickString(body, ['message', 'error', 'msg']) ??
          'Registration failed (HTTP ${res.statusCode}).';
      throw AuthException(msg);
    }
  }
}

MediaType _registerImageMediaTypeForFilename(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return MediaType('image', 'png');
  if (lower.endsWith('.gif')) return MediaType('image', 'gif');
  if (lower.endsWith('.webp')) return MediaType('image', 'webp');
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
    return MediaType('image', 'heic');
  }
  return MediaType('image', 'jpeg');
}

final _registerPhotoExt =
    RegExp(r'\.(jpe?g|png|gif|webp|heic|heif)$', caseSensitive: false);

String _normalizeRegisterPhotoFilename(String filePath) {
  var name = filePath.trim().replaceAll('\\', '/');
  if (name.contains('/')) name = name.split('/').last;
  if (name.isEmpty) return 'profile.jpg';
  if (!_registerPhotoExt.hasMatch(name)) return '$name.jpg';
  return name;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
