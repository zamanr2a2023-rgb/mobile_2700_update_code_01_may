import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/job_offer.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/truckfix_map_preview.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../../categories/job_taxonomy.dart';
import '../viewmodel/mechanic_viewmodel.dart';
import '../../../data/services/mechanic_api_service.dart';

class MechanicAppShell extends StatelessWidget {
  const MechanicAppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => MechanicViewModel(
        ctx.read<JobRepository>(),
        ctx.read<AuthRepository>(),
        MechanicApiService(),
      ),
      child: const _MechScaffold(),
    );
  }
}

class _MechScaffold extends StatelessWidget {
  const _MechScaffold();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MechanicViewModel>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Expanded(child: _MechBody()),
          _MechBottomNav(vm: vm),
        ],
      ),
    );
  }
}

class _MechBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MechanicViewModel>();
    switch (vm.tab) {
      case 'feed':
        return const _JobFeedPage();
      case 'my-quotes':
        return _MyQuotes(onBack: () => vm.setTab('feed'));
      case 'quote-detail':
        return _QuoteDetailPage(onBack: () => vm.setTab('feed'));
      case 'my-jobs':
        return _MyJobsPage(onTracker: () => vm.setTab('job-tracker'));
      case 'job-tracker':
        return _JobTrackerPage(onBack: () => vm.setTab('my-jobs'));
      case 'earnings':
        return _MechanicEarnings(onBack: () => vm.setTab('profile'));
      case 'edit-profile':
        return _MechanicEditProfile(onDone: () => vm.setTab('profile'));
      case 'payment-methods':
        return _MechPayment(onClose: () => vm.setTab('profile'));
      case 'profile':
        return _MechanicProfile(
          onEarnings: () => vm.setTab('earnings'),
          onEdit: () => vm.setTab('edit-profile'),
          onPayment: () => vm.setTab('payment-methods'),
          onHelp: () => showMechanicHelpSupportSheet(context),
          onLogout: () async {
            await context.read<AuthViewModel>().logout();
            if (context.mounted) context.go(AppRoutes.login);
          },
        );
      default:
        return const _JobFeedPage();
    }
  }
}

void showMechanicHelpSupportSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (ctx) => _HelpSupportSheet(onClose: () => Navigator.pop(ctx)),
  );
}

class _HelpCategory {
  const _HelpCategory({required this.id, required this.label, required this.icon});

  final String id;
  final String label;
  final IconData icon;
}

class _HelpSupportSheet extends StatefulWidget {
  const _HelpSupportSheet({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_HelpSupportSheet> createState() => _HelpSupportSheetState();
}

class _HelpSupportSheetState extends State<_HelpSupportSheet> {
  static const _categories = <_HelpCategory>[
    _HelpCategory(id: 'technical', label: 'Technical Issue', icon: Icons.build_outlined),
    _HelpCategory(id: 'payment', label: 'Payment / Billing', icon: Icons.attach_money_rounded),
    _HelpCategory(id: 'account', label: 'Account & Profile', icon: Icons.person_outline_rounded),
    _HelpCategory(id: 'job', label: 'Job / Booking', icon: Icons.work_outline_rounded),
    _HelpCategory(id: 'other', label: 'Other', icon: Icons.help_outline_rounded),
  ];

  String? _categoryId;
  final _messageCtrl = TextEditingController();
  bool _sent = false;

  static const _fromEmail = 'james@truckfix.co.uk';
  static const _roleLabel = 'Mechanic';

  bool get _canSend => _categoryId != null && _messageCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    if (_sent) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: const Color(0xFF0E0E0E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border2)),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(999)),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.30)),
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.green, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text('Message Sent!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text(
                    'Our support team will respond within 24 hours via your registered email address.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.45),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: widget.onClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: maxH,
          child: Material(
            color: const Color(0xFF0E0E0E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(999)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
                        ),
                        child: const Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Help & Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                            SizedBox(height: 2),
                            Text('We usually reply within 24 hours', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: widget.onClose,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "WHAT'S THIS ABOUT?",
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final chipW = (constraints.maxWidth - 8) / 2;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categories.map((c) {
                                final sel = _categoryId == c.id;
                                return SizedBox(
                                  width: chipW,
                                  child: Material(
                                    color: sel ? AppColors.primary.withValues(alpha: 0.08) : AppColors.card2,
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      onTap: () => setState(() => _categoryId = c.id),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: sel ? AppColors.primary.withValues(alpha: 0.50) : const Color(0xFF1E1E1E)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(c.icon, size: 18, color: sel ? AppColors.primary : AppColors.textMuted),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                c.label,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: sel ? AppColors.primary : AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'YOUR MESSAGE',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _messageCtrl,
                          onChanged: (_) => setState(() {}),
                          maxLines: 5,
                          style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.45),
                          decoration: InputDecoration(
                            hintText: 'Describe your issue or question in as much detail as possible...',
                            hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 12),
                            filled: true,
                            fillColor: AppColors.card2,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.border2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.border2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.40)),
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sent from: $_fromEmail · $_roleLabel',
                          style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.85), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _canSend ? () => setState(() => _sent = true) : null,
                          icon: Icon(Icons.send_rounded, size: 18, color: _canSend ? Colors.black : Colors.black.withValues(alpha: 0.35)),
                          label: Text(
                            'SEND MESSAGE',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              fontSize: 12,
                              color: _canSend ? Colors.black : Colors.black.withValues(alpha: 0.35),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canSend ? AppColors.primary : AppColors.primary.withValues(alpha: 0.30),
                            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.30),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onClose,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MechBottomNav extends StatelessWidget {
  const _MechBottomNav({required this.vm});

  final MechanicViewModel vm;

  @override
  Widget build(BuildContext context) {
    final a = vm.bottomNavResolved;
    Widget item(String id, IconData icon, String label) {
      final on = a == id;
      return Expanded(
        child: InkWell(
          onTap: () => vm.setTab(id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: on ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: on ? Colors.black : AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: on ? AppColors.primary : AppColors.textHint),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.border))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            item('feed', Icons.work_outline, 'Jobs'),
            item('my-quotes', Icons.list_alt, 'Quotes'),
            item('my-jobs', Icons.bolt, 'My Jobs'),
            item('profile', Icons.person_outline, 'Profile'),
          ],
        ),
      ),
    );
  }
}

class _JobFeedPage extends StatelessWidget {
  const _JobFeedPage();

  Future<void> _toggleOnline(BuildContext context) async {
    try {
      await context.read<MechanicViewModel>().toggleOnline();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MechanicViewModel>();
    final jobs = vm.online ? vm.filteredJobs() : <JobOffer>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Job Feed', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('Nearby breakdown jobs', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            if (vm.online)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.payments_outlined, size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text('£465 today', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _toggleOnline(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: vm.online ? AppColors.green.withValues(alpha: 0.1) : AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: vm.online ? AppColors.green.withValues(alpha: 0.55) : AppColors.border2,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, color: vm.online ? AppColors.green : AppColors.textMuted, size: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vm.online ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                          color: vm.online ? AppColors.green : AppColors.textMuted,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        vm.online ? 'Receiving nearby breakdown jobs' : 'Tap to go online',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: vm.online,
                  onChanged: (_) => _toggleOnline(context),
                  activeTrackColor: AppColors.green.withValues(alpha: 0.5),
                  activeThumbColor: Colors.white,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => _MechanicFeedSheets.serviceArea(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.card,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
              child: Text('${vm.radiusMi} mi radius', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _MechanicFeedSheets.serviceArea(context),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.card,
                  side: const BorderSide(color: AppColors.border2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                child: Text(
                  '${vm.city}, ${vm.postcode}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
        if (vm.online) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _distChip(vm, 'All', null),
                _distChip(vm, '≤ 5 mi', 5),
                _distChip(vm, '≤ 10 mi', 10),
                _distChip(vm, '≤ ${vm.radiusMi} mi', vm.radiusMi),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (!vm.online)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.offline_bolt, size: 56, color: AppColors.textHint),
                  SizedBox(height: 12),
                  Text("You're offline", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  SizedBox(height: 8),
                  Text(
                    'Toggle online to receive jobs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          ...jobs.map((j) => _jobCard(context, j)),
      ],
    );
  }

  Widget _distChip(MechanicViewModel vm, String label, int? max) {
    final on = vm.maxDistMi == max;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
        selected: on,
        onSelected: (_) => vm.setMaxDist(max),
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(color: on ? AppColors.primary : AppColors.textMuted),
        side: BorderSide(color: on ? AppColors.primary : AppColors.border),
      ),
    );
  }

  Widget _jobCard(BuildContext context, JobOffer j) {
    final vm = context.read<MechanicViewModel>();
    final ratio = vm.radiusMi <= 0 ? 0.0 : (j.distanceMi / vm.radiusMi).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: InkWell(
            onTap: () => context.read<MechanicViewModel>().setTab('quote-detail'),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        j.id,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: j.urgency.chipBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: j.urgency.chipBorder),
                        ),
                        child: Text(
                          urgencyLabel(j.urgency).toUpperCase(),
                          style: TextStyle(
                            color: j.urgency.foreground,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      if (j.quotes == 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.green.withValues(alpha: 0.30)),
                          ),
                          child: const Text(
                            'FIRST',
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    j.truck,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    j.issue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(
                          color: AppColors.primary.withValues(alpha: 0.50),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${j.distanceMi.toStringAsFixed(1)} mi away',
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        j.posted,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        '${j.quotes} quotes',
                        style: const TextStyle(color: AppColors.textHint, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MechanicFeedSheets {
  static String _radiusLabelFor(int miles) {
    if (miles <= 5) return 'Local';
    if (miles <= 15) return 'Town / City';
    if (miles <= 30) return 'Regional';
    if (miles <= 50) return 'Wide Area';
    return 'Nationwide';
  }

  static Future<void> serviceArea(BuildContext context) async {
    final vm = context.read<MechanicViewModel>();
    var draftRadius = vm.radiusMi;
    var draftPostcode = vm.postcode;
    final postcodeController = TextEditingController(text: draftPostcode);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final radiusLabel = _radiusLabelFor(draftRadius);
            final bottomPad = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(top: 14, bottom: bottomPad),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(top: BorderSide(color: AppColors.border2)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Service Area',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(ctx),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: AppColors.border,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'BASE POSTCODE',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.card2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border2),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          child: TextField(
                            controller: postcodeController,
                            onChanged: (v) => setSt(() => draftPostcode = v),
                            maxLength: 8,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                              hintText: 'e.g. M1 1AE',
                              hintStyle: TextStyle(color: AppColors.textHint, fontWeight: FontWeight.w600, letterSpacing: 1),
                              prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.textMuted, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Job distances are measured from this postcode',
                          style: TextStyle(color: AppColors.textHint, fontSize: 10),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'COVERAGE RADIUS',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            Text(
                              '$draftRadius mi',
                              style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '· $radiusLabel',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.card2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border2),
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(ctx).copyWith(
                                  activeTrackColor: AppColors.primary,
                                  inactiveTrackColor: AppColors.border2,
                                  thumbColor: AppColors.primary,
                                  overlayColor: AppColors.primary.withValues(alpha: 0.15),
                                ),
                                child: Slider(
                                  value: draftRadius.toDouble(),
                                  min: 5,
                                  max: 100,
                                  divisions: 19,
                                  onChanged: (v) => setSt(() => draftRadius = v.round()),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: const [
                                    Text('5 mi', style: TextStyle(color: AppColors.textHint, fontSize: 9)),
                                    Text('25 mi', style: TextStyle(color: AppColors.textHint, fontSize: 9)),
                                    Text('50 mi', style: TextStyle(color: AppColors.textHint, fontSize: 9)),
                                    Text('75 mi', style: TextStyle(color: AppColors.textHint, fontSize: 9)),
                                    Text('100 mi', style: TextStyle(color: AppColors.textHint, fontSize: 9)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [5, 15, 30, 60].map((r) {
                            final on = draftRadius == r;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: r == 60 ? 0 : 8),
                                child: OutlinedButton(
                                  onPressed: () => setSt(() => draftRadius = r),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: on ? AppColors.primary : AppColors.border),
                                    backgroundColor: on ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                                    foregroundColor: on ? AppColors.primary : AppColors.textMuted,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                    '$r mi',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              vm.applyLocation(draftPostcode);
                              vm.setRadius(draftRadius);
                              Navigator.pop(ctx);
                            },
                            child: const Text(
                              'APPLY CHANGES',
                              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    postcodeController.dispose();
  }
}


class _MyQuotes extends StatefulWidget {
  const _MyQuotes({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_MyQuotes> createState() => _MyQuotesState();
}

class _MyQuotesState extends State<_MyQuotes> {
  String _activeTab = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MechanicViewModel>().loadMyQuotes();
    });
  }

  static ({Color fg, Color bg, Color border, String label}) _statusCfg(String rawStatus) {
    return switch (rawStatus) {
      'WAITING' => (
          fg: AppColors.primary,
          bg: AppColors.primary.withValues(alpha: 0.10),
          border: AppColors.primary.withValues(alpha: 0.30),
          label: 'Waiting',
        ),
      'ACCEPTED' => (
          fg: AppColors.green,
          bg: AppColors.green.withValues(alpha: 0.10),
          border: AppColors.green.withValues(alpha: 0.30),
          label: 'Accepted \u2713',
        ),
      _ => (
          fg: AppColors.textMuted,
          bg: AppColors.textMuted.withValues(alpha: 0.10),
          border: AppColors.textMuted.withValues(alpha: 0.20),
          label: _capitalise(rawStatus),
        ),
    };
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

  List<MechanicMyQuote> _filtered(List<MechanicMyQuote> all) {
    if (_activeTab == 'ALL') return all;
    return all.where((q) => q.status == _activeTab).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MechanicViewModel>();
    final tabs = const ['ALL', 'WAITING', 'ACCEPTED', 'EXPIRED'];

    Widget tabButton(String t) {
      final active = _activeTab == t;
      return Expanded(
        child: OutlinedButton(
          onPressed: () => setState(() => _activeTab = t),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: active ? AppColors.primary : const Color(0xFF1E1E1E)),
            backgroundColor: active ? AppColors.primary.withValues(alpha: 0.10) : Colors.transparent,
            foregroundColor: active ? AppColors.primary : AppColors.textMuted,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            t,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Quotes',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (int i = 0; i < tabs.length; i++) ...[
                    tabButton(tabs[i]),
                    if (i != tabs.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(builder: (context) {
            if (vm.myQuotesLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (vm.myQuotesError != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.textMuted, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        vm.myQuotesError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: vm.loadMyQuotes,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          foregroundColor: AppColors.primary,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final items = _filtered(vm.myQuotes);
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _activeTab == 'ALL' ? 'No quotes yet' : 'No ${_capitalise(_activeTab)} quotes',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final q = items[i];
                final cfg = _statusCfg(q.status);
                final tappable = q.canOpenActiveJob;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: InkWell(
                      onTap: tappable ? () => vm.setTab('my-jobs') : null,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        q.jobCode,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        q.truckLine,
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: cfg.bg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: cfg.border),
                                  ),
                                  child: Text(
                                    cfg.label,
                                    style: TextStyle(color: cfg.fg, fontSize: 9, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(q.issue, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  q.amountDisplay,
                                  style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w900),
                                ),
                                if (q.etaLabel != null && q.etaLabel!.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.orange),
                                  const SizedBox(width: 4),
                                  Text(
                                    q.etaLabel!,
                                    style: const TextStyle(color: AppColors.orange, fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                ],
                                const Spacer(),
                                Text(q.submittedLabel, style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
                              ],
                            ),
                            // Accepted banner — text driven by API summaryLine
                            if (tappable && q.summaryLine != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.green.withValues(alpha: 0.20)),
                                ),
                                child: Text(
                                  q.summaryLine!,
                                  style: const TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                            // Resubmit action for expired / declined quotes
                            if (q.canResubmit) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {/* TODO: resubmit flow */},
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.50)),
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text(
                                    'Resubmit Quote',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

class _QuoteScheduleDay {
  const _QuoteScheduleDay({
    required this.key,
    required this.label,
    required this.date,
    required this.isToday,
  });

  final String key;
  final String label;
  final int date;
  final bool isToday;
}

class _QuoteDetailPage extends StatefulWidget {
  const _QuoteDetailPage({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_QuoteDetailPage> createState() => _QuoteDetailPageState();
}

class _QuoteDetailPageState extends State<_QuoteDetailPage> {
  final _quoteCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _submitted = false;
  String _availability = 'Available Now';
  String? _scheduledDate;
  String? _scheduledTime;

  static const _timeSlots = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
  ];

  static List<_QuoteScheduleDay> _buildDays() {
    const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final base = DateTime(2026, 3, 9);
    return List.generate(7, (i) {
      final d = base.add(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return _QuoteScheduleDay(
        key: key,
        label: w[d.weekday - 1],
        date: d.day,
        isToday: i == 0,
      );
    });
  }

  List<_QuoteScheduleDay> get _days => _buildDays();

  @override
  void dispose() {
    _quoteCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Material(
            color: AppColors.card2,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: widget.onBack,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border2),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job Detail',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'TF-8821 · 4 min ago',
                  style: TextStyle(color: Color(0xFF6B6B6B), fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.orange.withValues(alpha: 0.30)),
            ),
            child: const Text(
              'HIGH',
              style: TextStyle(
                color: AppColors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitted(BuildContext context) {
    final amt = _quoteCtrl.text.trim().isEmpty ? '—' : _quoteCtrl.text;
    return ColoredBox(
      color: AppColors.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withValues(alpha: 0.22),
                          blurRadius: 36,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.green, width: 2),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 44),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Quote Submitted!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                  children: [
                    const TextSpan(text: 'Your quote of '),
                    TextSpan(
                      text: '£$amt',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(
                      text:
                          ' has been sent to Logistix Transport. You\'ll be notified when they respond.',
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _submitted = false);
                    context.read<MechanicViewModel>().setTab('my-quotes');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'VIEW MY QUOTES',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _submitted = false);
                  context.read<MechanicViewModel>().setTab('feed');
                },
                child: Text(
                  'Back to Feed',
                  style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.85), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _availabilityChip(String label) {
    final on = _availability == label;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() {
            _availability = label;
            _scheduledDate = null;
            _scheduledTime = null;
          }),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: on ? AppColors.primary : const Color(0xFF1E1E1E),
              ),
              color: on ? AppColors.primary.withValues(alpha: 0.10) : Colors.transparent,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: on ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _submitted = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 18, color: Colors.black),
                  SizedBox(width: 8),
                  Text(
                    'SUBMIT QUOTE',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.4),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: widget.onBack,
            child: Text(
              'Not interested — Skip',
              style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return _buildSubmitted(context);
    }

    final scheduledOn = _availability == 'Scheduled';
    final days = _days;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('VEHICLE & ISSUE'),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _kv('Vehicle', 'Tautliner Semi')),
                          Expanded(child: _kv('Reg', 'CA 456-789')),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _kv('Fleet', 'Logistix Transport')),
                          Expanded(child: _kv('Issue Type', 'Engine / Mechanical')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Description',
                        style: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: 0.9),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Engine overheating — coolant leak suspected. Temperature gauge in the red. '
                        'Driver has pulled over safely on the N1 highway near Midrand.',
                        style: TextStyle(color: Colors.white, fontSize: 12, height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('PHOTOS (2)'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: AppAssets.truckWorkshop,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: AppColors.card2),
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppColors.card2,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.local_shipping_outlined, color: AppColors.textMuted),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.card2,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border2),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_outlined, size: 26, color: AppColors.textHint),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Engine bay',
                                      style: TextStyle(
                                        color: AppColors.textHint.withValues(alpha: 0.85),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('LOCATION'),
                      const SizedBox(height: 12),
                      const TruckFixMapPreview(height: 130, showRoute: true),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(Icons.location_on_rounded, size: 16, color: AppColors.red),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'N1 Highway, km 184, Midrand',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.navigation_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text(
                            '3.2 km from your location',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('SUBMIT YOUR QUOTE'),
                      const SizedBox(height: 14),
                      Text(
                        'QUOTE AMOUNT (GBP)',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _quoteCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.card2,
                          prefixText: '£ ',
                          prefixStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Suggested range: £130 – £200',
                        style: TextStyle(
                          color: AppColors.textHint.withValues(alpha: 0.85),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'NOTES FOR FLEET OPERATOR',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Describe your approach, parts needed...',
                          hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.7)),
                          filled: true,
                          fillColor: AppColors.card2,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'AVAILABILITY',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _availabilityChip('Available Now'),
                          const SizedBox(width: 8),
                          _availabilityChip('In 30 min'),
                          const SizedBox(width: 8),
                          _availabilityChip('In 1 hr'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() {
                            _availability = 'Scheduled';
                            _scheduledDate = null;
                            _scheduledTime = null;
                          }),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _availability == 'Scheduled'
                                    ? AppColors.primary
                                    : const Color(0xFF1E1E1E),
                              ),
                              color: _availability == 'Scheduled'
                                  ? AppColors.primary.withValues(alpha: 0.10)
                                  : Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 15,
                                  color: _availability == 'Scheduled'
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Schedule Date & Time',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _availability == 'Scheduled'
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (scheduledOn) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D0D0D),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF1E1E1E)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SELECT DAY',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: days.map((d) {
                                    final sel = _scheduledDate == d.key;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => setState(() {
                                            _scheduledDate = d.key;
                                            _scheduledTime = null;
                                          }),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: sel ? AppColors.primary : AppColors.border2,
                                              ),
                                              color: sel ? AppColors.primary : AppColors.card2,
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  d.isToday ? 'Today' : d.label,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: sel ? Colors.black : AppColors.textMuted,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${d.date}',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w900,
                                                    color: sel ? Colors.black : Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              if (_scheduledDate != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'SELECT TIME',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    mainAxisSpacing: 6,
                                    crossAxisSpacing: 6,
                                    childAspectRatio: 2.15,
                                  ),
                                  itemCount: _timeSlots.length,
                                  itemBuilder: (context, i) {
                                    final t = _timeSlots[i];
                                    final sel = _scheduledTime == t;
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => setState(() => _scheduledTime = t),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: sel ? AppColors.primary : AppColors.border2,
                                            ),
                                            color: sel ? AppColors.primary : AppColors.card2,
                                          ),
                                          child: Text(
                                            t,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: sel ? Colors.black : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                              if (_scheduledDate != null && _scheduledTime != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${days.firstWhere((e) => e.key == _scheduledDate).isToday ? 'Today' : days.firstWhere((e) => e.key == _scheduledDate).label} · $_scheduledTime',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildFooter(),
      ],
    );
  }
}

class _MyJobsPage extends StatefulWidget {
  const _MyJobsPage({required this.onTracker});

  final VoidCallback onTracker;

  @override
  State<_MyJobsPage> createState() => _MyJobsPageState();
}

class _MyJobsPageState extends State<_MyJobsPage> {
  static const _kBlue = Color(0xFF60A5FA);
  static const _kYellow = Color(0xFFFACC15);
  static const _kAmber = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MechanicViewModel>().loadMyJobs();
    });
  }

  ({String label, Color dot, Color fg, Color bg, Color border, bool pulse})
      _statusCfg(String tone, String label) {
    return switch (tone) {
      'green' => (
          label: label,
          dot: AppColors.green,
          fg: AppColors.green,
          bg: AppColors.green.withValues(alpha: 0.10),
          border: AppColors.green.withValues(alpha: 0.30),
          pulse: false,
        ),
      'blue' => (
          label: label,
          dot: _kBlue,
          fg: _kBlue,
          bg: _kBlue.withValues(alpha: 0.10),
          border: _kBlue.withValues(alpha: 0.30),
          pulse: false,
        ),
      'amber' => (
          label: label,
          dot: _kAmber,
          fg: _kAmber,
          bg: _kAmber.withValues(alpha: 0.10),
          border: _kAmber.withValues(alpha: 0.30),
          pulse: true,
        ),
      'yellow' => (
          label: label,
          dot: _kYellow,
          fg: _kYellow,
          bg: _kYellow.withValues(alpha: 0.10),
          border: _kYellow.withValues(alpha: 0.30),
          pulse: false,
        ),
      _ => (
          label: label,
          dot: AppColors.textMuted,
          fg: AppColors.textMuted,
          bg: AppColors.textMuted.withValues(alpha: 0.08),
          border: AppColors.textMuted.withValues(alpha: 0.20),
          pulse: false,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MechanicViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Jobs',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                vm.myJobsLoading
                    ? 'Loading…'
                    : '${vm.myJobsTotalActive} accepted job${vm.myJobsTotalActive == 1 ? '' : 's'}',
                style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.85), fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(builder: (context) {
            if (vm.myJobsLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (vm.myJobsError != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.textMuted, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        vm.myJobsError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: vm.loadMyJobs,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          foregroundColor: AppColors.primary,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (vm.myActiveJobs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.work_outline, color: AppColors.textMuted, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'No active jobs',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              itemCount: vm.myActiveJobs.length,
              itemBuilder: (context, i) {
                final job = vm.myActiveJobs[i];
                final cfg = _statusCfg(job.statusTone, job.statusLabel);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: widget.onTracker,
                      borderRadius: BorderRadius.circular(14),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          job.jobCode,
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          job.truck,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          job.fleet,
                                          style: TextStyle(
                                            color: AppColors.textSecondary.withValues(alpha: 0.75),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: cfg.bg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: cfg.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _StatusDot(color: cfg.dot, pulse: cfg.pulse),
                                        const SizedBox(width: 6),
                                        Text(
                                          cfg.label,
                                          style: TextStyle(
                                            color: cfg.fg,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                job.issue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Text(
                                    job.pay,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (job.scheduledForLabel != null) ...[
                                    const SizedBox(width: 12),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.access_time_rounded, size: 14, color: cfg.fg),
                                        const SizedBox(width: 4),
                                        Text(
                                          job.scheduledForLabel!,
                                          style: TextStyle(
                                            color: cfg.fg,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else if (job.etaMinutes != null && job.etaMinutes! > 0) ...[
                                    const SizedBox(width: 12),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.timer_outlined, size: 14, color: cfg.fg),
                                        const SizedBox(width: 4),
                                        Text(
                                          'ETA ${job.etaMinutes} min',
                                          style: TextStyle(
                                            color: cfg.fg,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const Spacer(),
                                  if (job.distanceLabel != null) ...[
                                    Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                                    const SizedBox(width: 2),
                                    Text(
                                      job.distanceLabel!,
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                    ),
                                    const SizedBox(width: 2),
                                  ],
                                  Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color, required this.pulse});

  final Color color;
  final bool pulse;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Opacity(
          opacity: 0.45 + 0.55 * _c.value,
          child: child,
        );
      },
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _TrackerStep {
  const _TrackerStep({
    required this.id,
    required this.shortLabel,
    required this.icon,
    required this.color,
  });

  final int id;
  final String shortLabel;
  final IconData icon;
  final Color color;
}

class _JobTrackerPage extends StatefulWidget {
  const _JobTrackerPage({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_JobTrackerPage> createState() => _JobTrackerPageState();
}

class _JobTrackerPageState extends State<_JobTrackerPage> {
  int _step = 0;
  final _callOutCtrl = TextEditingController(text: '85');
  final _labourHoursCtrl = TextEditingController(text: '1.5');
  final _notesCtrl = TextEditingController();
  final _reviewCtrl = TextEditingController();

  final List<({TextEditingController name, TextEditingController cost})> _parts = [];
  final List<String> _photos = [];

  bool _showReview = false;
  int _rating = 0;
  bool _reviewSubmitted = false;

  static const _labels = <String>[
    'Start Journey',
    'On Route',
    'Start Work',
    'In Progress',
    'Job Completed',
  ];

  static const _steps = <_TrackerStep>[
    _TrackerStep(id: 0, shortLabel: 'Journey', icon: Icons.navigation_rounded, color: Color(0xFF60A5FA)),
    _TrackerStep(id: 1, shortLabel: 'Arrived', icon: Icons.location_on_rounded, color: AppColors.primary),
    _TrackerStep(id: 2, shortLabel: 'Work', icon: Icons.build_rounded, color: AppColors.orange),
    _TrackerStep(id: 3, shortLabel: 'Progress', icon: Icons.timer_rounded, color: AppColors.orange),
    _TrackerStep(id: 4, shortLabel: 'Done', icon: Icons.check_circle_rounded, color: AppColors.green),
  ];

  Color get _stepDot => switch (_step) {
        0 => const Color(0xFF60A5FA),
        1 => AppColors.primary,
        2 => AppColors.orange,
        3 => AppColors.orange,
        _ => AppColors.green,
      };

  @override
  void dispose() {
    _callOutCtrl.dispose();
    _labourHoursCtrl.dispose();
    _notesCtrl.dispose();
    _reviewCtrl.dispose();
    for (final p in _parts) {
      p.name.dispose();
      p.cost.dispose();
    }
    super.dispose();
  }

  double get _callOut => double.tryParse(_callOutCtrl.text.trim()) ?? 0;
  double get _labourHours => double.tryParse(_labourHoursCtrl.text.trim()) ?? 0;
  static const double _labourRate = 65;
  double get _labourTotal => _labourHours * _labourRate;
  double get _partsTotal =>
      _parts.fold<double>(0, (s, p) => s + (double.tryParse(p.cost.text.trim()) ?? 0));
  double get _totalInvoice => _callOut + _labourTotal + _partsTotal;

  Widget _header() {
    final accent = _steps[_step].color;
    final pulse = _step == 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Material(
            color: AppColors.card2,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: widget.onBack,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border2),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusDot(color: _stepDot, pulse: pulse),
                    const SizedBox(width: 6),
                    Text(
                      _labels[_step].toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'TF-8797 · Atlas Haulage Ltd',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, height: 1.05),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.card2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border2),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_rounded, size: 16, color: accent),
                const SizedBox(width: 6),
                Text(
                  '14:22',
                  style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _steps.length; i++) ...[
            _TimelineNode(
              step: _steps[i],
              currentStep: _step,
            ),
            if (i != _steps.length - 1)
              Expanded(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.only(bottom: 14),
                  color: i < _step ? AppColors.primary : AppColors.border2,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _jobCard({required bool orangeAccent}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (orangeAccent ? AppColors.orange : AppColors.primary).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (orangeAccent ? AppColors.orange : AppColors.primary).withValues(alpha: 0.20),
              ),
            ),
            child: Icon(
              orangeAccent ? Icons.link_rounded : Icons.local_shipping_rounded,
              color: orangeAccent ? AppColors.orange : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flatbed · WC 678-123',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2),
                Text(
                  'Atlas Haulage Ltd · +44 161 400 9988',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                SizedBox(height: 6),
                Text(
                  'Right rear dual tyre blowout, roadside...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling is not wired up in this prototype.')),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(Icons.call_rounded, color: Colors.black, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionCard() {
    final cfg = switch (_step) {
      0 => (bg: const Color(0xFF60A5FA).withValues(alpha: 0.06), border: const Color(0xFF60A5FA).withValues(alpha: 0.22), icon: _steps[0].icon, color: _steps[0].color, title: _labels[0], body: 'Tap "Start Journey" below to begin navigating to the breakdown location.'),
      1 => (bg: AppColors.primary.withValues(alpha: 0.06), border: AppColors.primary.withValues(alpha: 0.22), icon: _steps[1].icon, color: _steps[1].color, title: _labels[1], body: 'You\'re on route. Tap "I\'ve Arrived" when you reach the location.'),
      _ => (bg: AppColors.orange.withValues(alpha: 0.06), border: AppColors.orange.withValues(alpha: 0.22), icon: _steps[2].icon, color: _steps[2].color, title: _labels[2], body: 'Begin the repair. Tap the button below when you start work.'),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cfg.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(cfg.icon, size: 18, color: cfg.color),
              const SizedBox(width: 8),
              Text(
                cfg.title,
                style: TextStyle(color: cfg.color, fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            cfg.body,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _jobInvoiceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'JOB INVOICE',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'CALL OUT CHARGE',
            style: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _callOutCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.card2,
              prefixText: '£  ',
              prefixStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Text(
            'LABOUR TIME (HOURS)',
            style: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _labourHoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.card2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.card2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border2),
                ),
                child: const Text(
                  '@ £65/hr',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Labour total: £${_labourTotal.toStringAsFixed(2)}',
            style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.9), fontSize: 10),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'PARTS USED',
                style: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.9,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() {
                    _parts.add((name: TextEditingController(), cost: TextEditingController()));
                  }),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.card2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border2),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        const Text('Add Part', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_parts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text('No parts added', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    'Click "Add Part" to itemize parts costs',
                    style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.85), fontSize: 10),
                  ),
                ],
              ),
            )
          else ...[
            for (int i = 0; i < _parts.length; i++) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _parts[i].name,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            decoration: InputDecoration(
                              hintText: 'Part name (e.g., Radiator hose)',
                              hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.8), fontSize: 11),
                              filled: true,
                              fillColor: AppColors.card2,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.border2),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Material(
                          color: AppColors.card2,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () => setState(() {
                              _parts[i].name.dispose();
                              _parts[i].cost.dispose();
                              _parts.removeAt(i);
                            }),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border2),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _parts[i].cost,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      decoration: InputDecoration(
                        prefixText: '£ ',
                        prefixStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 11),
                        hintText: '0.00',
                        hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.8), fontSize: 11),
                        filled: true,
                        fillColor: AppColors.card2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              'Parts total: £${_partsTotal.toStringAsFixed(2)}',
              style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.9), fontSize: 10),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border2))),
            child: Row(
              children: [
                const Text('Total Invoice', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  '£${_totalInvoice.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _doneSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.green, width: 2),
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 30),
          ),
          const SizedBox(height: 10),
          const Text(
            'Great work!',
            style: TextStyle(color: AppColors.green, fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Job marked complete · Awaiting fleet confirmation',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _doneEarningsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_money_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'JOB EARNINGS',
                style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.8),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _kvRow('Call Out Charge', '£${_callOut.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _kvRow('Labour (${_labourHoursCtrl.text.trim()} hrs @ £65/hr)', '£${_labourTotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _kvRow('Parts', '£${_partsTotal.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border2))),
            child: Row(
              children: [
                const Text(
                  'TOTAL PAYOUT',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  '£${_totalInvoice.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Payment pending fleet confirmation',
              style: TextStyle(color: AppColors.textHint, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _doneJobSummaryCard() {
    Widget row(String label, String value) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'JOB SUMMARY',
            style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.8),
          ),
          const SizedBox(height: 14),
          row('Vehicle', 'Flatbed · WC 678-123'),
          const SizedBox(height: 10),
          row('Fleet', 'Atlas Haulage Ltd'),
          const SizedBox(height: 10),
          row('Issue', 'Right rear dual tyre blowout'),
          const SizedBox(height: 10),
          row('Completed', '9 Mar 2026 · 16:44'),
          const SizedBox(height: 10),
          row('Duration', '1 hr 22 min'),
        ],
      ),
    );
  }

  Widget _doneAwaitingRatingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
            ),
            child: const Icon(Icons.star_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Awaiting fleet rating', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text(
                  'You\'ll be notified once they leave a review',
                  style: TextStyle(color: AppColors.textHint, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewOverlay() {
    if (!_showReview) return const SizedBox.shrink();

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.90),
        child: InkWell(
          onTap: _reviewSubmitted ? null : () => setState(() => _showReview = false),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: InkWell(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E0E),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                  border: Border(top: BorderSide(color: AppColors.border2)),
                ),
                child: SafeArea(
                  top: false,
                  child: _reviewSubmitted
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(10))),
                            const SizedBox(height: 22),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.green.withValues(alpha: 0.30)),
                              ),
                              child: const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 34),
                            ),
                            const SizedBox(height: 14),
                            const Text('Review Submitted!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            const Text('Thank you for your feedback', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            const SizedBox(height: 10),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(10))),
                            const SizedBox(height: 16),
                            const Text('Rate Fleet Operator', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            const Text(
                              'How was your experience with Atlas Haulage Ltd?',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int i = 1; i <= 5; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: InkWell(
                                      onTap: () => setState(() => _rating = i),
                                      child: Icon(
                                        i <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                                        size: 34,
                                        color: i <= _rating ? AppColors.primary : const Color(0xFF374151),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'FEEDBACK (OPTIONAL)',
                                style: TextStyle(
                                  color: AppColors.textMuted.withValues(alpha: 0.95),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _reviewCtrl,
                              maxLines: 3,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Share your experience with this fleet operator...',
                                hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.75)),
                                filled: true,
                                fillColor: AppColors.card2,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.border2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _rating == 0
                                    ? null
                                    : () async {
                                        setState(() => _reviewSubmitted = true);
                                        await Future<void>.delayed(const Duration(milliseconds: 1500));
                                        if (!mounted) return;
                                        setState(() {
                                          _showReview = false;
                                          _reviewSubmitted = false;
                                        });
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.30),
                                  foregroundColor: Colors.black,
                                  disabledForegroundColor: Colors.black.withValues(alpha: 0.40),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text(
                                  'SUBMIT REVIEW',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _showReview = false),
                              child: Text('Skip for now', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 12)),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cta() {
    String label;
    Color bg;
    Color fg = Colors.black;
    IconData? icon;

    switch (_step) {
      case 0:
        label = 'START JOURNEY →';
        bg = AppColors.primary;
      case 1:
        label = 'I\'VE ARRIVED ✓';
        bg = AppColors.primary;
      case 2:
        label = 'START WORK 🔧';
        bg = AppColors.orange;
      case 3:
        label = 'COMPLETE JOB ✓';
        bg = AppColors.green;
        icon = Icons.flag_rounded;
      default:
        label = 'BACK TO MY JOBS';
        bg = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            if (_step == 3) {
              setState(() => _step = 4);
              await Future<void>.delayed(const Duration(milliseconds: 500));
              if (!mounted) return;
              setState(() => _showReview = true);
              return;
            }
            setState(() {
              if (_step < 4) _step += 1;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Colors.black),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showMapBlock = _step <= 2;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            _timeline(),
            Expanded(
              child: showMapBlock
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TruckFixMapPreview(height: 125, showRoute: true, liveLabel: false),
                          const SizedBox(height: 12),
                          _jobCard(orangeAccent: false),
                          const SizedBox(height: 12),
                          _instructionCard(),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _jobCard(orangeAccent: true),
                          const SizedBox(height: 12),
                          if (_step == 3) ...[
                            _jobInvoiceCard(),
                            const SizedBox(height: 14),
                            Text(
                              'REPAIR NOTES',
                              style: TextStyle(
                                color: AppColors.textMuted.withValues(alpha: 0.95),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.9,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _notesCtrl,
                              maxLines: 4,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Describe work done, parts replaced, findings…',
                                hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.75)),
                                filled: true,
                                fillColor: AppColors.card2,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.border2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'COMPLETION PHOTOS',
                                  style: TextStyle(
                                    color: AppColors.textMuted.withValues(alpha: 0.95),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.9,
                                  ),
                                ),
                                Text('Optional · up to 5', style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.9), fontSize: 10)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _PhotoPickerButton(
                                    icon: Icons.camera_alt_outlined,
                                    label: 'Camera',
                                    onTap: () => setState(() {
                                      if (_photos.length < 5) _photos.add(AppAssets.truckWorkshop);
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _PhotoPickerButton(
                                    icon: Icons.inventory_2_outlined,
                                    label: 'Gallery',
                                    onTap: () => setState(() {
                                      if (_photos.length < 5) _photos.add(AppAssets.truckWorkshop);
                                    }),
                                  ),
                                ),
                              ],
                            ),
                            if (_photos.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (int i = 0; i < _photos.length; i++)
                                    _PhotoThumb(
                                      url: _photos[i],
                                      onRemove: () => setState(() => _photos.removeAt(i)),
                                    ),
                                  if (_photos.length < 5)
                                    _PhotoAddStub(
                                      onTap: () => setState(() => _photos.add(AppAssets.truckWorkshop)),
                                    ),
                                ],
                              ),
                            ],
                          ] else ...[
                            _doneSuccessCard(),
                            const SizedBox(height: 12),
                            _doneEarningsCard(),
                            const SizedBox(height: 12),
                            _doneJobSummaryCard(),
                            const SizedBox(height: 12),
                            _doneAwaitingRatingCard(),
                          ],
                        ],
                      ),
                    ),
            ),
            _cta(),
          ],
        ),
        _reviewOverlay(),
      ],
    );
  }
}

class _PhotoPickerButton extends StatelessWidget {
  const _PhotoPickerButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E1E1E)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.url, required this.onRemove});
  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 68,
            height: 68,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppColors.card2),
              errorWidget: (_, __, ___) => Container(color: AppColors.card2),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.black.withValues(alpha: 0.70),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 18,
                height: 18,
                child: Icon(Icons.close_rounded, size: 12, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoAddStub extends StatelessWidget {
  const _PhotoAddStub({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border2, style: BorderStyle.solid),
          ),
          child: const Center(child: Icon(Icons.play_arrow_rounded, color: AppColors.textHint)),
        ),
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({required this.step, required this.currentStep});

  final _TrackerStep step;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final done = step.id < currentStep;
    final cur = step.id == currentStep;
    final border = done || cur ? AppColors.primary : AppColors.border2;
    final bg = done
        ? AppColors.primary
        : cur
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.card2;

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.black)
              : Icon(step.icon, size: 14, color: cur ? AppColors.primary : AppColors.textHint),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 44,
          child: Text(
            step.shortLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: cur ? AppColors.primary : done ? AppColors.textMuted : AppColors.textHint,
            ),
          ),
        ),
      ],
    );
  }
}

class _EarnJob {
  const _EarnJob({
    required this.id,
    required this.truck,
    required this.issue,
    required this.fleet,
    required this.date,
    required this.gross,
    required this.net,
    required this.rating,
    required this.hours,
  });

  final String id;
  final String truck;
  final String issue;
  final String fleet;
  final String date;
  final int gross;
  final int net;
  final int rating;
  final String hours;
}

class _MechanicEarnings extends StatefulWidget {
  const _MechanicEarnings({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_MechanicEarnings> createState() => _MechanicEarningsState();
}

class _MechanicEarningsState extends State<_MechanicEarnings> {
  // Completed jobs list remains demo until a dedicated jobs-history API is added.
  static const _jobs = <_EarnJob>[
    _EarnJob(id: 'TF-8810', truck: 'Rigid 8T · GP 221-560', issue: 'Fuel system fault', fleet: 'Logistix Transport', date: '7 Mar 2026', gross: 185, net: 163, rating: 5, hours: '1h 45m'),
    _EarnJob(id: 'TF-8797', truck: 'Flatbed · WC 334-112', issue: 'Tyre replacement x2', fleet: 'Peak Haulage Ltd', date: '5 Mar 2026', gross: 140, net: 123, rating: 5, hours: '55m'),
    _EarnJob(id: 'TF-8782', truck: 'Tautliner · CA 100-221', issue: 'Air brake adjustment', fleet: 'Swift Freight', date: '3 Mar 2026', gross: 220, net: 194, rating: 4, hours: '2h 10m'),
    _EarnJob(id: 'TF-8771', truck: 'Tanker · KZN 44-310', issue: 'Coolant system flush', fleet: 'Bulk Trans UK', date: '28 Feb 2026', gross: 165, net: 145, rating: 5, hours: '1h 20m'),
    _EarnJob(id: 'TF-8760', truck: 'Rigid 18T · WC 887-002', issue: 'Engine diagnostics', fleet: 'Logistix Transport', date: '25 Feb 2026', gross: 95, net: 84, rating: 4, hours: '40m'),
    _EarnJob(id: 'TF-8744', truck: 'Flatbed · GP 551-889', issue: 'Suspension repair', fleet: 'Peak Haulage Ltd', date: '21 Feb 2026', gross: 310, net: 273, rating: 5, hours: '3h 05m'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MechanicViewModel>().loadEarnings();
    });
  }

  static String _fmtMoney(int v) => v >= 1000 ? '£${(v / 1000).toStringAsFixed(1)}k' : '£$v';

  Widget _summaryCard(String value, String label, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.6),
          ),
          const SizedBox(height: 2),
          Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _barChart(List<MechanicBarMonth> bars) {
    const chartH = 56.0;
    // Guard: if all bars are zero, use a minimum scale so bars still render
    final rawMax = bars.isEmpty ? 1 : bars.map((b) => b.net).reduce(math.max);
    final maxBar = rawMax > 0 ? rawMax : 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'MONTHLY NET INCOME',
                  style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ),
              Text('Last 6 months', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.85), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.map((bar) {
                final pct = (bar.net / maxBar) * 100;
                final h = chartH * (math.max(pct, 4) / 100);
                final cur = bar.current;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _fmtMoney(bar.net),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: cur ? AppColors.primary : const Color(0xFF4B5563),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: chartH,
                          width: double.infinity,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: h,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: cur ? AppColors.primary : const Color(0xFF222222),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bar.shortLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: cur ? AppColors.primary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '12% platform fee already deducted from net figures',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobCard(_EarnJob job) {
    final fee = job.gross - job.net;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(job.id, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace')),
                          Text(' · ', style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.8), fontSize: 10)),
                          Text(job.date, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(job.truck, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(job.issue, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('£${job.net}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 15)),
                    const Text('net earned', style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ...List.generate(5, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(Icons.star, size: 12, color: i < job.rating ? AppColors.primary : const Color(0xFF374151)),
                  );
                }),
                Text(' · ', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 10)),
                Expanded(
                  child: Text(
                    job.fleet,
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(' · ', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 10)),
                const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 2),
                Text(job.hours, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Divider(height: 1, color: AppColors.border),
            ),
            const SizedBox(height: 10),
            Material(
              color: AppColors.card2,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _showInvoiceSheet(job, fee),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border2),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gross', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                          Text('£${job.gross}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Fee (12%)', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                          Text('-£$fee', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Divider(height: 1, color: Color(0xFF2A2A2A)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900)),
                          Text('£${job.net}', style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Divider(height: 1, color: Color(0xFF1E1E1E)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.description_outlined, size: 16, color: AppColors.textMuted.withValues(alpha: 0.85)),
                          const SizedBox(width: 6),
                          Text(
                            'View Invoice',
                            style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.95), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInvoiceSheet(_EarnJob job, int fee) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border2, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const SizedBox(height: 16),
              Text('INV-${job.id}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              Text(job.date, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 16),
              Text(job.truck, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              Text(job.issue, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              _sheetRow('Gross', '£${job.gross}'),
              _sheetRow('Fee (12%)', '-£$fee'),
              const Divider(color: AppColors.border),
              _sheetRow('Net', '£${job.net}', highlight: true),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetRow(String k, String v, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: highlight ? AppColors.primary : AppColors.textMuted, fontWeight: highlight ? FontWeight.w900 : FontWeight.w400, fontSize: 12)),
          Text(v, style: TextStyle(color: highlight ? AppColors.primary : Colors.white, fontWeight: highlight ? FontWeight.w900 : FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MechanicViewModel>();
    final summary = vm.earningsSummary;
    final monthLabel = summary?.currentMonthLabel ?? 'This month';

    return ColoredBox(
      color: AppColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                Material(
                  color: AppColors.card2,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: widget.onBack,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border2),
                      ),
                      child: const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MECHANIC',
                      style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Earnings & Invoices',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                if (vm.earningsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                  )
                else if (vm.earningsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.textMuted, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            vm.earningsError!,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: vm.loadEarnings,
                          child: const Text('Retry', style: TextStyle(color: AppColors.primary, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(child: _summaryCard(
                      _fmtMoney(summary?.monthGross ?? 0),
                      '$monthLabel Gross',
                      'Before platform fee',
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _summaryCard(
                      _fmtMoney(summary?.monthNet ?? 0),
                      '$monthLabel Net',
                      'After 12% fee',
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _summaryCard(
                      _fmtMoney(summary?.allTimeNet ?? 0),
                      'All-time',
                      'Net since Mar 2026',
                    )),
                  ],
                ),
                const SizedBox(height: 16),
                _barChart(summary?.bars ?? []),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'COMPLETED JOBS',
                        style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                      ),
                    ),
                    Text('${_jobs.length} jobs', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 10),
                ..._jobs.map(_jobCard),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MechanicEditProfile extends StatefulWidget {
  const _MechanicEditProfile({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_MechanicEditProfile> createState() => _MechanicEditProfileState();
}

class _MechanicEditProfileState extends State<_MechanicEditProfile> {
  static const int _origHourly = 75;
  static const int _origEmergency = 95;

  final _nameCtrl = TextEditingController(text: 'James Mitchell');
  final _phoneCtrl = TextEditingController(text: '+44 7734 567 890');
  final _emailCtrl = TextEditingController(text: 'themba@truckfix.co.uk');
  final _hourlyCtrl = TextEditingController(text: '75');
  final _emergencyCtrl = TextEditingController(text: '95');
  final _bankNameCtrl = TextEditingController(text: 'Barclays');
  final _accountCtrl = TextEditingController(text: '12345678');
  final _sortCtrl = TextEditingController(text: '20-14-55');
  final _billingCtrl = TextEditingController(text: '14 Workshop Lane, Manchester M1 2AB');
  final _vatCtrl = TextEditingController(text: 'GB 345 7821 00');

  /// 'yes' | 'no' — matches React select.
  String _vatRegistered = 'yes';

  bool _showReapproval = false;

  bool get _ratesChanged {
    final h = int.tryParse(_hourlyCtrl.text.trim());
    final e = int.tryParse(_emergencyCtrl.text.trim());
    return (h ?? _origHourly) != _origHourly || (e ?? _origEmergency) != _origEmergency;
  }

  void _onRateFieldChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _hourlyCtrl.addListener(_onRateFieldChanged);
    _emergencyCtrl.addListener(_onRateFieldChanged);
  }

  @override
  void dispose() {
    _hourlyCtrl.removeListener(_onRateFieldChanged);
    _emergencyCtrl.removeListener(_onRateFieldChanged);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _hourlyCtrl.dispose();
    _emergencyCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountCtrl.dispose();
    _sortCtrl.dispose();
    _billingCtrl.dispose();
    _vatCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDec({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
      filled: true,
      fillColor: AppColors.card2,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.60)),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6,
        ),
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _inputDec(),
        ),
      ],
    );
  }

  Widget _moneyField({
    required String label,
    required TextEditingController controller,
    String? helperBelow,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _inputDec().copyWith(
            prefixText: '£ ',
            prefixStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        if (helperBelow != null) ...[
          const SizedBox(height: 6),
          Text(helperBelow, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],
      ],
    );
  }

  Widget _ratesWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Changing rates requires re-approval. You won't receive new jobs until approved (2-4 hrs).",
              style: TextStyle(color: AppColors.primary, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reapprovalScreen() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 20),
          const Text(
            'Profile Under Review',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
          ),
          const SizedBox(height: 10),
          const Text(
            "You've changed your rates. Your profile must be re-approved by TruckFix before you can receive new jobs.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: widget.onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'I UNDERSTAND',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Approval typically takes 2-4 business hours',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _onSave() {
    if (_ratesChanged) {
      setState(() => _showReapproval = true);
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showReapproval) {
      return ColoredBox(
        color: AppColors.bg,
        child: SafeArea(child: _reapprovalScreen()),
      );
    }

    return ColoredBox(
      color: AppColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                Material(
                  color: AppColors.card2,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: widget.onDone,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border2),
                      ),
                      child: const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MECHANIC',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Edit Profile',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PERSONAL DETAILS',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _textField(label: 'FULL NAME', controller: _nameCtrl),
                  const SizedBox(height: 14),
                  _textField(label: 'PHONE', controller: _phoneCtrl, keyboardType: TextInputType.phone),
                  const SizedBox(height: 14),
                  _textField(label: 'EMAIL', controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  const Text(
                    'RATES & COVERAGE',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_ratesChanged) _ratesWarning(),
                  _moneyField(label: 'HOURLY RATE (£)', controller: _hourlyCtrl),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Text(
                              'EMERGENCY HOURLY RATE (£)',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(optional)',
                              style: TextStyle(
                                color: AppColors.textHint.withValues(alpha: 0.9),
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextField(
                        controller: _emergencyCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDec().copyWith(
                          prefixText: '£ ',
                          prefixStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Higher rate for urgent emergency callouts',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  const Text(
                    'BANK & BILLING',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _textField(label: 'BANK NAME', controller: _bankNameCtrl),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('ACCOUNT NUMBER'),
                      TextField(
                        controller: _accountCtrl,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDec().copyWith(
                          suffixIcon: const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(Icons.lock_outline, color: Color(0xFF4B5563), size: 18),
                          ),
                          suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _textField(label: 'SORT CODE', controller: _sortCtrl),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: Color(0xFF1E1E1E)),
                  ),
                  _textField(label: 'BILLING ADDRESS', controller: _billingCtrl),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Text(
                              'VAT NUMBER',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(if applicable)',
                              style: TextStyle(
                                color: AppColors.textHint.withValues(alpha: 0.95),
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextField(
                        controller: _vatCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDec(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('VAT REGISTERED?'),
                      DropdownButtonFormField<String>(
                        key: ValueKey<String>(_vatRegistered),
                        initialValue: _vatRegistered,
                        dropdownColor: AppColors.card2,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDec().copyWith(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                        items: const [
                          DropdownMenuItem(
                            value: 'yes',
                            child: Text('Yes — I am VAT registered', overflow: TextOverflow.ellipsis),
                          ),
                          DropdownMenuItem(
                            value: 'no',
                            child: Text('No — Not VAT registered', overflow: TextOverflow.ellipsis),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _vatRegistered = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline, size: 14, color: Color(0xFF4B5563)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Bank details are encrypted and stored securely. TruckFix never shares your financial data.',
                          style: TextStyle(color: Color(0xFF4B5563), fontSize: 10, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.bg,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'SAVE CHANGES',
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onDone,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodItem {
  _PaymentMethodItem({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expires,
    required this.isDefault,
  });

  final String id;
  final String brand;
  final String last4;
  final String expires;
  bool isDefault;
}

class _MechPayment extends StatefulWidget {
  const _MechPayment({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_MechPayment> createState() => _MechPaymentState();
}

class _MechPaymentState extends State<_MechPayment> {
  late List<_PaymentMethodItem> _cards;

  @override
  void initState() {
    super.initState();
    _cards = [
      _PaymentMethodItem(id: 'visa', brand: 'Visa', last4: '4242', expires: '12/26', isDefault: true),
      _PaymentMethodItem(id: 'mc', brand: 'Mastercard', last4: '8888', expires: '09/25', isDefault: false),
    ];
  }

  void _setDefault(String id) {
    setState(() {
      for (final c in _cards) {
        c.isDefault = c.id == id;
      }
    });
  }

  void _remove(String id) {
    setState(() {
      final wasDefault = _cards.firstWhere((c) => c.id == id).isDefault;
      _cards.removeWhere((c) => c.id == id);
      if (_cards.isNotEmpty && wasDefault) {
        _cards.first.isDefault = true;
      }
    });
  }

  void _addCard() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add card flow — connect to your payment provider')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 20, 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                Material(
                  color: AppColors.card2,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border2),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Payment Methods',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                for (final card in _cards) ...[
                  _paymentCard(card),
                  const SizedBox(height: 14),
                ],
                _DashedAddCardButton(onTap: _addCard),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(_PaymentMethodItem card) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.credit_card, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${card.brand} •••• ${card.last4}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text('Expires ${card.expires}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              if (card.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.primary, width: 1),
                  ),
                  child: const Text(
                    'DEFAULT',
                    style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (card.isDefault)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: Material(
                color: const Color(0xFF2A1010),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _remove(card.id),
                  borderRadius: BorderRadius.circular(12),
                  child: const Center(
                    child: Text(
                      'REMOVE',
                      style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2),
                    ),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: Material(
                      color: AppColors.card2,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _setDefault(card.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border2),
                          ),
                          child: const Text(
                            'SET DEFAULT',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: Material(
                      color: const Color(0xFF2A1010),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _remove(card.id),
                        borderRadius: BorderRadius.circular(12),
                        child: const Center(
                          child: Text(
                            'REMOVE',
                            style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DashedAddCardButton extends StatelessWidget {
  const _DashedAddCardButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: _DashedRoundedRectPainter(color: AppColors.border2, radius: 14),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  '+ ADD NEW CARD',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  _DashedRoundedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final ui.PathMetric m in path.computeMetrics()) {
      var d = 0.0;
      const dash = 5.0;
      const gap = 4.0;
      while (d < m.length) {
        final len = math.min(dash, m.length - d);
        canvas.drawPath(m.extractPath(d, d + len), paint);
        d += len + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _MechanicProfile extends StatefulWidget {
  const _MechanicProfile({
    required this.onEarnings,
    required this.onEdit,
    required this.onPayment,
    required this.onHelp,
    required this.onLogout,
  });

  final VoidCallback onEarnings;
  final VoidCallback onEdit;
  final VoidCallback onPayment;
  final VoidCallback onHelp;
  final VoidCallback onLogout;

  @override
  State<_MechanicProfile> createState() => _MechanicProfileState();
}

class _MechanicProfileState extends State<_MechanicProfile> {
  bool _notifEnabled = true;
  int _notifRadius = 25;
  bool _notifNewJobs = true;
  bool _notifJobUpdates = true;
  bool _notifPayments = true;
  bool _notifSystem = false;

  @override
  Widget build(BuildContext context) {
    const radii = [5, 10, 25, 50];

    Widget stat(String value, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      );
    }

    Widget kv(String k, String v) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    Widget notifTypeRow({
      required IconData icon,
      required String label,
      required bool on,
      required VoidCallback onToggle,
    }) {
      return Material(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E1E1E)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: on ? AppColors.primary : AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: on ? Colors.white : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: on ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: on ? AppColors.primary : const Color(0xFF333333), width: 2),
                  ),
                  child: on ? const Icon(Icons.check, size: 12, color: Colors.black, weight: 900) : null,
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget profileShortcut({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E1E1E)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // Hero
        Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                    imageUrl: AppAssets.mechanicPortrait,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.bg, width: 2),
                    ),
                    child: const Center(
                      child: Text('✓', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Themba Dlamini', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < 5; i++)
                  const Padding(
                    padding: EdgeInsets.only(right: 3),
                    child: Icon(Icons.star, size: 16, color: AppColors.primary),
                  ),
                const SizedBox(width: 4),
                const Text('4.9', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: stat('184', 'Jobs Done')),
            const SizedBox(width: 10),
            Expanded(child: stat('4.9', 'Avg Rating')),
            const SizedBox(width: 10),
            Expanded(child: stat('6 min', 'Response')),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: widget.onEdit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.6)),
          ),
        ),
        const SizedBox(height: 14),

        // Rates & Coverage
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                child: const Text(
                  'RATES & COVERAGE',
                  style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    kv('Hourly Rate', '£75 / hr'),
                    const SizedBox(height: 10),
                    kv('Emergency Rate', '£95 / hr'),
                    const SizedBox(height: 10),
                    kv('Call-out Fee', '£35'),
                    const SizedBox(height: 10),
                    kv('Service Radius', '50 mi'),
                    const SizedBox(height: 10),
                    kv('Base Location', 'Manchester, M1'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Push Notifications
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                child: const Text(
                  'PUSH NOTIFICATIONS',
                  style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _notifEnabled ? AppColors.primary.withValues(alpha: 0.15) : AppColors.border,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: _notifEnabled ? AppColors.primary : AppColors.textMuted,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Enable Notifications', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            _notifEnabled ? 'You are receiving job alerts' : 'Tap to turn on job alerts',
                            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _notifEnabled,
                      onChanged: (v) => setState(() => _notifEnabled = v),
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: Colors.white,
                    ),
                  ],
                ),
              ),
              if (_notifEnabled) ...[
                const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Alert Radius', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          Text('$_notifRadius mi', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (int i = 0; i < radii.length; i++) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _notifRadius = radii[i]),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: _notifRadius == radii[i] ? AppColors.primary : AppColors.border2),
                                  backgroundColor: _notifRadius == radii[i] ? AppColors.primary : AppColors.card2,
                                  foregroundColor: _notifRadius == radii[i] ? Colors.black : const Color(0xFF9CA3AF),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  '${radii[i]} mi',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            if (i != radii.length - 1) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "You'll be notified of breakdown jobs within $_notifRadius mi of Manchester M1",
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'NOTIFY ME ABOUT',
                        style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                      ),
                      const SizedBox(height: 8),
                      notifTypeRow(
                        icon: Icons.work_outline,
                        label: 'New breakdown jobs near me',
                        on: _notifNewJobs,
                        onToggle: () => setState(() => _notifNewJobs = !_notifNewJobs),
                      ),
                      const SizedBox(height: 6),
                      notifTypeRow(
                        icon: Icons.check_circle_outline,
                        label: 'Job accepted / declined',
                        on: _notifJobUpdates,
                        onToggle: () => setState(() => _notifJobUpdates = !_notifJobUpdates),
                      ),
                      const SizedBox(height: 6),
                      notifTypeRow(
                        icon: Icons.payments_outlined,
                        label: 'Payment received',
                        on: _notifPayments,
                        onToggle: () => setState(() => _notifPayments = !_notifPayments),
                      ),
                      const SizedBox(height: 6),
                      notifTypeRow(
                        icon: Icons.shield_outlined,
                        label: 'System & app alerts',
                        on: _notifSystem,
                        onToggle: () => setState(() => _notifSystem = !_notifSystem),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Bank & Billing
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                child: const Text(
                  'BANK & BILLING',
                  style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    kv('Bank', 'Barclays'),
                    const SizedBox(height: 10),
                    kv('Account', '•••• •••• 4521'),
                    const SizedBox(height: 10),
                    kv('Sort Code', '20-14-55'),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Color(0xFF1E1E1E)),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Billing Address', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '14 Workshop Lane, Manchester M1 2AB',
                            textAlign: TextAlign.right,
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    kv('VAT Number', 'GB 345 7821 00'),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('VAT Registered', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.green.withValues(alpha: 0.20)),
                          ),
                          child: const Text(
                            'YES',
                            style: TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        profileShortcut(
          icon: Icons.trending_up,
          title: 'Earnings & Invoices',
          subtitle: 'Completed jobs, monthly income & PDF invoices',
          onTap: widget.onEarnings,
        ),
        const SizedBox(height: 10),
        profileShortcut(
          icon: Icons.credit_card,
          title: 'Payment Methods',
          subtitle: 'Manage cards for expenses & receipts',
          onTap: widget.onPayment,
        ),
        const SizedBox(height: 10),
        profileShortcut(
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'Send a message to the TruckFix team',
          onTap: widget.onHelp,
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: widget.onLogout,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.red.withValues(alpha: 0.25)),
            foregroundColor: AppColors.red,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.logout, color: AppColors.red),
          label: const Text('Log Out', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
