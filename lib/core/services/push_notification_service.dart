import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_token_sync_service.dart';

const _kFcmTokenKey = 'truckfix.fcm.token.v1';
const _androidChannelId = 'truckfix_alerts';
const _androidChannelName = 'TruckFix alerts';

/// Background FCM handler (must be top-level).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void _logFcmToken(String token, {required String label}) {
  print('');
  print('══════════════════════════════════════════════════════════');
  print('  FCM TOKEN ($label)');
  print('  $token');
  print('══════════════════════════════════════════════════════════');
  print('');
  debugPrint('[FCM] $label: $token');
}

/// Firebase Cloud Messaging setup for Android + iOS.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Prints the last known FCM token to the console.
  Future<void> logCurrentToken() async {
    final cached = _fcmToken ?? await loadPersistedToken();
    if (cached != null && cached.trim().isNotEmpty) {
      _logFcmToken(cached, label: 'current');
      return;
    }
    await _fetchAndLogFcmToken(label: 'manual');
  }

  /// Call once from [main] after [WidgetsFlutterBinding.ensureInitialized].
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;

      await _setupLocalNotifications();
      await _requestPermissions();

      final messaging = _messaging!;
      messaging.onTokenRefresh.listen((token) async {
        _fcmToken = token;
        await _persistToken(token);
        _logFcmToken(token, label: 'refreshed');
        unawaited(DeviceTokenSyncService.instance.syncWhenTokenAvailable());
      });

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _onMessageOpenedApp(initial);
      }

      _initialized = true;

      // iOS: FCM needs APNS first — fetch in background so startup is not blocked.
      unawaited(_fetchAndLogFcmToken(label: 'initial'));
    } catch (e, st) {
      print('[FCM] setup failed: $e');
      debugPrint('$st');
    }
  }

  /// Waits for APNS (iOS only), then requests the FCM token with retries.
  Future<void> _fetchAndLogFcmToken({required String label}) async {
    final messaging = _messaging;
    if (messaging == null) return;

    if (!kIsWeb && Platform.isIOS) {
      await _waitForApnsToken(messaging);
    }

    const maxAttempts = 15;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final token = await messaging.getToken();
        if (token != null && token.trim().isNotEmpty) {
          _fcmToken = token;
          await _persistToken(token);
          _logFcmToken(token, label: label);
          unawaited(DeviceTokenSyncService.instance.syncWhenTokenAvailable());
          return;
        }
      } on FirebaseException catch (e) {
        final isApnsPending = e.code == 'apns-token-not-set';
        if (isApnsPending && attempt < maxAttempts) {
          print('[FCM] APNS not ready yet ($attempt/$maxAttempts), retrying in 2s…');
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        _logApnsSetupHint(e);
        return;
      } catch (e) {
        print('[FCM] getToken error: $e');
        return;
      }
    }

    print('[FCM] No FCM token after $maxAttempts attempts.');
    _logApnsSetupHint(null);
  }

  Future<void> _waitForApnsToken(
    FirebaseMessaging messaging, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var tries = 0;
    while (DateTime.now().isBefore(deadline)) {
      tries++;
      final apns = await messaging.getAPNSToken();
      if (apns != null && apns.trim().isNotEmpty) {
        print('[FCM] APNS token received (attempt $tries).');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    print('[FCM] APNS token not received within ${timeout.inSeconds}s.');
  }

  void _logApnsSetupHint(FirebaseException? e) {
    if (e != null) {
      print('[FCM] ${e.code}: ${e.message}');
    }
    if (!kIsWeb && Platform.isIOS) {
      print(
        '[FCM] iOS checklist: enable Push on App ID r2a.truckfix.truckfix, '
        'add Push Notifications capability in Xcode, use Runner.entitlements '
        '(aps-environment), upload APNs key in Firebase Console, run on a real device.',
      );
    }
  }

  Future<void> _setupLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: 'Job updates, messages, and support alerts',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermissions() async {
    final messaging = _messaging;
    if (messaging == null) return;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      print('[FCM] permission: ${settings.authorizationStatus}');
    }

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFcmTokenKey, token);
  }

  Future<String?> loadPersistedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kFcmTokenKey);
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: 'Job updates, messages, and support alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data.isEmpty ? null : jsonEncode(message.data),
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FCM] opened from notification: ${message.data}');
    }
  }
}
