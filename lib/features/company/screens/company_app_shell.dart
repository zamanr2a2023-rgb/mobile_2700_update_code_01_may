import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../widgets/api_job_chat_screen.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../viewmodel/company_viewmodel.dart';
import 'company_management_screens.dart';
import 'company_messages_screen.dart';

class CompanyAppShell extends StatelessWidget {
  const CompanyAppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CompanyViewModel(auth: ctx.read<AuthRepository>()),
      child: const _CompanyScaffold(),
    );
  }
}

class _CompanyScaffold extends StatelessWidget {
  const _CompanyScaffold();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyViewModel>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Expanded(child: _CompanyBody()),
          _CompanyTabBar(vm: vm),
        ],
      ),
    );
  }
}

class _CompanyTabBar extends StatelessWidget {
  const _CompanyTabBar({required this.vm});

  final CompanyViewModel vm;

  @override
  Widget build(BuildContext context) {
    final active = vm.bottomResolved;
    Widget tab(String id, IconData icon, String label, {int? badge}) {
      final on = active == id;
      return Expanded(
        child: InkWell(
          onTap: () => vm.setScreen(id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
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
                    if (badge != null && badge > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.red,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.bg, width: 1),
                          ),
                          constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                          alignment: Alignment.center,
                          child: Text(
                            '$badge',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, height: 1),
                          ),
                        ),
                      ),
                  ],
                ),
                Text(label, style: TextStyle(fontSize: 8, color: on ? AppColors.primary : AppColors.textHint)),
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
            tab('company-dashboard', Icons.dashboard_outlined, 'Dashboard'),
            tab('company-job-feed', Icons.search, 'Feed'),
            tab('company-jobs', Icons.work_outline, 'Jobs', badge: vm.jobsTabBadge),
            tab('company-team', Icons.groups_outlined, 'Team'),
            tab('company-profile', Icons.person_outline, 'Profile'),
          ],
        ),
      ),
    );
  }
}

class _CompanyBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyViewModel>();
    switch (vm.screen) {
      case 'company-dashboard':
        return const _CompanyDashboardView();
      case 'company-job-feed':
        return const _CompanyJobFeedView();
      case 'company-jobs':
        return const CompanyJobsManagementView();
      case 'company-team':
        return const CompanyTeamManagementView();
      case 'company-earnings':
        return CompanyEarningsView(onBack: () => vm.setScreen('company-profile'));
      case 'company-messages':
        return CompanyMessagesListPage(onBack: () => vm.setScreen('company-profile'));
      case 'company-messages-chat':
        final peer = vm.activeCompanyChatPeer;
        if (peer == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) vm.setScreen('company-messages');
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
                    TextButton(onPressed: () => vm.closeCompanyMessageChat(), child: const Text('Back')),
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
          onClose: () => vm.closeCompanyMessageChat(),
          avatarFallbackAsset: AppAssets.mechanicPortrait,
        );
      case 'company-profile':
        return const CompanyProfileFullView();
      case 'company-edit-profile':
        return _coEdit(() => vm.setScreen('company-profile'));
      default:
        return const _CompanyDashboardView();
    }
  }

  Widget _coEdit(VoidCallback onDone) =>
      _CompanyEditProfileScreen(onDone: onDone);
}

class _CompanyDashboardView extends StatefulWidget {
  const _CompanyDashboardView();

  @override
  State<_CompanyDashboardView> createState() => _CompanyDashboardViewState();
}

class _CompanyDashboardViewState extends State<_CompanyDashboardView> {
  static const Color _headerBg = Color(0xFF0F0F0F);
  static const Color _blueAccent = Color(0xFF60A5FA);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CompanyViewModel>().loadDashboard();
    });
  }

  (IconData, Color) _activityVisual(String raw) {
    switch (raw.toUpperCase()) {
      case 'CHECK':
        return (Icons.check_circle_outline, AppColors.green);
      case 'BRIEFCASE':
        return (Icons.work_outline_rounded, AppColors.primary);
      case 'VAN':
        return (Icons.local_shipping_outlined, _blueAccent);
      case 'PERSON':
        return (Icons.person_outline_rounded, _blueAccent);
      case 'LOCATION':
        return (Icons.location_on_outlined, AppColors.green);
      case 'INFO':
        return (Icons.info_outline_rounded, AppColors.textMuted);
      default:
        return (Icons.notifications_none_rounded, AppColors.textMuted);
    }
  }

  String _revenuePctSub(int pct) {
    final sign = pct > 0 ? '+' : '';
    return '$sign$pct% vs last';
  }

  Color _revenuePctColor(int pct) =>
      pct > 0 ? AppColors.green : (pct < 0 ? AppColors.red : AppColors.textMuted);

  String _needsAssignTitle(int n) {
    if (n <= 0) return '';
    return n == 1 ? '1 Job Needs Assignment' : '$n Jobs Need Assignment';
  }

  Widget _dashMetric({
    required Color borderColor,
    required Color labelColor,
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: labelColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String detail,
    required String time,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(detail, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Text(time, style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, thickness: 1, color: AppColors.border),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyViewModel>();
    final d = vm.dashboard;

    final companyTitle =
        ((d?.companyName ?? '').trim().isNotEmpty) ? d!.companyName : 'Company';
    final mechanicCountTop = d?.mechanics;
    final mechanicHeadline =
        mechanicCountTop != null ? '$mechanicCountTop Active Mechanics' : '— Active Mechanics';

    final activeAssigned = d?.assignedActiveJobs;
    final unassigned = d?.unassignedJobsCount ?? 0;
    final mechanicCount = d?.mechanics;
    final online = d?.onlineMechanics;

    final monthAmt = formatCompanyMonthRevenueGbp(d?.monthRevenue ?? 0);
    final pct = d?.monthRevenueChangePercent ?? 0;

    final ratingStr = (d?.averageRating ?? 0) == 0 ? '—' : d!.averageRating.toStringAsFixed(1);

    final addInviteSub =
        (d?.pendingInvites ?? 0) > 0 ? 'Send invite · ${d!.pendingInvites} pending' : 'Send invite';

    final showAct = (d?.recentActivity ?? <CompanyRecentActivityRow>[])
        .where((r) => r.title.isNotEmpty || r.detail.isNotEmpty)
        .take(10)
        .toList();

    final showFatalDashboardErr =
        vm.dashboardError != null && vm.dashboard == null && !vm.dashboardLoading;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.bg,
      onRefresh: vm.loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: const BoxDecoration(
            color: _headerBg,
            border: Border(bottom: BorderSide(color: AppColors.border2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyTitle,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 4),
                    const Text('Company Dashboard', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.45), blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    mechanicHeadline,
                    style: TextStyle(color: AppColors.green.withValues(alpha: 0.95), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showFatalDashboardErr)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              children: [
                Text(vm.dashboardError!,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => vm.loadDashboard(),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else
          Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (vm.dashboardError != null && !showFatalDashboardErr)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vm.dashboardError!,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => vm.loadDashboard(),
                            child: const Text('Retry'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: _dashMetric(
                      borderColor: AppColors.primary.withValues(alpha: 0.35),
                      labelColor: AppColors.primary,
                      icon: Icons.work_outline_rounded,
                      label: 'Active Jobs',
                      value:
                          vm.dashboardLoading && vm.dashboard == null ? '—' : '${activeAssigned ?? 0}',
                      sub: '$unassigned unassigned',
                      subColor: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dashMetric(
                      borderColor: AppColors.green.withValues(alpha: 0.35),
                      labelColor: AppColors.green,
                      icon: Icons.groups_outlined,
                      label: 'Mechanics',
                      value: vm.dashboardLoading && vm.dashboard == null ? '—' : '${mechanicCount ?? 0}',
                      sub: '${online ?? 0} online',
                      subColor: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _dashMetric(
                      borderColor: _blueAccent.withValues(alpha: 0.35),
                      labelColor: _blueAccent,
                      icon: Icons.payments_outlined,
                      label: 'This Month',
                      value:
                          vm.dashboardLoading && vm.dashboard == null ? '—' : monthAmt,
                      sub: _revenuePctSub(pct),
                      subColor: _revenuePctColor(pct),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dashMetric(
                      borderColor: AppColors.orange.withValues(alpha: 0.35),
                      labelColor: AppColors.orange,
                      icon: Icons.star_rounded,
                      label: 'Avg Rating',
                      value:
                          vm.dashboardLoading && vm.dashboard == null ? '—' : ratingStr,
                      sub: '${d?.ratingReviewCount ?? 0} reviews',
                      subColor: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              if ((d?.unassignedJobsCount ?? 0) > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.65)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline_rounded, color: AppColors.primary, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _needsAssignTitle(d!.unassignedJobsCount),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Assign mechanics to new job requests',
                                  style: TextStyle(
                                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                                    fontSize: 12,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => vm.setScreen('company-jobs'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Assign Now',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'QUICK ACTIONS',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _quickAction(
                      icon: Icons.groups_outlined,
                      iconColor: AppColors.primary,
                      title: 'Manage Team',
                      subtitle: mechanicCount != null ? '$mechanicCount mechanics' : '— mechanics',
                      onTap: () => vm.setScreen('company-team'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _quickAction(
                      icon: Icons.person_add_alt_1_outlined,
                      iconColor: AppColors.green,
                      title: 'Add Mechanic',
                      subtitle: addInviteSub,
                      onTap: () => vm.setScreen('company-team'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'RECENT ACTIVITY',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: _headerBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border2),
                ),
                child: showAct.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('No recent activity',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      )
                        : Column(
                            children: List.generate(showAct.length, (i) {
                              final r = showAct[i];
                              final vis = _activityVisual(r.icon);
                              return _activityRow(
                                icon: vis.$1,
                                iconColor: vis.$2,
                                title: r.title.isNotEmpty ? r.title : 'Update',
                                detail: r.detail,
                                time: r.displayTimeLabel,
                                showDivider: i < showAct.length - 1,
                              );
                            }),
                          ),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}

// ─── Job Feed (`CompanyJobFeed` / check.tsx) ─────────────────────────────────

enum _CoFeedUrgency { urgent, high, medium, low }

class _CompanyJobFeedView extends StatefulWidget {
  const _CompanyJobFeedView();

  @override
  State<_CompanyJobFeedView> createState() => _CompanyJobFeedViewState();
}

class _CompanyJobFeedViewState extends State<_CompanyJobFeedView> {
  static const Color _headerBg = Color(0xFF0F0F0F);
  static const Color _tabInactiveBg = Color(0xFF1A1A1A);
  static const Color _blueUrgent = Color(0xFF60A5FA);

  bool _availableTab = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<CompanyViewModel>();
      vm.loadMyQuotes();
      vm.loadCompanyFeed();
    });
  }

  _CoFeedUrgency _urgencyFromApi(String raw) {
    switch (raw.toUpperCase()) {
      case 'CRITICAL':
      case 'URGENT':
      case 'EMERGENCY':
        return _CoFeedUrgency.urgent;
      case 'HIGH':
        return _CoFeedUrgency.high;
      case 'LOW':
        return _CoFeedUrgency.low;
      case 'MEDIUM':
      default:
        return _CoFeedUrgency.medium;
    }
  }

  String _urgencyChipLabelApi(String urgency) =>
      urgency.replaceAll('_', ' ').trim().toUpperCase();

  (Color bg, Color fg, Color border) _urgencyStyle(_CoFeedUrgency u) {
    switch (u) {
      case _CoFeedUrgency.urgent:
        return (AppColors.red.withValues(alpha: 0.10), AppColors.red, AppColors.red.withValues(alpha: 0.30));
      case _CoFeedUrgency.high:
        return (AppColors.orange.withValues(alpha: 0.10), AppColors.orange, AppColors.orange.withValues(alpha: 0.30));
      case _CoFeedUrgency.medium:
      case _CoFeedUrgency.low:
        return (_blueUrgent.withValues(alpha: 0.10), _blueUrgent, _blueUrgent.withValues(alpha: 0.30));
    }
  }



  ({Color fill, Color text, Color border}) _quoteToneDecoration(String tone) {
    switch (tone) {
      case 'green':
        return (
          fill: AppColors.green,
          text: Colors.white,
          border: AppColors.green,
        );
      case 'red':
        return (
          fill: AppColors.red,
          text: Colors.white,
          border: AppColors.red,
        );
      case 'amber':
      case 'yellow':
        return (
          fill: AppColors.primary.withValues(alpha: 0.10),
          text: AppColors.primary,
          border: AppColors.primary.withValues(alpha: 0.40),
        );
      case 'neutral':
      default:
        return (
          fill: Colors.white.withValues(alpha: 0.06),
          text: AppColors.textMuted,
          border: AppColors.border2,
        );
    }
  }

  String _quoteBadgeLabel(CompanyQuote q) {
    final l = q.statusLabel.trim();
    if (l.isNotEmpty) return l.toUpperCase();
    final s = q.status.trim().replaceAll('_', ' ');
    return s.isEmpty ? '' : s.toUpperCase();
  }

  Widget _quotesBody(CompanyViewModel vm) {
    if (vm.myQuotesLoading && vm.myQuotes.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (vm.myQuotesError != null && vm.myQuotes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                vm.myQuotesError!,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => vm.loadMyQuotes(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: vm.loadMyQuotes,
      child: vm.myQuotes.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(32),
              children: const [
                SizedBox(height: 80),
                Center(
                  child: Text(
                    'No quotes yet',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: vm.myQuotes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _myQuoteCard(ctx, vm, vm.myQuotes[i]),
            ),
    );
  }

  Widget _availableJobsBody(CompanyViewModel vm) {
    if (vm.feedLoading && vm.feedJobs.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (vm.feedError != null && vm.feedJobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                vm.feedError!,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => vm.loadCompanyFeed(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: vm.loadCompanyFeed,
      child: vm.feedJobs.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(32),
              children: const [
                SizedBox(height: 80),
                Center(
                  child: Text(
                    'No jobs in feed',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: vm.feedJobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _availableJobCard(vm.feedJobs[i]),
            ),
    );
  }

  void _openQuoteSheet(CompanyFeedJob job) {
    final vm = context.read<CompanyViewModel>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChangeNotifierProvider<CompanyViewModel>.value(
        value: vm,
        child: _CoQuoteSubmitSheet(job: job, onClose: () => Navigator.pop(ctx)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coVm = context.watch<CompanyViewModel>();

    final newJobsBadge = coVm.feedMeta?.activeCount ?? coVm.feedJobs.length;
    final availTotal = coVm.feedMeta?.total ?? coVm.feedJobs.length;

    return ColoredBox(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: _headerBg,
              border: Border(bottom: BorderSide(color: AppColors.border2)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Job Feed',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Browse & send quotes',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$newJobsBadge',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            ' new',
                            style: TextStyle(
                              color: AppColors.primary.withValues(alpha: 0.80),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _feedTabButton(
                        label: 'Available Jobs ($availTotal)',
                        selected: _availableTab,
                        onTap: () {
                          setState(() => _availableTab = true);
                          coVm.loadCompanyFeed();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _feedTabButton(
                        label: 'My Quotes (${coVm.myQuotes.length})',
                        selected: !_availableTab,
                        onTap: () {
                          setState(() => _availableTab = false);
                          coVm.loadMyQuotes();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _availableTab ? _availableJobsBody(coVm) : _quotesBody(coVm),
          ),
        ],
      ),
    );
  }

  Widget _feedTabButton({required String label, required bool selected, required VoidCallback onTap}) {
    return Material(
      color: selected ? AppColors.primary : _tabInactiveBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? Colors.transparent : AppColors.border2),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.black : AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _availableJobCard(CompanyFeedJob job) {
    final urgencyEnum = _urgencyFromApi(job.urgency);
    final st = _urgencyStyle(urgencyEnum);
    final chip = _urgencyChipLabelApi(job.urgency);
    final fleet = job.fleetRating;
    final distLabel = job.distanceMilesDisplay();
    final ratingText = fleet != null ? fleet.toStringAsFixed(1) : '—';
    final code = job.jobCode.isNotEmpty ? job.jobCode : job.jobBackendId;
    final veh = job.vehicleLine.isNotEmpty ? job.vehicleLine : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _headerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          code,
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: st.$1,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: st.$3),
                          ),
                          child: Text(
                            chip.isNotEmpty ? chip : 'MEDIUM',
                            style: TextStyle(color: st.$2, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 2),
                            Text(
                              ratingText,
                              style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      veh,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.subtitleLine,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                job.postedAgoLabel.isNotEmpty ? job.postedAgoLabel : '—',
                style: const TextStyle(color: AppColors.textHint, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 15, color: AppColors.textMuted.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  job.locationAddress.isNotEmpty ? job.locationAddress : '—',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.adjust, size: 15, color: AppColors.green.withValues(alpha: 0.95)),
              const SizedBox(width: 4),
              Text(
                distLabel,
                style: TextStyle(
                  color: job.distanceMiles != null ? AppColors.green : AppColors.textHint,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _openQuoteSheet(job),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Send Quote', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _myQuoteCard(BuildContext context, CompanyViewModel vm, CompanyQuote q) {
    final deco = _quoteToneDecoration(q.statusTone);
    final badgeTxt = _quoteBadgeLabel(q);
    final showNotes =
        q.notes.isNotEmpty && q.notes.toLowerCase() != q.issueTitle.toLowerCase();
    final dist = q.distanceKm;

    Widget card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _headerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          q.jobCode.isNotEmpty ? q.jobCode : q.quoteId,
                          style: const TextStyle(
                              color: AppColors.textHint, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        if (badgeTxt.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: deco.fill,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: deco.border),
                            ),
                            child: Text(
                              badgeTxt,
                              style: TextStyle(
                                color: deco.text,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.35,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      q.vehicle.isEmpty ? '—' : q.vehicle,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    if (q.issueTitle.isNotEmpty)
                      Text(
                        q.issueTitle,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35),
                      ),
                    if (showNotes) ...[
                      const SizedBox(height: 2),
                      Text(
                        q.notes,
                        style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.95), fontSize: 11, height: 1.35),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                q.amountDisplay,
                style: const TextStyle(color: AppColors.green, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 15, color: AppColors.textMuted.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [
                    q.location,
                    if (dist != null) '${dist.toStringAsFixed(1)} km',
                  ].where((s) => s.trim().isNotEmpty).join(' · '),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.schedule_rounded, size: 15, color: AppColors.textMuted.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
              Text(q.timeSubmittedLabel,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          if (q.showsAssignMechanicBanner) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.30)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      '✓ Quote accepted — assign a mechanic',
                      style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => vm.setScreen('company-team'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Assign', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ] else if (q.summaryLine.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.22)),
              ),
              child: Text(
                q.summaryLine,
                style: const TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
          ],
        ],
      ),
    );

    if (q.canOpenActiveJob) {
      card = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => vm.setScreen('company-jobs'),
        child: card,
      );
    }

    return card;
  }
}

class _CoQuoteSubmitSheet extends StatefulWidget {
  const _CoQuoteSubmitSheet({required this.job, required this.onClose});

  final CompanyFeedJob job;
  final VoidCallback onClose;

  @override
  State<_CoQuoteSubmitSheet> createState() => _CoQuoteSubmitSheetState();
}

class _CoQuoteSubmitSheetState extends State<_CoQuoteSubmitSheet> {
  static const Color _sheetBg = Color(0xFF0F0F0F);
  static const Color _fieldBg = Color(0xFF1A1A1A);

  final _amountCtrl = TextEditingController();
  final _etaCtrl = TextEditingController(text: '30');
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _etaCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountParsed = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    if (amountParsed == null || amountParsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid quote amount')));
      return;
    }
    final etaParsed = int.tryParse(_etaCtrl.text.trim());
    if (etaParsed == null || etaParsed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter estimated arrival (minutes)')));
      return;
    }
    if (widget.job.jobBackendId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing job id — cannot submit quote')));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final vm = context.read<CompanyViewModel>();
      final message = await vm.submitFeedJobQuote(
        jobBackendId: widget.job.jobBackendId,
        amount: amountParsed,
        etaMinutes: etaParsed,
        notes: _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message ?? 'Quote submitted')));
      widget.onClose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _sheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: AppColors.border2)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Submit Quote',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.job.jobCode} · ${widget.job.vehicleLine}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting ? null : widget.onClose,
                      icon: Icon(Icons.close_rounded, color: AppColors.textMuted.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border2),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.job.subtitleLine,
                              style:
                                  const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${widget.job.locationAddress} · ${widget.job.distanceMilesDisplay()}',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 16, color: AppColors.textMuted),
                              const SizedBox(width: 8),
                              Text(
                                widget.job.postedAgoLabel.isNotEmpty
                                    ? 'Posted ${widget.job.postedAgoLabel}'
                                    : 'Posted —',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Quote Amount',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountCtrl,
                      enabled: !_submitting,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _fieldBg,
                        prefixText: '£ ',
                        prefixStyle: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        hintText: '0',
                        hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.8), fontWeight: FontWeight.w900),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border2)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border2)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.45)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Estimated Arrival (minutes)',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _etaCtrl,
                      enabled: !_submitting,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _fieldBg,
                        hintText: '30',
                        hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.7)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border2)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border2)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.45)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Additional Notes (Optional)',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesCtrl,
                      enabled: !_submitting,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _fieldBg,
                        hintText: 'Any additional information...',
                        hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.7)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border2)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border2)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.45)),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('Submit Quote', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Company Edit Profile Screen
// ─────────────────────────────────────────────────────────────────────────────

class _CompanyEditProfileScreen extends StatefulWidget {
  const _CompanyEditProfileScreen({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_CompanyEditProfileScreen> createState() =>
      _CompanyEditProfileScreenState();
}

class _CompanyEditProfileScreenState extends State<_CompanyEditProfileScreen> {
  // Original values (would come from API in production)
  static const _origCompanyName = 'Swift Mechanics Ltd';
  static const _origHourlyRate = '75';
  static const _origEmergencyRate = '95';
  static const _origCalloutFee = '35';

  final _companyNameCtrl = TextEditingController(text: _origCompanyName);
  final _regNumCtrl = TextEditingController(text: '12345678');
  final _vatCtrl = TextEditingController();
  final _locationCtrl = TextEditingController(text: 'Birmingham, UK');
  final _radiusCtrl = TextEditingController(text: '50');
  final _hourlyRateCtrl = TextEditingController(text: _origHourlyRate);
  final _emergencyRateCtrl = TextEditingController(text: _origEmergencyRate);
  final _calloutFeeCtrl = TextEditingController(text: _origCalloutFee);
  final _bankNameCtrl = TextEditingController(text: 'Barclays Business');
  final _accountNumCtrl = TextEditingController(text: '••••9876');
  final _sortCodeCtrl = TextEditingController(text: '20-45-99');
  final _billingAddrCtrl =
      TextEditingController(text: '45 Industrial Park, Birmingham B12 8QT');

  bool _showReapprovalWarning = false;

  bool get _needsReapproval =>
      _companyNameCtrl.text != _origCompanyName ||
      _hourlyRateCtrl.text != _origHourlyRate ||
      _emergencyRateCtrl.text != _origEmergencyRate ||
      _calloutFeeCtrl.text != _origCalloutFee;

  @override
  void dispose() {
    for (final c in [
      _companyNameCtrl,
      _regNumCtrl,
      _vatCtrl,
      _locationCtrl,
      _radiusCtrl,
      _hourlyRateCtrl,
      _emergencyRateCtrl,
      _calloutFeeCtrl,
      _bankNameCtrl,
      _accountNumCtrl,
      _sortCodeCtrl,
      _billingAddrCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleSave() {
    if (_needsReapproval) {
      setState(() => _showReapprovalWarning = true);
    } else {
      widget.onDone();
    }
  }

  // ── Re-approval overlay ────────────────────────────────────────────────────
  Widget _reapprovalOverlay() {
    return Container(
      color: const Color(0xFF080808),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with glow
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFACC15).withOpacity(0.2),
                      blurRadius: 32,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F0F0F),
                  border: Border.all(color: const Color(0xFFFACC15), width: 2),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFACC15), size: 32),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Profile Under Review',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'You\'ve changed your company name or rates. Your profile must be re-approved by TruckFix before you can receive new jobs.',
            style:
                TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFACC15),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('I UNDERSTAND',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.2)),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Approval typically takes 2-4 business hours',
            style: TextStyle(color: Color(0xFF4B5563), fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  InputDecoration _inputDeco(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF374151), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF111111),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: const Color(0xFFFACC15).withOpacity(0.6)),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFFACC15),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
      );

  Widget _warningBanner(String text) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFACC15).withOpacity(0.05),
          border: Border.all(color: const Color(0xFFFACC15).withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFFACC15), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                    color: Color(0xFFFACC15), fontSize: 11, height: 1.5),
              ),
            ),
          ],
        ),
      );

  // ── Main build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_showReapprovalWarning) return _reapprovalOverlay();

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFF080808),
            border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onDone,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chevron_left,
                      color: Color(0xFF9CA3AF), size: 18),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMPANY',
                    style: TextStyle(
                      color: Color(0xFFFACC15),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Scrollable form body ─────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              // ── COMPANY DETAILS ──────────────────────────────────────────
              _sectionLabel('Company Details'),
              _warningBanner(
                'Changing your company name requires re-approval. '
                'Your account will be temporarily restricted until verified.',
              ),
              TextField(
                controller: _companyNameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco('COMPANY NAME'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _regNumCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco('REGISTRATION NUMBER'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _vatCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco('VAT NUMBER (if applicable)',
                    hint: 'e.g. GB 123 4567 89'),
              ),
              const SizedBox(height: 20),

              // ── SERVICE COVERAGE ─────────────────────────────────────────
              _sectionLabel('Service Coverage'),
              TextField(
                controller: _locationCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco('BASE LOCATION'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _radiusCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco('SERVICE RADIUS (MILES)'),
              ),
              const SizedBox(height: 20),

              // ── PRICING ──────────────────────────────────────────────────
              _sectionLabel('Pricing'),
              _warningBanner(
                  'Changing your rates requires re-approval to ensure pricing compliance.'),
              TextField(
                controller: _hourlyRateCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco('HOURLY RATE (£)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emergencyRateCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco('EMERGENCY RATE (£/HR)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _calloutFeeCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco('CALL-OUT FEE (£)'),
              ),
              const SizedBox(height: 20),

              // ── BANK & BILLING ───────────────────────────────────────────
              _sectionLabel('Bank & Billing'),
              TextField(
                controller: _bankNameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco('BANK NAME'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accountNumCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco('ACCOUNT NUMBER'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sortCodeCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco('SORT CODE'),
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF1A1A1A), height: 1),
              const SizedBox(height: 12),
              TextField(
                controller: _billingAddrCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco('BILLING ADDRESS'),
              ),
            ],
          ),
        ),

        // ── Footer ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF080808),
            border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFACC15),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'SAVE CHANGES',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: widget.onDone,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
