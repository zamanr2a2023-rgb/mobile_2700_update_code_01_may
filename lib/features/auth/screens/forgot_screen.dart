import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/buttons.dart';

/// Forgot password — `POST /api/v1/auth/forgot-password` with `{ "email": "..." }`.
class ForgetScreen extends StatefulWidget {
  const ForgetScreen({super.key});

  @override
  State<ForgetScreen> createState() => _ForgetScreenState();
}

class _ForgetScreenState extends State<ForgetScreen> {
  static const Color _kWrench = Color(0xFF000000);

  final _emailCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _successMessage;

  static InputDecoration _fieldDecoration({String? hint, Widget? prefix}) {
    const radius = 12.0;
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textGray, fontSize: 14, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: const Color(0xFF111111),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  Future<void> _submit() async {
    if (_submitting || _successMessage != null) return;

    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await context.read<AuthRepository>().forgotPassword(email: email);
      if (!mounted) return;
      setState(() {
        _successMessage = result.message;
        _submitting = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _successMessage != null;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _goBack,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    minimumSize: const Size(40, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textMuted.withValues(alpha: 0.95)),
                ),
              ),
              const SizedBox(height: 24),
              Center(child: _logo()),
              const SizedBox(height: 20),
              Text(
                sent ? 'Check your email' : 'Forgot password?',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.3),
              ),
              const SizedBox(height: 10),
              Text(
                sent
                    ? _successMessage!
                    : 'Enter your email and we\'ll send you a link to reset your password.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 32),
              if (sent) ...[
                const Icon(Icons.mark_email_read_outlined, size: 56, color: AppColors.primary),
                const SizedBox(height: 28),
                PrimaryButton(label: 'BACK TO SIGN IN', onPressed: _goBack),
              ] else ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'EMAIL ADDRESS',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textGray,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enabled: !_submitting,
                      style: const TextStyle(color: AppColors.textGray, fontSize: 14),
                      decoration: _fieldDecoration(
                        hint: 'you@company.co.uk',
                        prefix: const Icon(Icons.email_outlined, size: 20, color: AppColors.textGray),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _submitting ? 'SENDING…' : 'SEND RESET LINK',
                  onPressed: _submitting ? null : _submit,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _submitting ? null : _goBack,
                    child: const Text(
                      'Back to Sign in',
                      style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.38),
                blurRadius: 20,
              ),
            ],
          ),
          child: Transform.translate(
            offset: const Offset(-0.8, -1.2),
            child: Transform.rotate(
              angle: -math.pi / -2,
              alignment: Alignment.center,
              child: const Icon(Icons.build_outlined, size: 44, color: _kWrench),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.2, height: 1.0),
              children: const [
                TextSpan(text: 'TRUCK', style: TextStyle(color: AppColors.textWhite)),
                TextSpan(text: 'FIX', style: TextStyle(color: AppColors.primary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
