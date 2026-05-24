import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../widgets/app_input.dart';
import '../../../widgets/buttons.dart';

/// Skill codes accepted by `POST /auth/register` for `MECHANIC_EMPLOYEE` (see Postman).
const _kMechanicEmployeeSkillOptions = <(String code, String label)>[
  ('ENGINE', 'Engine'),
  ('BRAKES', 'Brakes'),
  ('TYRES', 'Tyres'),
  ('ELECTRICAL', 'Electrical'),
  ('BRAKE_PROBLEM', 'Brake fault'),
  ('ENGINE_WONT_START', 'Engine start'),
  ('OVERHEATING', 'Cooling'),
  ('BREAKDOWN_UNKNOWN', 'Diagnostics'),
];

const _kPoundPrefix = SizedBox(
  width: 48,
  child: Center(
    child: Text('£', style: TextStyle(color: AppColors.textGray, fontSize: 16, fontWeight: FontWeight.w600)),
  ),
);

class MechanicRegisterScreen extends StatelessWidget {
  const MechanicRegisterScreen({super.key, required this.onNavigate});

  final void Function(String) onNavigate;

  @override
  Widget build(BuildContext context) {
    return _MechanicRegisterBody(onNavigate: onNavigate);
  }
}

class _MechanicRegisterBody extends StatefulWidget {
  const _MechanicRegisterBody({required this.onNavigate});

  final void Function(String) onNavigate;

  @override
  State<_MechanicRegisterBody> createState() => _MechanicRegisterBodyState();
}

class _MechanicRegisterBodyState extends State<_MechanicRegisterBody> {
  static const int _minPasswordLen = 8;

  bool _showPass = false;
  bool _showConfirm = false;
  double _radius = 30;
  bool _submitting = false;

  final _fullName = TextEditingController();
  final _companyName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _callOutFee = TextEditingController();
  final _hourlyRate = TextEditingController();
  final _emergencySurcharge = TextEditingController();
  final _basePostcode = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _businessType = 'sole_trader'; // sole_trader | company
  /// When [_businessType] is `company`: workshop owner vs invited employee.
  String _companyRelation = 'owner'; // owner | employee
  final _inviteToken = TextEditingController();
  final _employeeDisplayName = TextEditingController();
  final Set<String> _employeeSkills = {};
  String? _profilePhotoPath;

  bool get _isEmployeePath => _businessType == 'company' && _companyRelation == 'employee';

  @override
  void dispose() {
    _fullName.dispose();
    _companyName.dispose();
    _email.dispose();
    _phone.dispose();
    _callOutFee.dispose();
    _hourlyRate.dispose();
    _emergencySurcharge.dispose();
    _basePostcode.dispose();
    _password.dispose();
    _confirm.dispose();
    _inviteToken.dispose();
    _employeeDisplayName.dispose();
    super.dispose();
  }

  bool get _passwordsMatch =>
      _password.text.isNotEmpty && _confirm.text.isNotEmpty && _password.text == _confirm.text;

  bool get _passwordStrongEnough => _password.text.trim().length >= _minPasswordLen;

  num? _tryNum(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    return num.tryParse(v);
  }

  Future<void> _onCreateAccountPressed() async {
    if (_submitting) return;

    final fullName = _fullName.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    final password = _password.text;
    final confirmPassword = _confirm.text;
    final companyName = _companyName.text.trim();
    final basePostcode = _basePostcode.text.trim();

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

    if (_isEmployeePath) {
      final invite = _inviteToken.text.trim();
      final disp = _employeeDisplayName.text.trim();
      final baseLoc = basePostcode;
      if (fullName.isEmpty || email.isEmpty || phone.isEmpty || invite.isEmpty || disp.isEmpty || baseLoc.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all required fields (including invite code).')),
        );
        return;
      }
      if (_employeeSkills.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one skill.')),
        );
        return;
      }
    } else {
      if (fullName.isEmpty || email.isEmpty || phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all required fields.')),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final auth = context.read<AuthRepository>();

      if (_isEmployeePath) {
        final invite = _inviteToken.text.trim();
        final disp = _employeeDisplayName.text.trim();
        final baseLoc = basePostcode;
        await auth.registerMechanicEmployee(
          email: email,
          password: password,
          confirmPassword: confirmPassword,
          inviteToken: invite,
          fullName: fullName,
          phone: phone,
          displayName: disp,
          baseLocationText: baseLoc,
          skills: _employeeSkills.toList()..sort(),
        );
      } else {
        final businessType = _businessType == 'company' ? 'COMPANY' : 'SOLE_TRADER';
        final displayName = companyName.isNotEmpty ? companyName : fullName.split(' ').first;

        await auth.registerServiceProvider(
          email: email,
          password: password,
          confirmPassword: confirmPassword,
          fullName: fullName,
          displayName: displayName,
          phone: phone,
          businessType: businessType,
          businessName: companyName.isNotEmpty ? companyName : null,
          companyName: companyName.isNotEmpty ? companyName : null,
          basePostcode: basePostcode.isNotEmpty ? basePostcode : null,
          baseLocationText: basePostcode.isNotEmpty ? basePostcode : null,
          callOutFee: _tryNum(_callOutFee.text),
          hourlyRate: _tryNum(_hourlyRate.text),
          emergencySurcharge: _tryNum(_emergencySurcharge.text),
          emergencyRate: _tryNum(_emergencySurcharge.text),
          rateCurrency: 'ZAR',
          coverageRadius: _radius.toInt(),
          profilePhotoPath: _profilePhotoPath,
          skills: const [],
        );
      }
      if (!mounted) return;
      widget.onNavigate('mechanic-terms');
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _infoBannerText() {
    if (_businessType == 'sole_trader') {
      return "You work alone and manage all jobs yourself. You'll see all financial information and job details.";
    }
    if (_isEmployeePath) {
      return 'Enter your invite token and profile details. Your account is created as a mechanic employee — jobs assigned by your company only.';
    }
    return 'You can add multiple mechanics to your team. You\'ll manage finances while mechanics only see their assigned jobs.';
  }

  void _showProfilePhotoSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfilePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfilePhoto(ImageSource.gallery);
              },
            ),
            if (_profilePhotoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.red),
                title: const Text('Remove photo', style: TextStyle(color: AppColors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _profilePhotoPath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfilePhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (!mounted || picked == null) return;
    setState(() => _profilePhotoPath = picked.path);
  }

  String get _radiusLabel {
    if (_radius <= 5) return 'Local (≤5 mi)';
    if (_radius <= 15) return 'Town / City';
    if (_radius <= 30) return 'Regional';
    if (_radius <= 50) return 'Wide Area';
    return 'Nationwide';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => widget.onNavigate('role-select-signup'),
                    icon: const Icon(Icons.chevron_left, size: 16, color: AppColors.textGray),
                    label: const Text('Back', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.build_outlined, size: 20, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SERVICE PROVIDER', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
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
                padding: const EdgeInsets.all(14),
                children: [
                  const Text(
                    'BUSINESS TYPE',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _businessTypeCard(
                          selected: _businessType == 'sole_trader',
                          icon: Icons.person_outline,
                          title: 'Sole Trader',
                          subtitle: 'Working alone',
                            onTap: () => setState(() {
                            _businessType = 'sole_trader';
                            _companyRelation = 'owner';
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _businessTypeCard(
                          selected: _businessType == 'company',
                          icon: Icons.apartment_outlined,
                          title: 'Company',
                          subtitle: 'Multiple mechanics',
                          onTap: () => setState(() {
                            _businessType = 'company';
                            _companyRelation = 'owner';
                          }),
                        ),
                      ),
                    ],
                  ),
                  if (_businessType == 'company') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'ARE YOU A MECHANIC EMPLOYEE OR YOUR COMPANY?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _businessTypeCard(
                            selected: _companyRelation == 'employee',
                            icon: Icons.badge_outlined,
                            title: 'Mechanic Employee',
                            subtitle: 'Invite code',
                            compact: true,
                            onTap: () => setState(() {
                              _companyRelation = 'employee';
                              _profilePhotoPath = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _businessTypeCard(
                            selected: _companyRelation == 'owner',
                            icon: Icons.storefront_outlined,
                            title: 'Your company',
                            subtitle: 'Register workshop',
                            compact: true,
                            onTap: () => setState(() => _companyRelation = 'owner'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.22)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: AppColors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _infoBannerText(),
                            style: const TextStyle(color: AppColors.textGray, fontSize: 11, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!_isEmployeePath) ...[
                    Center(
                      child: Column(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showProfilePhotoSheet,
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 96,
                                    height: 86,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.borderLight, width: 1),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: _profilePhotoPath != null
                                        ? Image.file(
                                            File(_profilePhotoPath!),
                                            fit: BoxFit.cover,
                                            width: 96,
                                            height: 86,
                                          )
                                        : const Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.camera_alt_outlined, size: 22, color: AppColors.textMuted),
                                              SizedBox(height: 6),
                                              Text(
                                                'PHOTO',
                                                style: TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                  Positioned(
                                    right: -6,
                                    bottom: -6,
                                    child: InkWell(
                                      onTap: _showProfilePhotoSheet,
                                      customBorder: const CircleBorder(),
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.add, size: 14, color: Colors.black),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Profile photo (optional)',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_isEmployeePath) ...[
                    const Text('MECHANIC EMPLOYEE', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Email Address',
                      placeholder: 'emp@gmail.com',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, size: 16, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Invite code',
                      placeholder: 'Paste invite token from your employer',
                      controller: _inviteToken,
                      prefixIcon: const Icon(Icons.vpn_key_outlined, size: 16, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Full Name',
                      placeholder: 'JOHN SMITH',
                      controller: _fullName,
                      prefixIcon: const Icon(Icons.person_outline, size: 16, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Display Name',
                      placeholder: 'JOHN SMITH',
                      controller: _employeeDisplayName,
                      prefixIcon: const Icon(Icons.badge_outlined, size: 16, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Phone Number',
                      placeholder: '+447700900999',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined, size: 16, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Base location',
                      placeholder: 'Derby, UK',
                      controller: _basePostcode,
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 20),
                    const Text('SKILLS', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final o in _kMechanicEmployeeSkillOptions)
                          FilterChip(
                            label: Text(o.$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            selected: _employeeSkills.contains(o.$1),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _employeeSkills.add(o.$1);
                              } else {
                                _employeeSkills.remove(o.$1);
                              }
                            }),
                            selectedColor: AppColors.primary.withValues(alpha: 0.22),
                            checkmarkColor: Colors.black,
                            backgroundColor: const Color(0xFF111111),
                            side: BorderSide(
                              color: _employeeSkills.contains(o.$1) ? AppColors.primary : AppColors.border2,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('SECURITY', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Password',
                      placeholder: 'Create a strong password',
                      obscureText: !_showPass,
                      controller: _password,
                      prefixIcon: const Icon(Icons.lock_outline, size: 16, color: AppColors.textGray),
                      suffixIcon: IconButton(icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, size: 16, color: AppColors.textGray), onPressed: () => setState(() => _showPass = !_showPass)),
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Confirm Password',
                      placeholder: 'Re-enter your password',
                      obscureText: !_showConfirm,
                      controller: _confirm,
                      prefixIcon: const Icon(Icons.lock_outline, size: 16, color: AppColors.textGray),
                      suffixIcon: IconButton(icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility, size: 16, color: AppColors.textGray), onPressed: () => setState(() => _showConfirm = !_showConfirm)),
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
                  ] else ...[
                    const Text('PERSONAL INFO', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Full Name',
                      placeholder: 'JOHN SMITH',
                      controller: _fullName,
                      prefixIcon: const Icon(Icons.person_outline, size: 16, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Company Name (optional)',
                      placeholder: 'e.g. TechMech Workshop',
                      controller: _companyName,
                      prefixIcon: const Icon(Icons.business, size: 16, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Email Address',
                      placeholder: 'john@swiftmechanics.co.uk',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, size: 16, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Phone Number',
                      placeholder: '+44 7700 900000',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined, size: 16, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 24),
                    const Text('RATES (£)', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Call-out Charge',
                      placeholder: '80',
                      controller: _callOutFee,
                      keyboardType: TextInputType.number,
                      prefixIcon: _kPoundPrefix,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Hourly Rate',
                      placeholder: '95',
                      controller: _hourlyRate,
                      keyboardType: TextInputType.number,
                      prefixIcon: _kPoundPrefix,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Emergency Surcharge',
                      placeholder: '150',
                      controller: _emergencySurcharge,
                      keyboardType: TextInputType.number,
                      prefixIcon: _kPoundPrefix,
                    ),
                    const SizedBox(height: 24),
                    const Text('SERVICE AREA', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Base Postcode',
                      placeholder: 'e.g. SW1A 1AA',
                      controller: _basePostcode,
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('COVERAGE RADIUS', style: TextStyle(color:AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2),
                        ),
                        Text('${_radius.toInt()} mi · $_radiusLabel', style: const TextStyle(color: AppColors.textGray, fontSize: 10)),
                      ],
                    ),
                    Slider(value: _radius, min: 5, max: 100, divisions: 19, activeColor: AppColors.primary, onChanged: (v) => setState(() => _radius = v)),
                    const SizedBox(height: 24),
                    const Text('SECURITY', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Password',
                      placeholder: 'Create a strong password',
                      obscureText: !_showPass,
                      controller: _password,
                      prefixIcon: const Icon(Icons.lock_outline, size: 16, color: AppColors.textGray),
                      suffixIcon: IconButton(icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, size: 16, color: AppColors.textGray), onPressed: () => setState(() => _showPass = !_showPass)),
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Confirm Password',
                      placeholder: 'Re-enter your password',
                      obscureText: !_showConfirm,
                      controller: _confirm,
                      prefixIcon: const Icon(Icons.lock_outline, size: 16, color: AppColors.textGray),
                      suffixIcon: IconButton(icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility, size: 16, color: AppColors.textGray), onPressed: () => setState(() => _showConfirm = !_showConfirm)),
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
                    onPressed: _submitting ? null : _onCreateAccountPressed,
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

Widget _businessTypeCard({
  required bool selected,
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
  bool compact = false,
}) {
  final vPad = compact ? 10.0 : 16.0;
  final hPad = compact ? 8.0 : 12.0;
  final iconSize = compact ? 18.0 : 20.0;
  final titleSize = compact ? 10.5 : 12.0;
  final gap = compact ? 6.0 : 10.0;
  return InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(vertical: vPad, horizontal: hPad),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: selected ? AppColors.primary : AppColors.textGray),
          SizedBox(height: gap),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: selected ? AppColors.primary : Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    ),
  );
}
