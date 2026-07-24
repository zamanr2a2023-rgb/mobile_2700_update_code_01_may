import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';

/// Handles company invite deep links (`email` + `inviteToken` query params).
///
/// Supported examples:
/// - `https://thetruckfix.co.uk/invite?email=...&inviteToken=...`
/// - `https://api.thetruckfix.co.uk/invite?...`
/// - `truckfix://invite?email=...&inviteToken=...`
class InviteDeepLinkService {
  InviteDeepLinkService._();

  static final InviteDeepLinkService instance = InviteDeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  GoRouter? _router;
  Uri? _pending;

  void attachRouter(GoRouter router) {
    _router = router;
    final pending = _pending;
    if (pending != null) {
      _pending = null;
      _handleUri(pending);
    }
  }

  Future<void> start() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handleUri(initial);
      }
    } catch (e) {
      debugPrint('[InviteDeepLink] initial link failed: $e');
    }

    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object e) => debugPrint('[InviteDeepLink] stream error: $e'),
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void _handleUri(Uri uri) {
    final parsed = parseInviteUri(uri);
    if (parsed == null) return;

    final router = _router;
    if (router == null) {
      _pending = uri;
      return;
    }

    final email = Uri.encodeQueryComponent(parsed.email);
    // Do not log invite tokens.
    final token = Uri.encodeQueryComponent(parsed.inviteToken);
    router.go('${AppRoutes.inviteRegister}?email=$email&inviteToken=$token');
  }

  /// Returns invite credentials when the URI looks like an invitation link.
  static ({String email, String inviteToken})? parseInviteUri(Uri uri) {
    final params = Map<String, String>.from(uri.queryParameters);
    // Some hosts put token in path segment.
    final email = (params['email'] ?? params['Email'] ?? '').trim();
    final token = (params['inviteToken'] ??
            params['invite_token'] ??
            params['token'] ??
            '')
        .trim();

    final path = uri.path.toLowerCase();
    final host = uri.host.toLowerCase();
    final isInvitePath = path.contains('invite') ||
        path.contains('invitation') ||
        host.contains('invite') ||
        uri.scheme == 'truckfix';

    if (email.isEmpty || token.isEmpty) return null;
    if (!isInvitePath && params['inviteToken'] == null && params['invite_token'] == null) {
      // Allow any path if explicit inviteToken query is present.
      if (params['token'] == null) return null;
    }
    return (email: email, inviteToken: token);
  }
}
