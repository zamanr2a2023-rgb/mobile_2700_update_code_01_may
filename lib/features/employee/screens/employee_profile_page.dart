import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/mechanic_me_profile.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/support_help_bottom_sheet.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../../mechanic/viewmodel/mechanic_viewmodel.dart';

/// Mechanic employee profile — layout aligned with `lib/react/check.md` `EmployeeProfile`.
class EmployeeProfilePage extends StatefulWidget {
  const EmployeeProfilePage({super.key});

  @override
  State<EmployeeProfilePage> createState() => _EmployeeProfilePageState();
}

class _EmployeeProfilePageState extends State<EmployeeProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MechanicViewModel>().loadMeProfile();
    });
  }

  String _subtitleLine(MechanicMeProfile? p) {
    final c = (p?.employerCompanyName ?? '').trim();
    if (c.isNotEmpty) return c;
    return 'Assigned by your company';
  }

  String _ratingLabel(MechanicMeProfile? p) {
    if (p == null || p.ratingCount <= 0) return '—';
    return p.avgRating.toStringAsFixed(1);
  }

  Future<void> _onPushChanged(bool value) async {
    final mech = context.read<MechanicViewModel>();
    final p = mech.meProfile;
    if (p == null) return;
    try {
      await mech.patchMechanicNotificationSettings(
        pushEnabled: value,
        alertRadiusMiles: p.alertRadiusMiles,
        newBreakdownJobs: p.notifNewBreakdownJobs,
        jobAcceptedDeclined: p.notifJobAcceptedDeclined,
        paymentReceived: p.notifPaymentReceived,
        systemAlerts: p.notifSystemAlerts,
        appAlerts: p.notifAppAlerts,
      );
      await mech.loadMeProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _openHelp() {
    showSupportHelpBottomSheet(context, roleSuffix: 'Mechanic Employee');
  }

  @override
  Widget build(BuildContext context) {
    final mech = context.watch<MechanicViewModel>();
    final session = context.watch<AuthViewModel>().session;
    final p = mech.meProfile;

    if (mech.meProfileLoading && p == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (mech.meProfileError != null && p == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(mech.meProfileError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: mech.loadMeProfile,
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary), foregroundColor: AppColors.primary),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final displayName = (p?.displayName ?? session?.displayName ?? session?.email ?? 'Profile').trim();
    final email = (p?.email ?? session?.email ?? '').trim();
    final jobsDone = p?.jobsDone ?? 0;
    final jobsWeek = p?.jobsThisWeek ?? 0;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 8, 20, 28),
      children: [
        Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: () {
                final url = p?.profilePhotoUrl?.trim();
                if (url != null && url.isNotEmpty) {
                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.person_outline, size: 40, color: AppColors.primary),
                  );
                }
                return const Icon(Icons.person_outline, size: 40, color: AppColors.primary);
              }(),
            ),
            const SizedBox(height: 12),
            Text(
              displayName,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.2),
            ),
            const SizedBox(height: 4),
            Text(
              _subtitleLine(p),
              style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _StatTile(value: '$jobsDone', label: 'Jobs Done')),
            const SizedBox(width: 8),
            Expanded(child: _StatTile(value: '$jobsWeek', label: 'This Week')),
            const SizedBox(width: 8),
            Expanded(child: _StatTile(value: _ratingLabel(p), label: 'Rating')),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'PERSONAL DETAILS',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReadOnlyField(label: 'FULL NAME', value: displayName),
              const SizedBox(height: 14),
              _ReadOnlyField(label: 'EMAIL ADDRESS', value: email.isEmpty ? '—' : email),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'NOTIFICATIONS',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.notifications_none_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Push Notifications', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      'Get notified of new job assignments',
                      style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.85), fontSize: 11, height: 1.25),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: p?.pushEnabled ?? false,
                onChanged: mech.meProfilePatchBusy || p == null ? null : _onPushChanged,
                activeThumbColor: Colors.black,
                activeTrackColor: AppColors.primary,
                inactiveThumbColor: AppColors.textMuted,
                inactiveTrackColor: AppColors.border2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _openHelp,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Help & Support', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            'Contact your company admin',
                            style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.85), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.textHint.withValues(alpha: 0.9), size: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await context.read<AuthViewModel>().logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: BorderSide(color: AppColors.red.withValues(alpha: 0.35)),
              backgroundColor: AppColors.red.withValues(alpha: 0.06),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.red),
            label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _footerLine(p, session?.email),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.85), fontSize: 10, height: 1.35),
        ),
      ],
    );
  }

  String _footerLine(MechanicMeProfile? p, String? sessionEmail) {
    final org = (p?.employerCompanyName ?? '').trim();
    if (org.isNotEmpty) return 'Employee account · Managed by $org';
    final e = (sessionEmail ?? '').trim();
    if (e.isNotEmpty) return 'Employee account · $e';
    return 'Employee account';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Text(
              title,
              style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border2),
          ),
          child: Text(value, style: const TextStyle(color: AppColors.textGray, fontSize: 14)),
        ),
      ],
    );
  }
}
