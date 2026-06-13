import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../widgets/app_input.dart';
import '../../../widgets/buttons.dart';
import '../viewmodel/auth_viewmodel.dart';

class FleetRegisterScreen extends StatelessWidget {
  const FleetRegisterScreen({super.key, required this.onNavigate});

  final void Function(String) onNavigate;

  @override
  Widget build(BuildContext context) {
    return _FleetRegisterBody(onNavigate: onNavigate);
  }
}

class _FleetRegisterBody extends StatefulWidget {
  const _FleetRegisterBody({required this.onNavigate});

  final void Function(String) onNavigate;

  @override
  State<_FleetRegisterBody> createState() => _FleetRegisterBodyState();
}

class _FleetRegisterBodyState extends State<_FleetRegisterBody> {
  static const int _minPasswordLen = 8;

  bool _showPass = false;
  bool _showConfirm = false;
  bool _submitting = false;
  final _company = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _company.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _passwordsMatch =>
      _password.text.isNotEmpty && _confirm.text.isNotEmpty && _password.text == _confirm.text;

  bool get _passwordStrongEnough => _password.text.trim().length >= _minPasswordLen;

  Future<void> _submit() async {
    if (_submitting) return;

    final companyName = _company.text.trim();
    final contactPerson = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final confirmPassword = _confirm.text;

    if (companyName.isEmpty || contactPerson.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }
    if (password.trim().length < _minPasswordLen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters.')),
      );
      return;
    }
    if (password.isEmpty || confirmPassword.isEmpty || password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final auth = context.read<AuthRepository>();
      final session = await auth.registerFleetOperator(
        companyName: companyName,
        contactPerson: contactPerson,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      );
      if (!mounted) return;
      await context.read<AuthViewModel>().adoptSession(session);
      if (!mounted) return;
      widget.onNavigate('fleet-dashboard');
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top:10, left: 24, right: 24, bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => widget.onNavigate('role-select-signup'),
                    icon: const Icon(Icons.chevron_left, size: 16, color: AppColors.textGray),
                    label: const Text('Back', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.local_shipping, size: 20, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FLEET OPERATOR', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                          Text('Create Account', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  AppInput(
                    label: 'Company Name',
                    placeholder: 'Logistix Transport (Pty) Ltd',
                    controller: _company,
                    prefixIcon: const Icon(Icons.business, size: 16, color: AppColors.textGray),
                  ),
                  const SizedBox(height: 16),
                  AppInput(
                    label: 'Full Name',
                    placeholder: 'John Khumalo',
                    controller: _name,
                    prefixIcon: const Icon(Icons.person_outline, size: 16, color: AppColors.textGray),
                  ),
                  const SizedBox(height: 16),
                  AppInput(
                    label: 'Email Address',
                    placeholder: 'john@logistix.co.za',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined, size: 16, color: AppColors.textGray),
                  ),
                  const SizedBox(height: 16),
                  AppInput(
                    label: 'Password',
                    placeholder: 'Create a strong password',
                    obscureText: !_showPass,
                    controller: _password,
                    prefixIcon: const Icon(Icons.lock_outline, size: 16, color: AppColors.textGray),
                    suffixIcon: IconButton(
                      icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, size: 16, color: AppColors.textGray),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppInput(
                    label: 'Confirm Password',
                    placeholder: 'Re-enter your password',
                    obscureText: !_showConfirm,
                    controller: _confirm,
                    prefixIcon: const Icon(Icons.lock_outline, size: 16, color: AppColors.textGray),
                    suffixIcon: IconButton(
                      icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility, size: 16, color: AppColors.textGray),
                      onPressed: () => setState(() => _showConfirm = !_showConfirm),
                    ),
                  ),
                  if (_password.text.isNotEmpty && _confirm.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            (_passwordsMatch && _passwordStrongEnough) ? Icons.check : Icons.close,
                            size: 12,
                            color: (_passwordsMatch && _passwordStrongEnough) ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            !_passwordStrongEnough
                                ? 'Minimum 8 characters required'
                                : _passwordsMatch
                                    ? 'Passwords match'
                                    : "Passwords don't match",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: (_passwordsMatch && _passwordStrongEnough)
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                children: [
                  PrimaryButton(
                    label: _submitting ? 'Creating…' : 'Create Account →',
                    onPressed: _submitting ? null : _submit,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already registered? ', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      GestureDetector(
                        onTap: () => widget.onNavigate('login'),
                        child: const Text('Sign in', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
