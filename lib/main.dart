import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/services/device_token_sync_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/app_repository.dart';
import 'data/repositories/api_auth_repository.dart';
import 'features/auth/viewmodel/auth_viewmodel.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FCM after binding; failures are logged and do not block startup.
  await PushNotificationService.instance.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final authRepository = ApiAuthRepository();
  final jobRepository = MemoryJobRepository();
  final authViewModel = AuthViewModel(authRepository);
  await authViewModel.loadSession();
  if (authViewModel.isAuthenticated && authViewModel.session != null) {
    unawaited(
      DeviceTokenSyncService.instance.syncWithSession(authViewModel.session!),
    );
  }

  final router = AppRouter.create(authViewModel);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        Provider<JobRepository>.value(value: jobRepository),
        ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
      ],
      child: TruckFixApp(router: router),
    ),
  );
}

class TruckFixApp extends StatefulWidget {
  const TruckFixApp({super.key, required this.router});

  final GoRouter router;

  @override
  State<TruckFixApp> createState() => _TruckFixAppState();
}

class _TruckFixAppState extends State<TruckFixApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(DeviceTokenSyncService.instance.syncWhenTokenAvailable());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TruckFix',
      theme: AppTheme.dark,
      routerConfig: widget.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
