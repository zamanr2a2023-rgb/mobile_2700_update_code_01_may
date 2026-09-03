import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../routes/app_routes.dart';
import '../viewmodel/auth_viewmodel.dart';
import 'truckfix_loading_screen.dart';
import '../../../core/auth/session_validation.dart';

/// Session bootstrap before the rest of the auth stack.
class IntroLoaderScreen extends StatefulWidget {
  const IntroLoaderScreen({super.key});

  @override
  State<IntroLoaderScreen> createState() => _IntroLoaderScreenState();
}

class _IntroLoaderScreenState extends State<IntroLoaderScreen> {
  final Completer<void> _gearRoundComplete = Completer<void>();
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    if (!mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final auth = context.read<AuthViewModel>();
    String? nextRoute;
    Object? validationError;

    await Future.wait<void>([
      () async {
        try {
          nextRoute = await auth.bootstrapSession();
        } catch (e) {
          validationError = e;
        }
      }(),
      _gearRoundComplete.future,
    ]);

    if (!mounted) return;

    if (validationError != null) {
      setState(() {
        _busy = false;
        _error = validationError is SessionUnreachableException
            ? validationError.toString()
            : 'Unable to verify your session. Please try again.';
      });
      return;
    }

    context.go(nextRoute ?? AppRoutes.splash);
  }

  void _onGearAnimationComplete() {
    if (!_gearRoundComplete.isCompleted) {
      _gearRoundComplete.complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _route,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return TruckFixLoadingScreen(onAnimationComplete: _onGearAnimationComplete);
  }
}
