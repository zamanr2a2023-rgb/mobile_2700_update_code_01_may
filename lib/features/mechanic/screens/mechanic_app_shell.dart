import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/fleet_billing_payment_method.dart';
import '../../../data/models/job_offer.dart';
import '../../../data/models/mechanic_job_detail.dart';
import '../../../data/models/mechanic_me_profile.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/job_location_google_map_preview.dart';
import '../../../widgets/truckfix_map_preview.dart';
import '../../../widgets/api_job_chat_screen.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../../categories/job_taxonomy.dart';
import '../viewmodel/mechanic_viewmodel.dart';
import 'mechanic_messages_chat_screens.dart';
import '../../../data/services/mechanic_api_service.dart';
import '../../../data/services/support_api_service.dart';

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
        return _QuoteDetailPage(
          onBack: () {
            vm.clearJobQuoteDetail();
            vm.setTab('feed');
          },
        );
      case 'my-jobs':
        return _MyJobsPage(
          onOpenTracker: (jobId) {
            vm.selectJobForTracker(jobId);
            vm.setTab('job-tracker');
          },
        );
      case 'job-tracker':
        return MechanicJobTrackerPage(
          onBack: () {
            vm.clearJobTrackerSelection();
            vm.setTab('my-jobs');
          },
        );
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
      case 'profile-messages':
        return MechanicMessagesListPage(onBack: () => vm.setTab('profile'));
      case 'profile-messages-chat':
        final peer = vm.activeChatPeer;
        if (peer == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) vm.setTab('profile-messages');
          });
          return const ColoredBox(color: AppColors.bg, child: SizedBox.expand());
        }
        final token = context.watch<AuthViewModel>().session?.accessToken;
        if (token == null || token.trim().isEmpty) {
          return ColoredBox(
            color: AppColors.bg,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Session expired. Sign in again.', style: TextStyle(color: AppColors.textMuted)),
                    TextButton(onPressed: () => vm.closeMessageChat(), child: const Text('Back')),
                  ],
                ),
              ),
            ),
          );
        }
        return ApiJobChatScreen(
          accessToken: token,
          jobId: peer.jobId,
          headerTitle: peer.title,
          headerSubtitle: peer.subtitle,
          headerAvatarUrl: peer.photoUrl,
          peerPhone: peer.phone,
          onClose: () => vm.closeMessageChat(),
          avatarFallbackAsset: AppAssets.mechanicPortrait,
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
  bool _submitting = false;

  final _supportApi = SupportApiService();

  bool get _canSend => _categoryId != null && _messageCtrl.text.trim().isNotEmpty;

  String _senderLine(String? email) {
    final e = email == null || email.trim().isEmpty ? 'your registered email' : email.trim();
    return 'Sent from: $e · Mechanic';
  }

  String _subjectForCategory(String id) {
    for (final c in _categories) {
      if (c.id == id) return c.label;
    }
    return id;
  }

  Future<void> _submit() async {
    if (!_canSend || _submitting || _categoryId == null) return;
    final token = context.read<AuthViewModel>().session?.accessToken;
    if (token == null || token.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in again to send support messages.')));
      return;
    }
    final subjectLabel = _subjectForCategory(_categoryId!);
    setState(() => _submitting = true);
    try {
      await _supportApi.createTicket(
        accessToken: token,
        subject: subjectLabel,
        message: _messageCtrl.text.trim(),
        category: supportTicketCategoryEnum(_categoryId!),
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _sent = true;
      });
    } on SupportApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send message. Please try again.')));
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionEmail = context.watch<AuthViewModel>().session?.email;
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
                          _senderLine(sessionEmail),
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
                          onPressed: (_canSend && !_submitting) ? _submit : null,
                          icon: _submitting
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black.withValues(alpha: 0.7),
                                  ),
                                )
                              : Icon(Icons.send_rounded, size: 18, color: (_canSend && !_submitting) ? Colors.black : Colors.black.withValues(alpha: 0.35)),
                          label: Text(
                            'SEND MESSAGE',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              fontSize: 12,
                              color: (_canSend && !_submitting) ? Colors.black : Colors.black.withValues(alpha: 0.35),
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

class _JobFeedPage extends StatefulWidget {
  const _JobFeedPage();

  @override
  State<_JobFeedPage> createState() => _JobFeedPageState();
}

class _JobFeedPageState extends State<_JobFeedPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MechanicViewModel>().loadJobFeed();
    });
  }

  Future<void> _toggleOnline(BuildContext context) async {
    final vm = context.read<MechanicViewModel>();
    try {
      await vm.toggleOnline();
      if (mounted) await vm.loadJobFeed();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  List<JobOffer> _filtered(MechanicViewModel vm) {
    if (vm.maxDistMi == null) return vm.feedJobs;
    return vm.feedJobs
        .where((j) => j.distanceMi <= vm.maxDistMi!)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MechanicViewModel>();
    final jobs = vm.online ? _filtered(vm) : <JobOffer>[];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await vm.loadJobFeed();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
        else if (vm.feedLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (vm.feedError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: AppColors.textMuted, size: 36),
                const SizedBox(height: 10),
                Text(vm.feedError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: vm.loadJobFeed,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary), foregroundColor: AppColors.primary),
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (jobs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: AppColors.textHint),
                  SizedBox(height: 12),
                  Text('No jobs nearby', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                ],
              ),
            ),
          )
        else
          ...jobs.map((j) => _jobCard(context, j)),
      ],
    ),
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
            onTap: () {
              if (j.backendId == null || j.backendId!.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('This job cannot be opened (missing server id).')),
                );
                return;
              }
              vm.openJobQuoteDetail(j);
            },
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

// ignore: unused_element
class _MechanicFeedSheets {
  // ignore: unused_element
  static String _radiusLabelFor(int miles) {
    if (miles <= 5) return 'Local';
    if (miles <= 15) return 'Town / City';
    if (miles <= 30) return 'Regional';
    if (miles <= 50) return 'Wide Area';
    return 'Nationwide';
  }

  // ignore: unused_element
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
  String? _prefilledQuoteJobId;
  String? _submittedFleetName;

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MechanicViewModel>().loadJobQuoteDetail();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = context.read<MechanicViewModel>();
    final d = vm.jobQuoteDetail;
    if (d != null && _prefilledQuoteJobId != d.id) {
      _prefilledQuoteJobId = d.id;
      if (_quoteCtrl.text.trim().isEmpty) {
        final est = d.estimatedPayout;
        if (est != null && est > 0) {
          final t = est == est.roundToDouble() ? est.round().toString() : est.toStringAsFixed(0);
          _quoteCtrl.value = TextEditingValue(
            text: t,
            selection: TextSelection.collapsed(offset: t.length),
          );
        }
      }
    }
  }

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

  Widget _buildHeader(MechanicJobDetailParsed d) {
    final urg = switch (d.urgencyUpper) {
      'CRITICAL' => JobUrgency.critical,
      'HIGH' => JobUrgency.high,
      'MEDIUM' => JobUrgency.medium,
      _ => JobUrgency.low,
    };
    final sub = d.postedAgoText.isEmpty ? d.jobCode : '${d.jobCode} · ${d.postedAgoText}';
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Job Detail',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: urg.chipBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: urg.chipBorder),
            ),
            child: Text(
              urgencyLabel(urg),
              style: TextStyle(
                color: urg.foreground,
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
                    TextSpan(
                      text: ' has been sent to ${_submittedFleetName ?? 'the fleet'}. You\'ll be notified when they respond.',
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

  Widget _buildFooter(MechanicViewModel vm, MechanicJobDetailParsed d) {
    final can = d.canSubmitNewQuote;
    final busy = vm.quoteSubmitBusy;
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
              onPressed: !can || busy
                  ? null
                  : () async {
                      final parsed = double.tryParse(_quoteCtrl.text.replaceAll(',', '').trim());
                      if (parsed == null || parsed <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a valid quote amount')),
                        );
                        return;
                      }
                      FocusScope.of(context).unfocus();
                      final err = await vm.submitJobQuote(
                        amount: parsed,
                        notes: _notesCtrl.text.trim(),
                        availabilityUi: _availability,
                        scheduledDateKey: _scheduledDate,
                        scheduledTime: _scheduledTime,
                      );
                      if (!mounted) return;
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        return;
                      }
                      setState(() {
                        _submittedFleetName = d.fleetName.isNotEmpty ? d.fleetName : null;
                        _submitted = true;
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : const Row(
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
            onPressed: busy ? null : widget.onBack,
            child: Text(
              'Not interested — Skip',
              style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderLoading() {
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
            child: Text(
              'Job Detail',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MechanicViewModel>();
    if (_submitted) {
      return _buildSubmitted(context);
    }
    if (vm.jobQuoteDetailLoading && vm.jobQuoteDetail == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderLoading(),
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
        ],
      );
    }
    if (vm.jobQuoteDetailError != null && vm.jobQuoteDetail == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderLoading(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(vm.jobQuoteDetailError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: () => vm.loadJobQuoteDetail(), child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ],
      );
    }
    final d = vm.jobQuoteDetail;
    if (d == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderLoading(),
          const Expanded(
            child: Center(
              child: Text('No job loaded.', style: TextStyle(color: AppColors.textMuted)),
            ),
          ),
        ],
      );
    }

    final scheduledOn = _availability == 'Scheduled';
    final days = _days;
    final hasRoute = d.mechanicLngLat != null && d.jobDestinationLngLat != null;
    final mapBreakdown = d.mapBreakdownLngLat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(d),
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
                          Expanded(child: _kv('Vehicle', d.vehicleMakeModel)),
                          Expanded(child: _kv('Reg', d.vehicleRegistration.isEmpty ? '—' : d.vehicleRegistration)),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _kv('Fleet', d.fleetName.isEmpty ? '—' : d.fleetName)),
                          Expanded(child: _kv('Issue Type', d.issueTypeLabel)),
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
                      Text(
                        d.description.isEmpty ? '—' : d.description,
                        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.45),
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
                      _sectionTitle('PHOTOS (${d.photoUrls.length})'),
                      const SizedBox(height: 12),
                      if (d.photoUrls.isEmpty)
                        Text(
                          'No photos uploaded for this job.',
                          style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.9), fontSize: 12),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final url in d.photoUrls)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 160,
                                      height: 90,
                                      child: CachedNetworkImage(
                                        imageUrl: url,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(color: AppColors.card2),
                                        errorWidget: (_, __, ___) => Container(
                                          color: AppColors.card2,
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
                      if (!kIsWeb && mapBreakdown != null)
                        JobLocationGoogleMapPreview(
                          height: 130,
                          lat: mapBreakdown.lat,
                          lng: mapBreakdown.lng,
                          mechanicLat: hasRoute ? d.mechanicLngLat?.lat : null,
                          mechanicLng: hasRoute ? d.mechanicLngLat?.lng : null,
                        )
                      else
                        TruckFixMapPreview(height: 130, showRoute: hasRoute, liveLabel: true),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(Icons.location_on_rounded, size: 16, color: AppColors.red),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              d.locationDisplayAddress,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      if (d.distanceFromYouLine != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.navigation_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                d.distanceFromYouLine!,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!d.canSubmitNewQuote) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.orange, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            d.hasAcceptedQuote
                                ? 'You already have an accepted quote on this job. Open My Jobs to continue the visit.'
                                : 'This job is not accepting new quotes right now (${d.statusUpper.replaceAll('_', ' ')}). You can still review the details below.',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
                        'QUOTE AMOUNT (${d.currencyCode})',
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
                          prefixText: '${d.currencySymbol} ',
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
                        readOnly: !d.canSubmitNewQuote,
                      ),
                      const SizedBox(height: 4),
                      if (d.suggestedQuoteRangeLabel != null)
                        Text(
                          d.suggestedQuoteRangeLabel!,
                          style: TextStyle(
                            color: AppColors.textHint.withValues(alpha: 0.85),
                            fontSize: 10,
                          ),
                        )
                      else
                        Text(
                          'Enter your quote amount for this job.',
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
                        readOnly: !d.canSubmitNewQuote,
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
        _buildFooter(vm, d),
      ],
    );
  }
}

class _MyJobsPage extends StatefulWidget {
  const _MyJobsPage({required this.onOpenTracker});

  final void Function(String jobId) onOpenTracker;

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
                      onTap: () => widget.onOpenTracker(job.backendId),
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

/// Full mechanic job tracker (feed of [MechanicViewModel]) — also used by [EmployeeAppShell].
class MechanicJobTrackerPage extends StatefulWidget {
  const MechanicJobTrackerPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<MechanicJobTrackerPage> createState() => _MechanicJobTrackerPageState();
}

class _MechanicJobTrackerPageState extends State<MechanicJobTrackerPage> {
  final _callOutCtrl = TextEditingController();
  final _labourHoursCtrl = TextEditingController();
  final _labourRateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _reviewCtrl = TextEditingController();

  final List<({TextEditingController name, TextEditingController cost})> _parts = [];
  final List<XFile> _photoFiles = [];

  bool _showReview = false;
  int _rating = 0;
  bool _reviewSubmitted = false;
  bool _reviewSubmitBusy = false;
  String? _seededInvoiceJobId;

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

  @override
  void initState() {
    super.initState();
    _callOutCtrl.text = '85';
    _labourHoursCtrl.text = '1.5';
    _labourRateCtrl.text = '65';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MechanicViewModel>().loadJobTrackerDetail();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final d = context.read<MechanicViewModel>().jobTrackerDetail;
    if (d != null && _seededInvoiceJobId != d.id) {
      _seededInvoiceJobId = d.id;
      final r = d.labourRatePerHour;
      if (r > 0) {
        _labourRateCtrl.text = r == r.roundToDouble() ? r.round().toString() : r.toStringAsFixed(2);
      }
    }
  }

  int _displayStep(MechanicViewModel vm) {
    final d = vm.jobTrackerDetail;
    if (d != null && d.showCompletedSummary) return 4;
    return d?.uiStepIndex ?? 0;
  }

  Color _stepAccent(MechanicViewModel vm) {
    final i = _displayStep(vm).clamp(0, _steps.length - 1);
    return _steps[i].color;
  }

  @override
  void dispose() {
    _callOutCtrl.dispose();
    _labourHoursCtrl.dispose();
    _labourRateCtrl.dispose();
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
  double _labourRate(MechanicViewModel vm) {
    final parsed = double.tryParse(_labourRateCtrl.text.trim());
    if (parsed != null && parsed > 0) return parsed;
    return vm.jobTrackerDetail?.labourRatePerHour ?? 65;
  }
  double _labourTotal(MechanicViewModel vm) => _labourHours * _labourRate(vm);
  double get _partsTotal =>
      _parts.fold<double>(0, (s, p) => s + (double.tryParse(p.cost.text.trim()) ?? 0));
  double _totalInvoice(MechanicViewModel vm) => _callOut + _labourTotal(vm) + _partsTotal;

  Widget _header(MechanicViewModel vm) {
    final st = _displayStep(vm);
    final accent = _stepAccent(vm);
    final detail = vm.jobTrackerDetail;
    final pulse = st == 3 && !(detail?.showCompletedSummary ?? false);
    final timeStr = TimeOfDay.now().format(context);
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
                    _StatusDot(color: accent, pulse: pulse),
                    const SizedBox(width: 6),
                    Text(
                      _labels[st].toUpperCase(),
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
                Text(
                  detail?.headerSubtitle ?? '—',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, height: 1.05),
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
                  timeStr,
                  style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForWorkflowKey(String key) {
    switch (key.toUpperCase()) {
      case 'ASSIGNED':
        return Icons.navigation_rounded;
      case 'EN_ROUTE':
        return Icons.location_on_rounded;
      case 'ON_SITE':
        return Icons.build_rounded;
      case 'IN_PROGRESS':
        return Icons.timer_rounded;
      case 'COMPLETED':
        return Icons.check_circle_rounded;
      default:
        return Icons.flag_rounded;
    }
  }

  Widget _timeline(MechanicViewModel vm) {
    final detail = vm.jobTrackerDetail;
    final apiSteps = detail?.workflowSteps ?? const <MechanicWorkflowStepUi>[];
    final cur = _displayStep(vm);
    if (apiSteps.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            for (int i = 0; i < _steps.length; i++) ...[
              _TimelineNode(step: _steps[i], currentStep: cur),
              if (i != _steps.length - 1)
                Expanded(
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.only(bottom: 14),
                    color: i < cur ? AppColors.primary : AppColors.border2,
                  ),
                ),
            ],
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < apiSteps.length; i++) ...[
            _TimelineNodeApi(step: apiSteps[i], icon: _iconForWorkflowKey(apiSteps[i].key)),
            if (i != apiSteps.length - 1)
              Expanded(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.only(bottom: 14),
                  color: apiSteps[i].done ? AppColors.primary : AppColors.border2,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _jobCard(MechanicViewModel vm, {required bool orangeAccent}) {
    final d = vm.jobTrackerDetail;
    final truck = d?.vehicleLine ?? '—';
    final fleet = d?.fleetName ?? '—';
    final phone = d?.fleetPhone ?? '';
    final issue = d?.title ?? '—';
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  truck,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  phone.isNotEmpty ? '$fleet · $phone' : fleet,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Text(
                  issue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () async {
                final raw = phone.replaceAll(RegExp(r'\s'), '');
                if (raw.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No fleet phone on file.')));
                  return;
                }
                final uri = Uri(scheme: 'tel', path: raw);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
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

  Widget _instructionCard(MechanicViewModel vm) {
    final st = _displayStep(vm);
    final cfg = switch (st) {
      0 => (
          bg: const Color(0xFF60A5FA).withValues(alpha: 0.06),
          border: const Color(0xFF60A5FA).withValues(alpha: 0.22),
          icon: _steps[0].icon,
          color: _steps[0].color,
          title: _labels[0],
          body: 'Tap "Start Journey" below to begin navigating to the breakdown location.',
        ),
      1 => (
          bg: AppColors.primary.withValues(alpha: 0.06),
          border: AppColors.primary.withValues(alpha: 0.22),
          icon: _steps[1].icon,
          color: _steps[1].color,
          title: _labels[1],
          body: 'You\'re on route. Tap "I\'ve Arrived" when you reach the location.',
        ),
      2 => (
          bg: AppColors.orange.withValues(alpha: 0.06),
          border: AppColors.orange.withValues(alpha: 0.22),
          icon: _steps[2].icon,
          color: _steps[2].color,
          title: _labels[2],
          body: 'Begin the repair. Tap the button below when you start work.',
        ),
      3 => (
          bg: AppColors.orange.withValues(alpha: 0.06),
          border: AppColors.orange.withValues(alpha: 0.22),
          icon: _steps[3].icon,
          color: _steps[3].color,
          title: _labels[3],
          body: 'Enter billing details and repair notes below, then tap Complete Job.',
        ),
      _ => (
          bg: AppColors.green.withValues(alpha: 0.06),
          border: AppColors.green.withValues(alpha: 0.22),
          icon: _steps[4].icon,
          color: AppColors.green,
          title: _labels[4],
          body: 'This job is finished. Payment will confirm once the fleet approves.',
        ),
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

  Widget _jobInvoiceCard(MechanicViewModel vm) {
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
                flex: 3,
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
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _labourRateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.card2,
                    isDense: true,
                    prefixText: '@ £',
                    prefixStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 10),
                    suffixText: '/hr',
                    suffixStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 9, fontWeight: FontWeight.w600),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
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
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Labour total: £${_labourTotal(vm).toStringAsFixed(2)}',
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
                  '£${_totalInvoice(vm).toStringAsFixed(2)}',
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

  Widget _doneEarningsCard(MechanicViewModel vm) {
    final completeData = mechanicWorkCompleteData(vm.jobWorkCompleteEnvelope);
    final apiLines = mechanicCompletionLineAmounts(completeData);
    final apiSub = mechanicCompletionSubtotal(completeData);

    final rows = <Widget>[];
    if (apiLines.isNotEmpty) {
      for (var i = 0; i < apiLines.length; i++) {
        final line = apiLines[i];
        if (i > 0) rows.add(const SizedBox(height: 8));
        rows.add(_kvRow(line.label, '£${line.amount.toStringAsFixed(2)}'));
      }
    } else {
      rows.add(_kvRow('Call Out Charge', '£${_callOut.toStringAsFixed(2)}'));
      rows.add(const SizedBox(height: 8));
      rows.add(_kvRow(
        'Labour (${_labourHoursCtrl.text.trim()} hrs @ £${_labourRate(vm).toStringAsFixed(0)}/hr)',
        '£${_labourTotal(vm).toStringAsFixed(2)}',
      ));
      rows.add(const SizedBox(height: 8));
      rows.add(_kvRow('Parts', '£${_partsTotal.toStringAsFixed(2)}'));
    }

    final total = apiSub > 0 ? apiSub : _totalInvoice(vm);

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
          ...rows,
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
                  '£${total.toStringAsFixed(2)}',
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

  Widget _doneJobSummaryCard(MechanicViewModel vm) {
    final completeData = mechanicWorkCompleteData(vm.jobWorkCompleteEnvelope);
    final js = mechanicJobSummaryFromComplete(completeData);
    final d = vm.jobTrackerDetail;

    String pick(String k) {
      final v = js?[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
      return '';
    }

    final vehicle = pick('vehicleLine').isNotEmpty ? pick('vehicleLine') : (d?.vehicleLine ?? '—');
    final fleet = pick('fleetName').isNotEmpty ? pick('fleetName') : (d?.fleetName ?? '—');
    final issue = pick('issueLine').isNotEmpty ? pick('issueLine') : (d?.title ?? '—');
    final completed = pick('submittedForApprovalLabel').isNotEmpty ? pick('submittedForApprovalLabel') : '—';
    final duration = pick('durationLabel').isNotEmpty ? pick('durationLabel') : '—';

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
          row('Vehicle', vehicle),
          const SizedBox(height: 10),
          row('Fleet', fleet),
          const SizedBox(height: 10),
          row('Issue', issue),
          const SizedBox(height: 10),
          row('Completed', completed),
          const SizedBox(height: 10),
          row('Duration', duration),
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

  Widget _reviewOverlay(MechanicViewModel vm) {
    if (!_showReview) return const SizedBox.shrink();

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.90),
        child: InkWell(
          onTap: (_reviewSubmitted || _reviewSubmitBusy) ? null : () => setState(() => _showReview = false),
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
                            Text(
                              'How was your experience with ${vm.jobTrackerDetail?.fleetName ?? 'this fleet'}?',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                                onPressed: _rating == 0 || _reviewSubmitBusy
                                    ? null
                                    : () async {
                                        setState(() => _reviewSubmitBusy = true);
                                        final err = await vm.submitJobFleetReview(
                                          rating: _rating,
                                          comment: _reviewCtrl.text.trim(),
                                        );
                                        if (!mounted) return;
                                        setState(() => _reviewSubmitBusy = false);
                                        if (err != null) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                          return;
                                        }
                                        setState(() => _reviewSubmitted = true);
                                        await Future<void>.delayed(const Duration(milliseconds: 1200));
                                        if (!mounted) return;
                                        setState(() {
                                          _showReview = false;
                                          _reviewSubmitted = false;
                                          _rating = 0;
                                          _reviewCtrl.clear();
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
                                child: _reviewSubmitBusy
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                      )
                                    : const Text(
                                        'SUBMIT REVIEW',
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
                                      ),
                              ),
                            ),
                            TextButton(
                              onPressed: _reviewSubmitBusy ? null : () => setState(() => _showReview = false),
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

  Widget _cta(MechanicViewModel vm) {
    final st = _displayStep(vm);
    final doneFlow = st >= 4 || (vm.jobTrackerDetail?.showCompletedSummary ?? false);
    String label;
    Color bg = AppColors.primary;
    Color fg = Colors.black;
    IconData? icon;

    if (doneFlow) {
      label = 'BACK TO MY JOBS';
    } else if (st == 0) {
      label = 'START JOURNEY →';
    } else if (st == 1) {
      label = 'I\'VE ARRIVED ✓';
    } else if (st == 2) {
      label = 'START WORK 🔧';
      bg = AppColors.orange;
    } else if (st == 3) {
      label = 'COMPLETE JOB ✓';
      bg = AppColors.green;
      icon = Icons.flag_rounded;
    } else {
      label = 'CONTINUE';
    }

    final busy = vm.jobTrackerActionBusy;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: busy
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  if (doneFlow) {
                    widget.onBack();
                    return;
                  }
                  String? err;
                  if (st == 0) {
                    err = await vm.patchJobTrackerJourneyStart();
                  } else if (st == 1) {
                    err = await vm.patchJobTrackerArrive();
                  } else if (st == 2) {
                    err = await vm.patchJobTrackerWorkStart();
                  } else if (st == 3) {
                    final parts = <Map<String, dynamic>>[];
                    for (final p in _parts) {
                      final desc = p.name.text.trim();
                      final amt = double.tryParse(p.cost.text.trim()) ?? 0;
                      if (desc.isEmpty && amt == 0) continue;
                      parts.add({'description': desc, 'amount': amt});
                    }
                    final invoice = <String, dynamic>{
                      'callOutCharge': _callOut,
                      'labourHours': _labourHours,
                      'labourRatePerHour': _labourRate(vm),
                      if (parts.isNotEmpty) 'parts': parts,
                    };
                    final photos = <http.MultipartFile>[];
                    for (var i = 0; i < _photoFiles.length; i++) {
                      final xf = _photoFiles[i];
                      try {
                        final bytes = await xf.readAsBytes();
                        photos.add(
                          MechanicApiService.buildCompletePhotoPart(
                            bytes: bytes,
                            originalName: xf.name,
                            index: i,
                          ),
                        );
                      } catch (_) {}
                    }
                    err = await vm.patchJobWorkComplete(
                      repairNotes: _notesCtrl.text,
                      invoice: invoice,
                      finalAmount: _totalInvoice(vm),
                      photos: photos,
                    );
                  }
                  if (!mounted) return;
                  if (err != null) {
                    messenger?.showSnackBar(SnackBar(content: Text(err)));
                    return;
                  }
                  if (st == 3) {
                    await Future<void>.delayed(const Duration(milliseconds: 400));
                    if (!mounted) return;
                    setState(() => _showReview = true);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: bg.withValues(alpha: 0.45),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                )
              : Row(
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
    final vm = context.watch<MechanicViewModel>();
    if (vm.jobTrackerLoading && vm.jobTrackerDetail == null) {
      return ColoredBox(
        color: AppColors.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(vm),
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            ),
          ],
        ),
      );
    }
    if (vm.jobTrackerError != null && vm.jobTrackerDetail == null) {
      return ColoredBox(
        color: AppColors.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(vm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(vm.jobTrackerError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => vm.loadJobTrackerDetail(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final st = _displayStep(vm);
    final completed = vm.jobTrackerDetail?.showCompletedSummary ?? false;
    final showMapBlock = st <= 2 && !completed;
    final d = vm.jobTrackerDetail;
    final hasRoute = d?.mechanicLngLat != null && d?.jobDestinationLngLat != null;
    final mapBreakdown = d?.mapBreakdownLngLat;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(vm),
            _timeline(vm),
            Expanded(
              child: showMapBlock
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!kIsWeb && mapBreakdown != null)
                            JobLocationGoogleMapPreview(
                              height: 125,
                              lat: mapBreakdown.lat,
                              lng: mapBreakdown.lng,
                              mechanicLat: d?.mechanicLngLat?.lat,
                              mechanicLng: d?.mechanicLngLat?.lng,
                            )
                          else
                            TruckFixMapPreview(height: 125, showRoute: hasRoute, liveLabel: false),
                          const SizedBox(height: 12),
                          _jobCard(vm, orangeAccent: false),
                          const SizedBox(height: 12),
                          _instructionCard(vm),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _jobCard(vm, orangeAccent: true),
                          const SizedBox(height: 12),
                          if (st == 3 && !completed) ...[
                            _jobInvoiceCard(vm),
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
                                    onTap: () async {
                                      if (_photoFiles.length >= 5) return;
                                      final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2000, imageQuality: 85);
                                      if (x != null && mounted) setState(() => _photoFiles.add(x));
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _PhotoPickerButton(
                                    icon: Icons.inventory_2_outlined,
                                    label: 'Gallery',
                                    onTap: () async {
                                      if (_photoFiles.length >= 5) return;
                                      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
                                      if (x != null && mounted) setState(() => _photoFiles.add(x));
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (_photoFiles.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (int i = 0; i < _photoFiles.length; i++)
                                    _LocalPhotoThumb(
                                      path: _photoFiles[i].path,
                                      onRemove: () => setState(() => _photoFiles.removeAt(i)),
                                    ),
                                  if (_photoFiles.length < 5)
                                    _PhotoAddStub(
                                      onTap: () async {
                                        if (_photoFiles.length >= 5) return;
                                        final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
                                        if (x != null && mounted) setState(() => _photoFiles.add(x));
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ] else ...[
                            _doneSuccessCard(),
                            const SizedBox(height: 12),
                            _doneEarningsCard(vm),
                            const SizedBox(height: 12),
                            _doneJobSummaryCard(vm),
                            const SizedBox(height: 12),
                            _doneAwaitingRatingCard(),
                          ],
                        ],
                      ),
                    ),
            ),
            _cta(vm),
          ],
        ),
        _reviewOverlay(vm),
      ],
    );
  }
}

class _LocalPhotoThumb extends StatelessWidget {
  const _LocalPhotoThumb({required this.path, required this.onRemove});

  final String path;
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
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: AppColors.card2),
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

class _TimelineNodeApi extends StatelessWidget {
  const _TimelineNodeApi({required this.step, required this.icon});

  final MechanicWorkflowStepUi step;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final showCheck = step.done;
    final cur = step.active;
    final border = showCheck || cur ? AppColors.primary : AppColors.border2;
    final bg = showCheck ? AppColors.primary : (cur ? AppColors.primary.withValues(alpha: 0.15) : AppColors.card2);

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
          child: showCheck
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.black)
              : Icon(icon, size: 14, color: cur ? AppColors.primary : AppColors.textHint),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 52,
          child: Text(
            step.label.isNotEmpty ? step.label : step.key,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: cur ? AppColors.primary : showCheck ? AppColors.textMuted : AppColors.textHint,
            ),
          ),
        ),
      ],
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

String _mechEarnPctLabel(double pct) => pct == pct.roundToDouble() ? '${pct.round()}' : pct.toStringAsFixed(1);

String _mechEarnMoneyAbs(double amount, String currency) {
  final cur = currency.toUpperCase().trim().isEmpty ? 'GBP' : currency.trim().toUpperCase();
  if (cur == 'GBP') {
    if (amount == amount.roundToDouble()) return '£${amount.round()}';
    return '£${amount.toStringAsFixed(2)}';
  }
  if (amount == amount.roundToDouble()) return '$cur ${amount.round()}';
  return '$cur ${amount.toStringAsFixed(2)}';
}

String _mechEarnNegativeMoney(double fee, String currency) {
  if (fee == 0) return _mechEarnMoneyAbs(0, currency);
  return '-${_mechEarnMoneyAbs(fee, currency)}'.replaceFirst('--', '-');
}

Map<String, dynamic>? _mechEarningUnwrapEnvelope(Map<String, dynamic>? raw) {
  if (raw == null) return null;
  final d = raw['data'];
  if (d is Map<String, dynamic>) return d;
  return raw;
}

class _MechanicEarnings extends StatefulWidget {
  const _MechanicEarnings({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_MechanicEarnings> createState() => _MechanicEarningsState();
}

class _MechanicEarningsState extends State<_MechanicEarnings> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<MechanicViewModel>();
      vm.loadEarnings();
      vm.loadEarningsJobs();
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

  Widget _jobCard(BuildContext context, MechanicViewModel vm, MechanicCompletedEarningJob job) {
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
                          Text(
                            job.jobCode.isNotEmpty ? job.jobCode : '—',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
                          ),
                          Text(' · ', style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.8), fontSize: 10)),
                          Text(job.dateLabel, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.vehicleLine.isNotEmpty ? job.vehicleLine : '—',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.issueLine.isNotEmpty ? job.issueLine : '—',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      job.netEarnedDisplay,
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
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
                    job.customerName.isNotEmpty ? job.customerName : '—',
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(' · ', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 10)),
                const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 2),
                Text(
                  job.durationLabel.isNotEmpty ? job.durationLabel : '—',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
                ),
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
                onTap: () => _showInvoiceSheet(context, vm, job),
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
                          Text(job.grossDisplay, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fee (${job.platformFeePercent}%)',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                          ),
                          Text(job.feeDisplay, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
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
                          Text(job.netDisplay, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900)),
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

  Widget _mechInvoiceKv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 118, child: Text(k, style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
          Expanded(child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _mechInvoiceSheetBody(BuildContext context, MechanicCompletedEarningJob job, Map<String, dynamic> inv) {
    String pickStr(String snake, [String camel = '']) {
      final keys = camel.isEmpty ? <String>[snake] : <String>[snake, camel];
      for (final k in keys) {
        final raw = inv[k];
        if (raw == null) continue;
        final s = raw.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    final invNoPick = pickStr('invoice_no', 'invoiceNo');
    final invoiceNoLine = invNoPick.isNotEmpty ? invNoPick : job.invoiceNo.trim();

    final statusPick = pickStr('status').trim();
    final paidPick = pickStr('paid_at', 'paidAt');

    final grossPickStr = pickStr('gross_amount', 'grossAmount');
    final netPickStr = pickStr('net_amount', 'netAmount');
    final curPick = pickStr('currency');
    final cur = curPick.isEmpty ? job.currency : curPick;

    final pdfInline = pickStr('pdf_url', 'pdfUrl');

    final grossParsed = grossPickStr.isNotEmpty ? double.tryParse(grossPickStr) : null;
    final netParsed = netPickStr.isNotEmpty ? double.tryParse(netPickStr) : null;

    final rows = <Widget>[
      if (job.jobCode.isNotEmpty) _mechInvoiceKv('Job code', job.jobCode),
      if (invoiceNoLine.isNotEmpty) _mechInvoiceKv('Invoice #', invoiceNoLine),
      if (statusPick.isNotEmpty) _mechInvoiceKv('Status', statusPick),
      if (paidPick.isNotEmpty) _mechInvoiceKv('Paid', paidPick),
      _mechInvoiceKv('Gross', _mechEarnMoneyAbs(grossParsed ?? job.grossAmount, cur)),
      _mechInvoiceKv(
        'Fee (${_mechEarnPctLabel(job.platformFeePercent.toDouble())}%)',
        _mechEarnNegativeMoney(job.platformFeeAmount, cur),
      ),
      _mechInvoiceKv('Net', _mechEarnMoneyAbs(netParsed ?? job.netAmount, cur)),
    ];

    if (pdfInline.trim().startsWith('http')) {
      final url = pdfInline.trim();
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: FilledButton.icon(
            onPressed: () async {
              final u = Uri.tryParse(url);
              if (u != null && await canLaunchUrl(u)) {
                await launchUrl(u, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.black, size: 20),
            label: const Text('Open PDF', style: TextStyle(fontWeight: FontWeight.w900)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  void _showInvoiceSheet(BuildContext context, MechanicViewModel vm, MechanicCompletedEarningJob job) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final href = job.invoiceDownloadPath.trim();
    if (href.isEmpty) {
      messenger?.showSnackBar(const SnackBar(content: Text('No invoice link for this job.')));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 12),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.56,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F0F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(top: BorderSide(color: AppColors.border2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Invoice',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: AppColors.textMuted.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF1A1A1A)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottom),
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: vm.fetchMechanicAuthorizedGet(href),
                        builder: (_, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                            );
                          }
                          if (snapshot.hasError) {
                            return Text(
                              snapshot.error.toString(),
                              style: TextStyle(color: AppColors.red.withValues(alpha: 0.9), fontSize: 13, height: 1.35),
                            );
                          }
                          final envelope = snapshot.data!;
                          final inv = _mechEarningUnwrapEnvelope(envelope) ?? envelope;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                job.vehicleLine,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(job.issueLine, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              const SizedBox(height: 16),
                              _mechInvoiceSheetBody(context, job, inv),
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
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
                    Text(
                      '${vm.earningsJobsMeta?.total ?? vm.earningsJobs.length} jobs',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (vm.earningsJobsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                  )
                else if (vm.earningsJobsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.textMuted, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            vm.earningsJobsError!,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: vm.loadEarningsJobs,
                          child: const Text('Retry', style: TextStyle(color: AppColors.primary, fontSize: 11)),
                        ),
                      ],
                    ),
                  )
                else if (vm.earningsJobs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No completed jobs yet.',
                      style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 12),
                    ),
                  )
                else
                  ...vm.earningsJobs.map((j) => _jobCard(context, vm, j)),
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
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _hourlyCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _sortCtrl = TextEditingController();
  final _billingCtrl = TextEditingController();
  final _vatCtrl = TextEditingController();

  /// 'yes' | 'no' — matches React select.
  String _vatRegistered = 'yes';

  bool _showReapproval = false;
  bool _seededFromServer = false;
  int? _baselineHourly;
  int? _baselineEmergency;

  bool get _ratesChanged {
    final h = int.tryParse(_hourlyCtrl.text.trim());
    final e = int.tryParse(_emergencyCtrl.text.trim());
    final bh = _baselineHourly;
    if (bh == null) return false;
    if (h != bh) return true;
    final be = _baselineEmergency;
    if (be == null) return e != null;
    return e != be;
  }

  void _onRateFieldChanged() => setState(() {});

  static String _rateFieldText(num? r) {
    if (r == null) return '';
    if (r == r.roundToDouble()) return r.round().toString();
    return r.toString();
  }

  void _seedFromProfile(MechanicMeProfile p) {
    _nameCtrl.text = p.displayName;
    _phoneCtrl.text = p.phone;
    _emailCtrl.text = p.email;
    _hourlyCtrl.text = _rateFieldText(p.hourlyRate);
    _emergencyCtrl.text = _rateFieldText(p.emergencyRate);
    _bankNameCtrl.text = p.bankDisplayName ?? '';
    _accountCtrl.text = p.bankAccountMasked ?? '';
    _sortCtrl.text = p.bankSortCode ?? '';
    _billingCtrl.text = p.billingAddress ?? '';
    _vatCtrl.text = p.vatNumber ?? '';
    _vatRegistered = p.vatRegistered ? 'yes' : 'no';
    _baselineHourly = p.hourlyRate == null ? null : (p.hourlyRate as num).round();
    _baselineEmergency = p.emergencyRate == null ? null : (p.emergencyRate as num).round();
    if (mounted) setState(() {});
  }

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

  Future<void> _onSave() async {
    final vm = context.read<MechanicViewModel>();
    final hourly = int.tryParse(_hourlyCtrl.text.trim());
    if (hourly == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid hourly rate')));
      return;
    }
    final emRaw = _emergencyCtrl.text.trim();
    final emParsed = int.tryParse(emRaw);
    if (emRaw.isNotEmpty && emParsed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid emergency rate or leave it blank')));
      return;
    }
    final int? emergencyRate = emRaw.isEmpty ? null : emParsed;

    try {
      await vm.saveMechanicProfileFromEdit(
        displayName: _nameCtrl.text,
        email: _emailCtrl.text,
        phone: _phoneCtrl.text,
        hourlyRate: hourly,
        emergencyRate: emergencyRate,
        bankDisplayName: _bankNameCtrl.text,
        bankAccountField: _accountCtrl.text,
        bankSortCode: _sortCtrl.text,
        billingAddress: _billingCtrl.text,
        vatNumber: _vatCtrl.text,
        vatRegistered: _vatRegistered == 'yes',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }

    if (!mounted) return;
    if (_ratesChanged) {
      setState(() => _showReapproval = true);
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MechanicViewModel>();
    final p = vm.meProfile;
    if (!_seededFromServer && p != null && !vm.meProfileLoading) {
      _seededFromServer = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _seedFromProfile(p);
      });
    }

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
                      onPressed: vm.meProfilePatchBusy ? null : _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: vm.meProfilePatchBusy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                            )
                          : const Text(
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

class _MechPayment extends StatefulWidget {
  const _MechPayment({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_MechPayment> createState() => _MechPaymentState();
}

class _MechPaymentState extends State<_MechPayment> {
  bool _showAddForm = false;
  bool _saveBusy = false;

  final _cardNumCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MechanicViewModel>().loadBillingPaymentMethods();
    });
  }

  @override
  void dispose() {
    _cardNumCtrl.dispose();
    _expiryCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  static String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// Parses `MM/YY`, `MMYY`, or `MM / YY`.
  static ({int month, int year})? _parseExpiry(String raw) {
    final d = _digitsOnly(raw);
    if (d.length == 4) {
      final m = int.tryParse(d.substring(0, 2));
      var y2 = int.tryParse(d.substring(2, 4));
      if (m == null || y2 == null || m < 1 || m > 12) return null;
      final y = y2 < 100 ? 2000 + y2 : y2;
      return (month: m, year: y);
    }
    return null;
  }

  static String _inferCardBrandLower(String digits) {
    if (digits.isEmpty) return 'visa';
    if (digits.startsWith('4')) return 'visa';
    if (digits.length >= 2) {
      final p2 = int.tryParse(digits.substring(0, 2)) ?? 0;
      if (p2 >= 51 && p2 <= 55) return 'mastercard';
      if (p2 == 22 || p2 == 23 || p2 == 24 || p2 == 25 || p2 == 26 || p2 == 27) return 'mastercard';
    }
    if (digits.startsWith('34') || digits.startsWith('37')) return 'amex';
    return 'visa';
  }

  Future<void> _setDefault(String id) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await context.read<MechanicViewModel>().setDefaultBillingPaymentMethod(id);
      if (!mounted) return;
      messenger?.showSnackBar(const SnackBar(content: Text('Default card updated')));
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _remove(String id) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await context.read<MechanicViewModel>().deleteBillingPaymentMethod(id);
      if (!mounted) return;
      messenger?.showSnackBar(const SnackBar(content: Text('Card removed')));
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _addCard() {
    setState(() => _showAddForm = !_showAddForm);
    if (!_showAddForm) {
      _cardNumCtrl.clear();
      _expiryCtrl.clear();
      _nameCtrl.clear();
    }
  }

  Future<void> _saveCard() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final digits = _digitsOnly(_cardNumCtrl.text);
    if (digits.length < 13 || digits.length > 16) {
      messenger?.showSnackBar(const SnackBar(content: Text('Enter a valid card number (13–16 digits).')));
      return;
    }
    final last4 = digits.substring(digits.length - 4);
    final exp = _parseExpiry(_expiryCtrl.text);
    if (exp == null) {
      messenger?.showSnackBar(const SnackBar(content: Text('Enter expiry as MM/YY')));
      return;
    }
    final brand = _inferCardBrandLower(digits);
    setState(() => _saveBusy = true);
    try {
      await context.read<MechanicViewModel>().createBillingPaymentMethod(
        cardBrandLower: brand,
        last4: last4,
        expMonth: exp.month,
        expYear: exp.year,
      );
      if (!mounted) return;
      setState(() {
        _showAddForm = false;
        _cardNumCtrl.clear();
        _expiryCtrl.clear();
        _nameCtrl.clear();
      });
      messenger?.showSnackBar(const SnackBar(content: Text('Card saved')));
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saveBusy = false);
    }
  }

  static InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
        filled: true,
        fillColor: Color(0xFF111111),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      );

  Widget _addCardForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEW CARD DETAILS',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          const Text('CARD NUMBER', style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          TextField(
            controller: _cardNumCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
            ],
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDeco('1234 5678 9012 3456'),
          ),
          const SizedBox(height: 14),
          const Text('EXPIRY', style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          TextField(
            controller: _expiryCtrl,
            keyboardType: TextInputType.datetime,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDeco('MM/YY'),
          ),
          const SizedBox(height: 14),
          const Text('CARDHOLDER NAME', style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDeco('John Smith'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saveBusy ? null : _saveCard,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
                disabledForegroundColor: Colors.black54,
              ),
              child: _saveBusy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : const Text(
                      'SAVE CARD',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MechanicViewModel>();
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
                if (vm.billingPaymentMethodsLoading && vm.billingPaymentMethods.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                  )
                else if (vm.billingPaymentMethodsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.textMuted, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vm.billingPaymentMethodsError!,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () => vm.loadBillingPaymentMethods(),
                          child: const Text('Retry', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                for (final card in vm.billingPaymentMethods) ...[
                  _paymentCard(card),
                  const SizedBox(height: 14),
                ],
                _DashedAddCardButton(onTap: _addCard),
                if (_showAddForm) ...[
                  const SizedBox(height: 14),
                  _addCardForm(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(FleetBillingPaymentMethod card) {
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
                      '${card.displayBrand} •••• ${card.last4}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text('Expires ${card.expiryLabel}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
  late final MechanicViewModel _vm;
  late final VoidCallback _vmListen;
  MechanicMeProfile? _syncedFromProfile;

  bool _pushEnabled = true;
  int _notifRadius = 25;
  bool _notifNewJobs = true;
  bool _notifJobUpdates = true;
  bool _notifPayments = true;
  bool _notifSystem = false;
  bool _notifApp = false;

  @override
  void initState() {
    super.initState();
    _vm = context.read<MechanicViewModel>();
    _vmListen = () {
      final profile = _vm.meProfile;
      if (_vm.meProfileLoading || profile == null) return;
      if (identical(_syncedFromProfile, profile)) return;
      _syncedFromProfile = profile;
      setState(() {
        _pushEnabled = profile.pushEnabled;
        _notifRadius = profile.alertRadiusMiles;
        _notifNewJobs = profile.notifNewBreakdownJobs;
        _notifJobUpdates = profile.notifJobAcceptedDeclined;
        _notifPayments = profile.notifPaymentReceived;
        final sysApp = profile.notifSystemAlerts || profile.notifAppAlerts;
        _notifSystem = sysApp;
        _notifApp = sysApp;
      });
    };
    _vm.addListener(_vmListen);
    WidgetsBinding.instance.addPostFrameCallback((_) => _vmListen());
  }

  @override
  void dispose() {
    _vm.removeListener(_vmListen);
    super.dispose();
  }

  Future<void> _persistNotificationSettings() async {
    final vm = context.read<MechanicViewModel>();
    try {
      await vm.patchMechanicNotificationSettings(
        pushEnabled: _pushEnabled,
        alertRadiusMiles: _notifRadius,
        newBreakdownJobs: _notifNewJobs,
        jobAcceptedDeclined: _notifJobUpdates,
        paymentReceived: _notifPayments,
        systemAlerts: _notifSystem,
        appAlerts: _notifApp,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      await vm.loadMeProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MechanicViewModel>();
    final p = vm.meProfile;
    final loading = vm.meProfileLoading;
    final err = vm.meProfileError;

    const radii = [5, 10, 25, 50];

    final avatarUrl = () {
      final u = p?.profilePhotoUrl?.trim();
      if (u != null && u.isNotEmpty) return u;
      return AppAssets.mechanicPortrait;
    }();

    final displayName = p?.displayName ?? (loading ? '…' : 'Mechanic');
    final ratingLabel = p != null ? p.avgRating.toStringAsFixed(1) : (loading ? '…' : '—');
    final avgForStars = p?.avgRating ?? 0;
    final jobsDoneLabel = p != null ? '${p.jobsDone}' : (loading ? '…' : '—');
    final responseLabel =
        (p != null && p.responseMinutes > 0) ? '${p.responseMinutes} min' : (loading ? '…' : '—');

    final hourlyLine = p != null ? '${p.formatMoney(p.hourlyRate)} / hr' : (loading ? '…' : '—');
    final emergencyLine =
        loading && p == null ? '…' : (p != null && p.emergencyRate != null ? '${p.formatMoney(p.emergencyRate)} / hr' : '—');
    final callOutLine = p != null ? p.formatMoney(p.callOutFee) : (loading ? '…' : '—');
    final serviceRadius = p?.serviceRadiusMiles;
    final radiusLine = serviceRadius != null ? '$serviceRadius mi' : (loading ? '…' : '—');
    final baseLine = loading && p == null ? '…' : (p != null ? p.baseLocationLine : '—');

    final bankLabel = p?.bankDisplayName ?? (loading ? '…' : '—');
    final accountMasked = p?.bankAccountMasked ?? (loading ? '…' : '—');
    final sortCodeLabel = p?.bankSortCode ?? (loading ? '…' : '—');
    final billingAddr = p?.billingAddress ?? (loading ? '…' : '—');
    final vatNum = p?.vatNumber ?? (loading ? '…' : '—');
    final vatReg = p?.vatRegistered == true;

    final alertFootnoteBase = loading && p == null ? 'your base location' : (p?.baseLocationLine ?? 'your base location');

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
      bool locked = false,
    }) {
      return Material(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: locked ? null : onToggle,
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

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: vm.loadMeProfile,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: AppColors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(err, style: TextStyle(color: AppColors.red.withValues(alpha: 0.95), fontSize: 12, height: 1.35)),
                      TextButton(onPressed: loading ? null : vm.loadMeProfile, child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
            ),
        // Hero
        Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: AppColors.card2,
                      alignment: Alignment.center,
                      child: Icon(Icons.person_rounded, size: 40, color: AppColors.textMuted.withValues(alpha: 0.85)),
                    ),
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
            Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(
                      Icons.star,
                      size: 16,
                      color: i < avgForStars.floor().clamp(0, 5) ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.35),
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  ratingLabel,
                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: stat(jobsDoneLabel, 'Jobs Done')),
            const SizedBox(width: 10),
            Expanded(child: stat(ratingLabel, 'Avg Rating')),
            const SizedBox(width: 10),
            Expanded(child: stat(responseLabel, 'Response')),
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
        const SizedBox(height: 12),
        profileShortcut(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Messages',
          subtitle: 'Chats with fleets, operators & TruckFix support',
          onTap: () => vm.setTab('profile-messages'),
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
                    kv('Hourly Rate', hourlyLine),
                    const SizedBox(height: 10),
                    kv('Emergency Rate', emergencyLine),
                    const SizedBox(height: 10),
                    kv('Call-out Fee', callOutLine),
                    const SizedBox(height: 10),
                    kv('Service Radius', radiusLine),
                    const SizedBox(height: 10),
                    kv('Base Location', baseLine),
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
                        color: _pushEnabled ? AppColors.primary.withValues(alpha: 0.15) : AppColors.border,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: _pushEnabled ? AppColors.primary : AppColors.textMuted,
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
                            _pushEnabled ? 'You are receiving job alerts' : 'Tap to turn on job alerts',
                            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _pushEnabled,
                      onChanged: vm.meProfilePatchBusy
                          ? null
                          : (v) {
                              setState(() => _pushEnabled = v);
                              _persistNotificationSettings();
                            },
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: Colors.white,
                    ),
                  ],
                ),
              ),
              if (_pushEnabled) ...[
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
                                onPressed: vm.meProfilePatchBusy
                                    ? null
                                    : () {
                                        setState(() => _notifRadius = radii[i]);
                                        _persistNotificationSettings();
                                      },
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
                        "You'll be notified of breakdown jobs within $_notifRadius mi of $alertFootnoteBase",
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
                        locked: vm.meProfilePatchBusy,
                        onToggle: () {
                          setState(() => _notifNewJobs = !_notifNewJobs);
                          _persistNotificationSettings();
                        },
                      ),
                      const SizedBox(height: 6),
                      notifTypeRow(
                        icon: Icons.check_circle_outline,
                        label: 'Job accepted / declined',
                        on: _notifJobUpdates,
                        locked: vm.meProfilePatchBusy,
                        onToggle: () {
                          setState(() => _notifJobUpdates = !_notifJobUpdates);
                          _persistNotificationSettings();
                        },
                      ),
                      const SizedBox(height: 6),
                      notifTypeRow(
                        icon: Icons.payments_outlined,
                        label: 'Payment received',
                        on: _notifPayments,
                        locked: vm.meProfilePatchBusy,
                        onToggle: () {
                          setState(() => _notifPayments = !_notifPayments);
                          _persistNotificationSettings();
                        },
                      ),
                      const SizedBox(height: 6),
                      notifTypeRow(
                        icon: Icons.shield_outlined,
                        label: 'System & app alerts',
                        on: _notifSystem,
                        locked: vm.meProfilePatchBusy,
                        onToggle: () {
                          setState(() {
                            final next = !_notifSystem;
                            _notifSystem = next;
                            _notifApp = next;
                          });
                          _persistNotificationSettings();
                        },
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
                    kv('Bank', bankLabel),
                    const SizedBox(height: 10),
                    kv('Account', accountMasked),
                    const SizedBox(height: 10),
                    kv('Sort Code', sortCodeLabel),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Color(0xFF1E1E1E)),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Billing Address', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            billingAddr,
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    kv('VAT Number', vatNum),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('VAT Registered', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: vatReg ? AppColors.green.withValues(alpha: 0.10) : AppColors.textMuted.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: vatReg ? AppColors.green.withValues(alpha: 0.20) : AppColors.border2,
                            ),
                          ),
                          child: Text(
                            vatReg ? 'YES' : 'NO',
                            style: TextStyle(
                              color: vatReg ? AppColors.green : AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
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
          subtitle: (() {
            final card = p?.paymentCardLabel?.trim();
            if (card != null && card.isNotEmpty) return card;
            return 'Manage cards for expenses & receipts';
          })(),
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
    ),
    );
  }
}
