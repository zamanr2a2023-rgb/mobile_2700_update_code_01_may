import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/company_invite.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/services/public_invite_api_service.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/app_input.dart';
import '../../../widgets/buttons.dart';
import '../viewmodel/auth_viewmodel.dart';

/// New-user invitation registration after public validate.
class InviteRegisterScreen extends StatefulWidget {
  const InviteRegisterScreen({
    super.key,
    required this.email,
    required this.inviteToken,
    this.companyName,
    this.initialValidation,
  });

  final String email;
  final String inviteToken;
  final String? companyName;
  final PublicInviteValidation? initialValidation;

  @override
  State<InviteRegisterScreen> createState() => _InviteRegisterScreenState();
}

class _InviteRegisterScreenState extends State<InviteRegisterScreen> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _displayName = TextEditingController();
  final _baseLocation = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  PublicInviteValidation? _validation;
  bool _validating = true;
  String? _validateError;
  bool _submitting = false;

  static const _skills = <(String, String)>[
    ('GENERAL_REPAIR', 'General repair'),
    ('TYRES', 'Tyres'),
    ('BRAKES', 'Brakes'),
    ('ELECTRICAL', 'Electrical'),
    ('DIAGNOSTICS', 'Diagnostics'),
    ('RECOVERY', 'Recovery'),
  ];
  final Set<String> _selectedSkills = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValidation;
    if (initial != null) {
      _validation = initial;
      _validating = false;
      if (initial.existingAccount) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _goLoginForExisting());
      }
    } else {
      _runValidate();
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _displayName.dispose();
    _baseLocation.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _runValidate() async {
    setState(() {
      _validating = true;
      _validateError = null;
    });
    try {
      final result = await PublicInviteApiService().validateInvite(
        token: widget.inviteToken,
        email: widget.email,
      );
      if (!mounted) return;
      if (result.existingAccount) {
        _validation = result;
        _validating = false;
        setState(() {});
        _goLoginForExisting();
        return;
      }
      if (!result.valid) {
        setState(() {
          _validation = result;
          _validating = false;
          _validateError = result.message ?? 'This invitation is not valid.';
        });
        return;
      }
      setState(() {
        _validation = result;
        _validating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validating = false;
        _validateError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _goLoginForExisting() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You already have an account. Sign in to accept this invitation.'),
      ),
    );
    context.go('${AppRoutes.login}?role=mechanic&next=company-invites');
  }

  Future<void> _submit() async {
    final fullName = _fullName.text.trim();
    final phone = _phone.text.trim();
    final displayName = _displayName.text.trim().isEmpty ? fullName : _displayName.text.trim();
    final baseLoc = _baseLocation.text.trim();
    final password = _password.text;
    final confirm = _confirmPassword.text;

    if (fullName.isEmpty || phone.isEmpty || baseLoc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters.')),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one skill.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final session = await context.read<AuthRepository>().registerMechanicEmployee(
            email: widget.email.trim(),
            password: password,
            confirmPassword: confirm,
            inviteToken: widget.inviteToken.trim(),
            fullName: fullName,
            phone: phone,
            displayName: displayName,
            baseLocationText: baseLoc,
            skills: _selectedSkills.toList()..sort(),
          );
      if (!mounted) return;
      await context.read<AuthViewModel>().adoptSession(session);
      if (!mounted) return;
      context.go(AppRoutes.employeeHome);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = (_validation?.companyName ?? widget.companyName ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => context.go(AppRoutes.splash),
        ),
        title: const Text(
          'Join company team',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: _validating
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _validateError != null
              ? _ErrorBody(message: _validateError!, onRetry: _runValidate)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    if (company.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invited by',
                              style: TextStyle(
                                color: AppColors.textMuted.withValues(alpha: 0.95),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              company,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    _LockedEmailField(email: widget.email),
                    const SizedBox(height: 12),
                    AppInput(label: 'Full name', placeholder: 'Your full name', controller: _fullName),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Display name',
                      placeholder: 'Shown to fleets',
                      controller: _displayName,
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Phone',
                      placeholder: '+44 …',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Base location',
                      placeholder: 'Town or postcode',
                      controller: _baseLocation,
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Password',
                      placeholder: 'Min 8 characters',
                      controller: _password,
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Confirm password',
                      placeholder: 'Repeat password',
                      controller: _confirmPassword,
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SKILLS',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in _skills)
                          FilterChip(
                            label: Text(s.$2, style: const TextStyle(fontSize: 11)),
                            selected: _selectedSkills.contains(s.$1),
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _selectedSkills.add(s.$1);
                                } else {
                                  _selectedSkills.remove(s.$1);
                                }
                              });
                            },
                            selectedColor: AppColors.primary.withValues(alpha: 0.25),
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: _selectedSkills.contains(s.$1) ? Colors.white : AppColors.textSecondary,
                            ),
                            backgroundColor: AppColors.card,
                            side: BorderSide(color: AppColors.border),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: _submitting ? 'Creating account…' : 'Create employee account',
                      onPressed: _submitting ? null : _submit,
                    ),
                  ],
                ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.link_off_rounded, color: AppColors.textMuted, size: 40),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _LockedEmailField extends StatelessWidget {
  const _LockedEmailField({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INVITED EMAIL',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textGray,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  email,
                  style: const TextStyle(color: AppColors.textGray, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
