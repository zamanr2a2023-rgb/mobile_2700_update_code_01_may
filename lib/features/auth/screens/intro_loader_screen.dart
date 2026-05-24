import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/app_repository.dart';
import '../../../routes/app_routes.dart';
import '../logic/splash_login_check.dart';
import 'truckfix_loading_screen.dart';

/// Session bootstrap before the rest of the auth stack.
class IntroLoaderScreen extends StatefulWidget {
  const IntroLoaderScreen({super.key});

  @override
  State<IntroLoaderScreen> createState() => _IntroLoaderScreenState();
}

class _IntroLoaderScreenState extends State<IntroLoaderScreen> {
  final Completer<void> _gearRoundComplete = Completer<void>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    if (!mounted) return;
    final auth = context.read<AuthRepository>();
    String? nextRoute;
    await Future.wait<void>([
      resolvePostSplashLocation(auth).then((next) {
        nextRoute = next;
      }),
      _gearRoundComplete.future,
    ]);
    if (!mounted) return;
    context.go(nextRoute ?? AppRoutes.splash);
  }

  void _onGearAnimationComplete() {
    if (!_gearRoundComplete.isCompleted) {
      _gearRoundComplete.complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TruckFixLoadingScreen(onAnimationComplete: _onGearAnimationComplete);
  }
}
