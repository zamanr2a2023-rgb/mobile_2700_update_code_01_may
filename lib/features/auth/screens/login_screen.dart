import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/session.dart';
import '../viewmodel/auth_viewmodel.dart';
import '../../../widgets/buttons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.role,
    required this.onNavigate,
    this.nextAfterLogin,
  });

  final UserRole role;
  final void Function(String) onNavigate;

  /// Optional post-login route id (e.g. `company-invites`).
  final String? nextAfterLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _kWrench = Color(0xFF000000);

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  static InputDecoration _fieldDecoration(
      {String? hint, Widget? prefix, Widget? suffix}) {
    const radius = 12.0;
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(
          color: AppColors.textGray, fontSize: 14, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: const Color(0xFF111111),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIcon: suffix,
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
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _submitting = false;
        _error = 'Please enter email and password.';
      });
      return;
    }

    try {
      await context.read<AuthViewModel>().loginAs(email, password, widget.role);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful')),
      );

      final resolvedRole =
          context.read<AuthViewModel>().session?.role ?? widget.role;
      final next = widget.nextAfterLogin?.trim();
      if (next != null && next.isNotEmpty) {
        widget.onNavigate(next);
        return;
      }
      widget.onNavigate(
        switch (resolvedRole) {
          UserRole.mechanic => 'mechanic-dashboard',
          UserRole.company => 'company-dashboard',
          UserRole.employee => 'employee-dashboard',
          _ => 'fleet-dashboard',
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel =
        widget.role == UserRole.mechanic ? 'SERVICE PROVIDER' : 'FLEET';
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
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
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Transform.translate(
                  offset: const Offset(-0.8, -1.2),
                  child: Transform.rotate(
                    angle: -math.pi / -2,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.build_outlined,
                      size: 44,
                      color: _kWrench,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  textAlign: TextAlign.center,
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      height: 1.0,
                    ),
                    children: [
                      const TextSpan(
                        text: 'TRUCK',
                        style: TextStyle(color: AppColors.textWhite),
                      ),
                      TextSpan(
                        text: 'FIX',
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
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
                    style: const TextStyle(
                      color: AppColors.textGray,
                      fontSize: 14,
                    ),
                    decoration: _fieldDecoration(
                      hint: 'driver@fleetco.co.za',
                      prefix: const Icon(
                        Icons.email_outlined,
                        size: 20,
                        color: AppColors.textGray,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'PASSWORD',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textGray,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(
                      color: AppColors.textGray,
                      fontSize: 14,
                    ),
                    decoration: _fieldDecoration(
                      hint: '••••••••••',
                      prefix: const Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: AppColors.textGray,
                      ),
                      suffix: IconButton(
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppColors.textGray,
                        ),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.only(right: 8, left: 4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0B0B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3A1414)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFFFB4B4),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'SIGN IN AS $roleLabel',
                onPressed: _submitting ? null : _submit,
              ),
              const SizedBox(height: 100),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'New to TruckFix? ',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => widget.onNavigate('role-select-signup'),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => widget.onNavigate('forgot'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
