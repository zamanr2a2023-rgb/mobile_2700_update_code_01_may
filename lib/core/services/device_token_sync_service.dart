import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/session.dart';
import '../../data/repositories/api_auth_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/services/notifications_api_service.dart';
import 'push_notification_service.dart';

const _kLastDeviceTokenSyncKey = 'truckfix.device_token.last_sync.v1';

/// Registers the FCM token with `POST /api/v1/notifications/device-tokens`.
class DeviceTokenSyncService {
  DeviceTokenSyncService({
    AuthRepository? authRepository,
    NotificationsApiService? notificationsApi,
  })  : _auth = authRepository ?? ApiAuthRepository(),
        _notificationsApi = notificationsApi ?? NotificationsApiService();

  static final DeviceTokenSyncService instance = DeviceTokenSyncService();

  final AuthRepository _auth;
  final NotificationsApiService _notificationsApi;

  Future<void> syncWhenTokenAvailable() async {
    final session = await _auth.getSession();
    if (session != null) {
      await syncWithSession(session);
    }
  }

  Future<void> syncWithSession(Session session) async {
    final accessToken = session.accessToken?.trim();
    if (accessToken == null || accessToken.isEmpty) return;

    final fcmToken = await _resolveFcmToken();
    if (fcmToken == null || fcmToken.isEmpty) return;

    final platform = _pushPlatform;
    final syncKey = '$accessToken|$fcmToken|$platform';
    if (await _wasSynced(syncKey)) return;

    try {
      await _notificationsApi.registerDeviceToken(
        accessToken: accessToken,
        token: fcmToken,
        platform: platform,
      );
      await _markSynced(syncKey);
      if (kDebugMode) {
        debugPrint('[FCM] device token registered with backend ($platform).');
      }
    } on NotificationsApiException catch (e) {
      debugPrint('[FCM] device token registration failed: $e');
    } catch (e) {
      debugPrint('[FCM] device token registration error: $e');
    }
  }

  Future<void> clearLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastDeviceTokenSyncKey);
  }

  Future<String?> _resolveFcmToken() async {
    final push = PushNotificationService.instance;
    final inMemory = push.fcmToken?.trim();
    if (inMemory != null && inMemory.isNotEmpty) return inMemory;
    final cached = await push.loadPersistedToken();
    if (cached != null && cached.trim().isNotEmpty) return cached.trim();
    return null;
  }

  String get _pushPlatform {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  Future<bool> _wasSynced(String syncKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastDeviceTokenSyncKey) == syncKey;
  }

  Future<void> _markSynced(String syncKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastDeviceTokenSyncKey, syncKey);
  }
}
