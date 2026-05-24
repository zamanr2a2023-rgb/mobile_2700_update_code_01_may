import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../../data/services/support_api_service.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../viewmodel/company_viewmodel.dart';

// ─── Helpers shared by company management screens ───────────────────────────

Color _companyTeamDotPaintColor(String tone) {
  switch (tone.toLowerCase()) {
    case 'green':
      return AppColors.green;
    case 'orange':
      return AppColors.orange;
    case 'red':
      return AppColors.red;
    default:
      return AppColors.textHint;
  }
}

Color _companyTeamLabelColor(String tone) {
  switch (tone.toLowerCase()) {
    case 'green':
      return AppColors.green;
    case 'orange':
      return AppColors.orange;
    case 'red':
      return AppColors.red;
    default:
      return AppColors.textHint;
  }
}

/// Uses API `workStatusUi.dotTone` / `tone` tokens (`green`, `orange`, `grey`, …).
Widget _mechToneDot(String dotTone, {bool greenGlow = false}) {
  final c = _companyTeamDotPaintColor(dotTone);
  return Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: c,
      shape: BoxShape.circle,
      boxShadow:
          greenGlow ? [BoxShadow(color: AppColors.green.withValues(alpha: 0.45), blurRadius: 6)] : null,
    ),
  );
}

Widget _teamMemberAvatarCircle(String profilePhotoUrl, {double diameter = 48, double iconScale = 0.54}) {
  final fallback = Container(
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.20),
      shape: BoxShape.circle,
    ),
    child: Icon(Icons.person_rounded, color: AppColors.primary, size: diameter * iconScale),
  );
  if (profilePhotoUrl.isEmpty) return fallback;
  return ClipOval(
    child: SizedBox(
      width: diameter,
      height: diameter,
      child: CachedNetworkImage(
        imageUrl: profilePhotoUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: AppColors.primary.withValues(alpha: 0.12),
          alignment: Alignment.center,
          child: SizedBox(
            width: diameter * 0.35,
            height: diameter * 0.35,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => fallback,
      ),
    ),
  );
}

// ─── Job Management (`CompanyJobs` / check.tsx) ──────────────────────────────

class CompanyJobsManagementView extends StatefulWidget {
  const CompanyJobsManagementView({super.key});

  @override
  State<CompanyJobsManagementView> createState() => _CompanyJobsManagementViewState();
}

class _CompanyJobsManagementViewState extends State<CompanyJobsManagementView> {
  static const Color _headerBg = Color(0xFF0F0F0F);
  static const Color _chipInactive = Color(0xFF1A1A1A);
  static const Color _blueUrgent = Color(0xFF60A5FA);

  String _filter = 'All';
  CompanyManagementJob? _assignJob;
  String? _selectedMechanicKey;

  static const _filters = ['All', 'Pending Review', 'Unassigned', 'Assigned', 'In Progress'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final vm = context.read<CompanyViewModel>();
      vm.loadCompanyTeam();
      vm.loadCompanyJobs(tab: _companyJobsTabQueryForFilter(_filter));
    });
  }

  /// Maps Job Management tabs to API `tab` query (snake_case). Omit for **All**.
  String? _companyJobsTabQueryForFilter(String filter) {
    switch (filter) {
      case 'All':
        return null;
      case 'Pending Review':
        return 'pending_review';
      case 'Unassigned':
        return 'unassigned';
      case 'Assigned':
        return 'assigned';
      case 'In Progress':
        return 'in_progress';
      default:
        return null;
    }
  }

  (Color bg, Color fg, Color bd) _statusToneColors(String tone) {
    switch (tone.toLowerCase()) {
      case 'yellow':
        return (AppColors.primary.withValues(alpha: 0.10), AppColors.primary, AppColors.primary.withValues(alpha: 0.30));
      case 'green':
        return (AppColors.green.withValues(alpha: 0.10), AppColors.green, AppColors.green.withValues(alpha: 0.30));
      case 'blue':
        return (_blueUrgent.withValues(alpha: 0.10), _blueUrgent, _blueUrgent.withValues(alpha: 0.30));
      case 'amber':
      case 'orange':
        return (AppColors.orange.withValues(alpha: 0.10), AppColors.orange, AppColors.orange.withValues(alpha: 0.30));
      case 'neutral':
        return (_chipInactive, AppColors.textMuted, AppColors.border2);
      default:
        return (_chipInactive, AppColors.textMuted, AppColors.border2);
    }
  }

  IconData _companyJobActionIcon(String iconKey) {
    switch (iconKey.toUpperCase()) {
      case 'EYE':
        return Icons.visibility_outlined;
      case 'USER_PLUS':
        return Icons.person_add_alt_1_outlined;
      case 'SWAP':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.chevron_right_rounded;
    }
  }

  String _formatGbpAmount(double? v) {
    if (v == null) return '—';
    if (v == v.roundToDouble()) return '£${v.round()}';
    return '£${v.toStringAsFixed(2)}';
  }

  void _applyFilter(String f) {
    setState(() => _filter = f);
    context.read<CompanyViewModel>().loadCompanyJobs(tab: _companyJobsTabQueryForFilter(f));
  }

  int _badgeForChip(CompanyJobsMeta? meta, String label) {
    final tc = meta?.tabCounts;
    if (tc == null) {
      if (label == 'Pending Review') return meta?.pendingReviewCount ?? 0;
      return 0;
    }
    return tc.countForUiTab(label);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyViewModel>();
    final jobs = vm.companyJobs;
    final meta = vm.companyJobsMeta;
    final pending = meta?.pendingReviewCount ?? 0;

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
                            'Job Management',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                          ),
                          SizedBox(height: 4),
                          Text('Assign & track jobs', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (pending > 0)
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
                              '$pending',
                              style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              ' pending',
                              style: TextStyle(color: AppColors.primary.withValues(alpha: 0.80), fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _filters) ...[
                        if (f != _filters.first) const SizedBox(width: 8),
                        _filterChip(
                          label: f,
                          selected: _filter == f,
                          badge: f == 'Pending Review' ? _badgeForChip(meta, f) : null,
                          onTap: () => _applyFilter(f),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: vm.companyJobsLoading && jobs.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : vm.companyJobsError != null && jobs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                vm.companyJobsError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => vm.loadCompanyJobs(tab: _companyJobsTabQueryForFilter(_filter)),
                                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                                child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: vm.reloadCompanyJobs,
                        child: jobs.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  Center(child: Text('No jobs in this tab.', style: TextStyle(color: AppColors.textMuted, fontSize: 14))),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: jobs.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (_, i) => _buildJobCard(context, vm, jobs[i]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required bool selected, required VoidCallback onTap, int? badge}) {
    return Material(
      color: selected ? AppColors.primary : _chipInactive,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? Colors.transparent : AppColors.border2),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.black : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (badge != null && badge > 0)
                Positioned(
                  right: -14,
                  top: -14,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                    child: Text(
                      '$badge',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, height: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, CompanyViewModel vm, CompanyManagementJob job) {
    final statusColors = _statusToneColors(job.statusUi.tone);
    final urgency = job.urgencyUi;
    final amount = job.displayAmount;
    final hasMechanic = job.mechanic != null;
    final borderEmphasis = job.statusUi.tone.toLowerCase() == 'yellow';
    final invoiceLabel = job.invoice?.label ?? 'Total invoice';
    final timeLine = job.timeRowLabel();
    final action = job.primaryAction;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _headerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderEmphasis ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border2),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            job.jobCode.isNotEmpty ? job.jobCode : job.id,
                            style: const TextStyle(color: AppColors.textHint, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (job.statusUi.label.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColors.$1,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColors.$3),
                            ),
                            child: Text(
                              job.statusUi.label.toUpperCase(),
                              style: TextStyle(color: statusColors.$2, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                      ],
                    ),
                    if (urgency != null && urgency.label.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusToneColors(urgency.tone).$1,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _statusToneColors(urgency.tone).$3),
                        ),
                        child: Text(
                          urgency.label,
                          style: TextStyle(color: _statusToneColors(urgency.tone).$2, fontSize: 8, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      job.displayVehicle,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(job.title, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              if (!hasMechanic && amount != null)
                Text(
                  _formatGbpAmount(amount),
                  style: const TextStyle(color: AppColors.green, fontSize: 18, fontWeight: FontWeight.w900),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 15, color: AppColors.textMuted.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  job.locationLabel.isNotEmpty ? job.locationLabel : '—',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ],
          ),
          if (timeLine.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: AppColors.textMuted.withValues(alpha: 0.9)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(timeLine, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ),
              ],
            ),
          ],
          if (hasMechanic) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _chipInactive,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border2),
              ),
              child: Row(
                children: [
                  SizedBox(width: 36, height: 36, child: _teamMemberAvatarCircle(job.mechanic!.profilePhotoUrl, diameter: 36, iconScale: 0.5)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.mechanic!.displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (job.mechanic!.workStatusLine.isNotEmpty)
                          Text(
                            job.mechanic!.workStatusLine,
                            style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.85), fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatGbpAmount(amount),
                        style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(invoiceLabel, style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.85), fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _onPrimaryAction(context, vm, job),
              icon: Icon(_companyJobActionIcon(action.icon), size: 18, color: Colors.black),
              label: Text(action.label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onPrimaryAction(BuildContext context, CompanyViewModel vm, CompanyManagementJob job) async {
    final key = job.primaryAction?.key ?? '';
    if (key == 'ASSIGN_MECHANIC' || key == 'REASSIGN_MECHANIC') {
      setState(() {
        _assignJob = job;
        _selectedMechanicKey = null;
      });
      _showAssignSheet(context);
      return;
    }
    if (key == 'REVIEW_APPROVE_INVOICE' || key.contains('APPROVE')) {
      final path = job.primaryAction?.path;
      if (path == null || path.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No approval endpoint for this job.')));
        }
        return;
      }
      _showInvoiceReviewSheet(context, vm, job);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This action is not connected yet.')));
  }

  /// Stable list-selection key (prefer Mongo `_id` from team payload).
  static String _companyTeamMemberUiKey(CompanyTeamMember m) {
    final id = m.mongoId.trim();
    if (id.isNotEmpty) return id;
    return m.employeeId.trim();
  }

  /// Mechanic id for `POST …/company/jobs/:id/assign` body (Mongo user id when present).
  static String _companyTeamMemberMechanicIdForAssign(CompanyTeamMember m) {
    final mongo = m.mongoId.trim();
    if (mongo.isNotEmpty) return mongo;
    return m.employeeId.trim();
  }

  void _showAssignSheet(BuildContext messengerContext) {
    final messenger = ScaffoldMessenger.of(messengerContext);
    final companyVm = messengerContext.read<CompanyViewModel>();
    showModalBottomSheet<void>(
      context: messengerContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ChangeNotifierProvider<CompanyViewModel>.value(
          value: companyVm,
          child: Consumer<CompanyViewModel>(
            builder: (ctx, vm, _) {
              return StatefulBuilder(
                builder: (ctx, setModal) {
                  return DraggableScrollableSheet(
                    initialChildSize: 0.72,
                    minChildSize: 0.4,
                    maxChildSize: 0.92,
                    builder: (_, scrollController) {
                      final mechanics = vm.teamMembers;
                      return Container(
                        decoration: const BoxDecoration(
                          color: _headerBg,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          border: Border(top: BorderSide(color: AppColors.border2)),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Assign Mechanic', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_assignJob?.jobCode ?? ''} · ${_assignJob?.displayVehicle ?? ''}',
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      setState(() {
                                        _assignJob = null;
                                        _selectedMechanicKey = null;
                                      });
                                    },
                                    icon: Icon(Icons.close_rounded, color: AppColors.textMuted.withValues(alpha: 0.9)),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: AppColors.border2),
                            Expanded(
                              child: vm.teamLoading && mechanics.isEmpty
                                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                                  : mechanics.isEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: Text(
                                              vm.teamError ??
                                                  'No mechanics available. Pull up Team Management or check your connection.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 13),
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          controller: scrollController,
                                          padding: const EdgeInsets.all(16),
                                          itemCount: mechanics.length,
                                          itemBuilder: (_, i) {
                                            final m = mechanics[i];
                                            final rowKey = _companyTeamMemberUiKey(m);
                                            final sel = _selectedMechanicKey != null && _selectedMechanicKey == rowKey;
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Material(
                                                color: _chipInactive,
                                                borderRadius: BorderRadius.circular(14),
                                                child: InkWell(
                                                  onTap: () {
                                                    final k = rowKey;
                                                    setModal(() => _selectedMechanicKey = k);
                                                    setState(() => _selectedMechanicKey = k);
                                                  },
                                                  borderRadius: BorderRadius.circular(14),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(14),
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(14),
                                                      border: Border.all(
                                                        color: sel ? AppColors.primary : AppColors.border2,
                                                        width: sel ? 2 : 1,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            SizedBox(width: 40, height: 40, child: _teamMemberAvatarCircle(m.profilePhotoUrl, diameter: 40, iconScale: 0.5)),
                                                            const SizedBox(width: 12),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(m.displayName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                                                  Text(m.employeeId, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                                                ],
                                                              ),
                                                            ),
                                                            _mechToneDot(m.workStatusUi.dotTone, greenGlow: m.workStatusUi.key == 'active'),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 10),
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.star_rounded, size: 16, color: AppColors.primary),
                                                            const SizedBox(width: 4),
                                                            Text(m.ratingDisplay, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                                                            const SizedBox(width: 12),
                                                            Expanded(
                                                              child: Text(
                                                                '${m.activeJobs} active · ${m.jobsCompleted} completed',
                                                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.paddingOf(ctx).bottom),
                              child: FilledButton(
                                onPressed:
                                    (_selectedMechanicKey == null || _selectedMechanicKey!.isEmpty || vm.companyJobAssignBusy)
                                        ? null
                                        : () async {
                                            final job = _assignJob;
                                            if (job == null || job.id.trim().isEmpty) {
                                              messenger.showSnackBar(const SnackBar(content: Text('Cannot assign: job is not linked to the server.')));
                                              return;
                                            }
                                            CompanyTeamMember? chosen;
                                            for (final cm in mechanics) {
                                              if (_companyTeamMemberUiKey(cm) == _selectedMechanicKey) {
                                                chosen = cm;
                                                break;
                                              }
                                            }
                                            if (chosen == null) {
                                              messenger.showSnackBar(const SnackBar(content: Text('Selected mechanic not found.')));
                                              return;
                                            }
                                            final mechanicPayload = _companyTeamMemberMechanicIdForAssign(chosen);
                                            if (mechanicPayload.isEmpty) {
                                              messenger.showSnackBar(const SnackBar(content: Text('Mechanic has no assignable id.')));
                                              return;
                                            }
                                            FocusScope.of(ctx).unfocus();
                                            try {
                                              await vm.assignCompanyJobMechanic(jobId: job.id.trim(), mechanicId: mechanicPayload);
                                              if (!messengerContext.mounted) return;
                                              Navigator.pop(ctx);
                                              messenger.showSnackBar(const SnackBar(content: Text('Mechanic assigned.')));
                                              setState(() {
                                                _assignJob = null;
                                                _selectedMechanicKey = null;
                                              });
                                            } catch (e) {
                                              messenger.showSnackBar(SnackBar(content: Text(e.toString())));
                                            }
                                          },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.30),
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: vm.companyJobAssignBusy
                                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black))
                                    : const Text('Confirm Assignment', style: TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showInvoiceReviewSheet(BuildContext context, CompanyViewModel vm, CompanyManagementJob job) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _CompanyJobInvoiceReviewSheet(
          job: job,
          onClose: () => Navigator.pop(ctx),
          onApprove: (body) async {
            final path = job.primaryAction?.path;
            if (path == null || path.isEmpty) {
              throw Exception('No approval URL for this job');
            }
            await vm.patchCompanyJobPath(path, body: body);
            await vm.reloadCompanyJobs();
          },
        ),
      ),
    );
  }
}

class _CompanyJobInvoiceReviewSheet extends StatefulWidget {
  const _CompanyJobInvoiceReviewSheet({
    required this.job,
    required this.onClose,
    required this.onApprove,
  });

  final CompanyManagementJob job;
  final VoidCallback onClose;
  final Future<void> Function(Map<String, dynamic> approveBody) onApprove;

  @override
  State<_CompanyJobInvoiceReviewSheet> createState() => _CompanyJobInvoiceReviewSheetState();
}

class _CompanyJobInvoiceReviewSheetState extends State<_CompanyJobInvoiceReviewSheet> {
  bool _busy = false;

  static const Color _sheetBg = Color(0xFF0F0F0F);
  static const Color _fieldBg = Color(0xFF1A1A1A);
  static const double _defaultLabourRate = 65;

  late final TextEditingController _callOutCtrl;
  late final TextEditingController _labourHoursCtrl;
  late double _labourRate;
  final List<({TextEditingController name, TextEditingController cost})> _parts = [];

  @override
  void initState() {
    super.initState();
    final inv = widget.job.invoice;
    _labourRate = inv?.labourRatePerHour ?? _defaultLabourRate;
    _callOutCtrl = TextEditingController(text: _editableMoneyFromApi(inv?.callOutCharge));
    _labourHoursCtrl = TextEditingController(text: _editableMoneyFromApi(inv?.labourHours));
    final lines = inv?.partsLines ?? const <CompanyInvoiceLineItem>[];
    for (final p in lines) {
      _parts.add((
        name: TextEditingController(text: p.description),
        cost: TextEditingController(text: _editableMoneyFromApi(p.amount)),
      ));
    }
  }

  @override
  void dispose() {
    _callOutCtrl.dispose();
    _labourHoursCtrl.dispose();
    for (final p in _parts) {
      p.name.dispose();
      p.cost.dispose();
    }
    super.dispose();
  }

  static String _editableMoneyFromApi(num? v) {
    if (v == null) return '';
    final d = v.toDouble();
    if (d == d.roundToDouble()) return '${d.round()}';
    return d.toStringAsFixed(2);
  }

  String _formatMoney(double? v) {
    if (v == null) return '—';
    if (v == v.roundToDouble()) return '£${v.round()}';
    return '£${v.toStringAsFixed(2)}';
  }

  String get _rateLabel => _labourRate == _labourRate.roundToDouble()
      ? '@ £${_labourRate.round()}/hr'
      : '@ £${_labourRate.toStringAsFixed(2)}/hr';

  double get _callOutVal => double.tryParse(_callOutCtrl.text.trim()) ?? 0;
  double get _labourHoursVal => double.tryParse(_labourHoursCtrl.text.trim()) ?? 0;
  double get _labourTotal => _labourHoursVal * _labourRate;

  double get _partsTotal =>
      _parts.fold<double>(0, (sum, p) => sum + (double.tryParse(p.cost.text.trim()) ?? 0));

  double get _invoiceTotalComputed => _callOutVal + _labourTotal + _partsTotal;

  Map<String, dynamic> _buildApproveBody() {
    final partsPayload = <Map<String, dynamic>>[];
    for (final p in _parts) {
      final desc = p.name.text.trim();
      final amt = double.tryParse(p.cost.text.trim()) ?? 0;
      if (desc.isEmpty && amt == 0) continue;
      partsPayload.add({
        'description': desc.isEmpty ? 'Part' : desc,
        'amount': amt,
      });
    }
    final total =
        _callOutVal + (_labourHoursVal * _labourRate) + partsPayload.fold<double>(0, (s, e) => s + ((e['amount'] as num).toDouble()));
    return <String, dynamic>{
      'invoice': <String, dynamic>{
        'callOutCharge': _callOutVal,
        'labourHours': _labourHoursVal,
        'labourRatePerHour': _labourRate,
        'parts': partsPayload,
      },
      'totalAmount': total,
    };
  }

  Future<void> _approve() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onApprove(_buildApproveBody());
      if (mounted) widget.onClose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final j = widget.job;
    final mech = j.mechanic;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      snap: true,
      snapSizes: const [0.55, 0.82, 0.88, 0.94],
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
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3A3A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Review Invoice', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(
                                '${j.jobCode} · ${j.displayVehicle}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(onPressed: widget.onClose, icon: Icon(Icons.close_rounded, color: AppColors.textMuted.withValues(alpha: 0.9))),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border2),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 12 + bottom),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'JOB DETAILS',
                            style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 14),
                          _kv('Job code', j.jobCode.isNotEmpty ? j.jobCode : '—'),
                          if (j.statusUi.label.isNotEmpty) _kv('Status', j.statusUi.label),
                          _kv('Issue', j.title.isNotEmpty ? j.title : '—'),
                          _kv('Location', j.locationLabel.isNotEmpty ? j.locationLabel : '—'),
                          if (mech != null) ...[
                            _kv('Mechanic', mech.displayName),
                            if (mech.workStatusLine.isNotEmpty) _kv('Mechanic status', mech.workStatusLine),
                          ],
                          if (j.fleetCompanyName.isNotEmpty) _kv('Fleet operator', j.fleetCompanyName),
                          if (j.timeRowLabel().isNotEmpty) _kv('Completed', j.timeRowLabel()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _jobInvoiceEditorCard(j),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF60A5FA).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.30)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.help_outline_rounded, color: const Color(0xFF60A5FA).withValues(alpha: 0.95), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Company Review',
                                  style: TextStyle(color: const Color(0xFF60A5FA).withValues(alpha: 0.95), fontSize: 12, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Review and approve this invoice to finalize the job. The amount will be charged to the fleet operator.',
                                  style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.9), fontSize: 11, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8 + bottom),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + bottom),
                child: Column(
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _approve,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _busy
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text('✓ Approve & Complete Job', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy ? null : widget.onClose,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: AppColors.border2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _jobInvoiceEditorCard(CompanyManagementJob j) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'JOB INVOICE',
                  style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
          if ((j.invoice?.invoiceNo ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _kv('Invoice #', j.invoice!.invoiceNo!.trim()),
          ],
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
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              prefixText: '£  ',
              prefixStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _labourHoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
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
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border2),
                ),
                child: Text(
                  _rateLabel,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Labour total: £${_labourTotal.toStringAsFixed(2)}',
            style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.9), fontSize: 11),
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
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        const Text('+ Add Part', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
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
                border: Border.all(color: AppColors.border2),
              ),
              child: Column(
                children: [
                  Text('No parts added', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "+ Add Part" to itemise parts.',
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
                  border: Border.all(color: AppColors.border2),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _parts[i].name,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Part description',
                              hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.8), fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF1A1A1A),
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
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () => setState(() {
                              _parts[i].name.dispose();
                              _parts[i].cost.dispose();
                              _parts.removeAt(i);
                            }),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border2),
                              ),
                              child: Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.textMuted.withValues(alpha: 0.9)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _parts[i].cost,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        prefixText: '£ ',
                        prefixStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                        hintText: '0',
                        hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.8), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
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
              SizedBox(height: i < _parts.length - 1 ? 10 : 12),
            ],
          ],
          Text(
            'Parts total: £${_partsTotal.toStringAsFixed(2)}',
            style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.9), fontSize: 11),
          ),
          if (j.finalAmount != null && j.acceptedAmount != null && j.finalAmount != j.acceptedAmount) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border2),
            const SizedBox(height: 12),
            _kv('Quoted / accepted', '£${j.acceptedAmount!.toStringAsFixed(j.acceptedAmount == j.acceptedAmount!.roundToDouble() ? 0 : 2)}'),
            _kv('Job final amount', '£${j.finalAmount!.toStringAsFixed(j.finalAmount == j.finalAmount!.roundToDouble() ? 0 : 2)}'),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border2),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Total invoice',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              Text(
                _formatMoney(_invoiceTotalComputed),
                style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if ((j.invoice?.currency ?? j.currency).trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  (j.invoice?.currency ?? j.currency).trim(),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ),
          if ((j.invoice?.totalAmount != null &&
                  (_invoiceTotalComputed - j.invoice!.totalAmount!).abs() > 0.015))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Listed total earlier: ${_formatMoney(j.invoice!.totalAmount)} · approval sends computed total above.',
                style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.88), fontSize: 10, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.25)),
            ),
          ),
          Expanded(child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3))),
        ],
      ),
    );
  }
}

// ─── Team Management (`CompanyTeam` / check.tsx) ─────────────────────────────

class CompanyTeamManagementView extends StatefulWidget {
  const CompanyTeamManagementView({super.key});

  @override
  State<CompanyTeamManagementView> createState() => _CompanyTeamManagementViewState();
}

class _CompanyTeamManagementViewState extends State<CompanyTeamManagementView> {
  static const Color _headerBg = Color(0xFF0F0F0F);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<CompanyViewModel>().loadCompanyTeam();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyViewModel>();
    final members = vm.teamMembers;
    final pendingCount = vm.teamMeta?.pendingInviteCount ?? vm.teamPendingInvites.length;

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Team Management',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pendingCount > 0 ? 'Manage your mechanics · $pendingCount pending invite${pendingCount == 1 ? '' : 's'}' : 'Manage your mechanics',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showInviteSheet(context),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18, color: Colors.black),
                  label: const Text('Invite', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: vm.teamLoading && members.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : vm.teamError != null && members.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(vm.teamError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => vm.loadCompanyTeam(),
                                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                                child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : members.isEmpty
                        ? const Center(child: Text('No team members yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 14)))
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: vm.loadCompanyTeam,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: members.length,
                              itemBuilder: (_, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _mechanicCard(context, members[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _mechanicCard(BuildContext context, CompanyTeamMember m) {
    final label = (m.workStatusUi.label.isNotEmpty) ? m.workStatusUi.label : m.workStatusUi.key;
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
              _teamMemberAvatarCircle(m.profilePhotoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.displayName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(m.employeeId, style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                  ],
                ),
              ),
              Row(
                children: [
                  _mechToneDot(m.workStatusUi.dotTone, greenGlow: m.workStatusUi.key == 'active'),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: _companyTeamLabelColor(m.workStatusUi.tone),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCell(m.ratingDisplay, 'Rating', AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: _statCell('${m.activeJobs}', 'Active', AppColors.orange)),
              const SizedBox(width: 10),
              Expanded(child: _statCell('${m.jobsCompleted}', 'Done', AppColors.green)),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showMechanicDetail(context, m),
            icon: Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textMuted.withValues(alpha: 0.9)),
            label: Text(m.cardAction?.label ?? 'More', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontWeight: FontWeight.w800, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              side: const BorderSide(color: AppColors.border2),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(String value, String label, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border2),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  void _showInviteSheet(BuildContext context) {
    final companyVm = context.read<CompanyViewModel>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottom = MediaQuery.paddingOf(sheetContext).bottom;
        final kb = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: kb),
          child: ChangeNotifierProvider<CompanyViewModel>.value(
            value: companyVm,
            child: _CompanyTeamInviteSheetContent(bottomInset: bottom),
          ),
        );
      },
    );
  }

  Future<void> _dialTeamMemberPhone(BuildContext messengerContext, CompanyTeamMember m) async {
    final raw = m.phone.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.maybeOf(messengerContext)?.showSnackBar(
        const SnackBar(content: Text('No phone number on file')),
      );
      return;
    }
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) {
      ScaffoldMessenger.maybeOf(messengerContext)?.showSnackBar(
        const SnackBar(content: Text('No phone number on file')),
      );
      return;
    }
    final uri = Uri.parse('tel:$digits');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && messengerContext.mounted) {
        ScaffoldMessenger.maybeOf(messengerContext)?.showSnackBar(
          const SnackBar(content: Text('Unable to start call')),
        );
      }
    } catch (_) {
      if (messengerContext.mounted) {
        ScaffoldMessenger.maybeOf(messengerContext)?.showSnackBar(
          const SnackBar(content: Text('Unable to start call')),
        );
      }
    }
  }

  void _showMechanicDetail(BuildContext context, CompanyTeamMember m) {
    final label = (m.workStatusUi.label.isNotEmpty) ? m.workStatusUi.label : m.workStatusUi.key;
    final companyVm = context.read<CompanyViewModel>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => ChangeNotifierProvider<CompanyViewModel>.value(
        value: companyVm,
        child: Consumer<CompanyViewModel>(
          builder: (sheetCtx, vm, __) {
          return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: _headerBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: AppColors.border2)),
            ),
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.paddingOf(sheetCtx).bottom),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _teamMemberAvatarCircle(m.profilePhotoUrl, diameter: 56, iconScale: 0.54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          Text(m.employeeId, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          if (m.jobTitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(m.jobTitle, style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.95), fontSize: 11)),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _mechToneDot(m.workStatusUi.dotTone, greenGlow: m.workStatusUi.key == 'active'),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  color: _companyTeamLabelColor(m.workStatusUi.tone),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'PERFORMANCE',
                  style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _bigStat(m.ratingDisplay, 'RATING', AppColors.primary)),
                    const SizedBox(width: 10),
                    Expanded(child: _bigStat('${m.activeJobs}', 'ACTIVE', AppColors.orange)),
                    const SizedBox(width: 10),
                    Expanded(child: _bigStat('${m.jobsCompleted}', 'DONE', AppColors.green)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'CONTACT',
                  style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _detailRow('Email', m.email.isNotEmpty ? m.email : '—'),
                      _detailRow('Phone', m.phone.isNotEmpty ? m.phone : '—'),
                      _detailRow('Joined', m.joinedMonthLabel.isNotEmpty ? m.joinedMonthLabel : '—'),
                      if (m.ratingCount > 0) _detailRow('Reviews', '${m.ratingCount}'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'SPECIALTIES',
                        style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: m.skillsLabels.map<Widget>(
                              (s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
                                ),
                                child: Text(s, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            )
                            .toList(),
                      ),
                      if (m.skillsLabels.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          child: Text('—', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.8), fontSize: 12)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: m.phone.trim().isEmpty ? null : () => _dialTeamMemberPhone(sheetCtx, m),
                  icon: const Icon(Icons.phone_outlined, size: 18, color: Colors.black),
                  label: const Text('CALL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 52),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 22),
                OutlinedButton(
                  onPressed: vm.teamMemberRemoveLoading
                      ? null
                      : () => _confirmRemoveFromTeam(context, sheetCtx, m),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: BorderSide(color: AppColors.red.withValues(alpha: 0.30)),
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: AppColors.red.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: vm.teamMemberRemoveLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.red),
                        )
                      : const Text('Remove from Team', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ],
            ),
          );
        },
      );
        },
      ),
    ),
    );
  }

  Future<void> _confirmRemoveFromTeam(BuildContext hostContext, BuildContext sheetCtx, CompanyTeamMember m) async {
    final ok = await showDialog<bool>(
      context: sheetCtx,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          surfaceTintColor: Colors.transparent,
          title: const Text('Remove from team?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          content: Text(
            '${m.displayName} will be removed from your company team.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Remove', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
    if (ok != true || !sheetCtx.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(hostContext) ?? ScaffoldMessenger.maybeOf(sheetCtx);
    try {
      await sheetCtx.read<CompanyViewModel>().removeCompanyTeamMember(m);
      if (!sheetCtx.mounted) return;
      Navigator.pop(sheetCtx);
      messenger?.showSnackBar(
        SnackBar(content: Text('${m.displayName} removed'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!sheetCtx.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(sheetCtx.read<CompanyViewModel>().teamMemberRemoveError ?? e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _bigStat(String v, String l, Color c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(v, style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(l, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _detailRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Flexible(child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _CompanyTeamInviteSheetContent extends StatefulWidget {
  const _CompanyTeamInviteSheetContent({required this.bottomInset});

  final double bottomInset;

  @override
  State<_CompanyTeamInviteSheetContent> createState() => _CompanyTeamInviteSheetContentState();
}

class _CompanyTeamInviteSheetContentState extends State<_CompanyTeamInviteSheetContent> {
  static const Color _headerBg = Color(0xFF0F0F0F);
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final raw = _email.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an email address'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (!raw.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final vm = context.read<CompanyViewModel>();
    try {
      final apiMessage = await vm.sendCompanyTeamInvitation(raw);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiMessage ?? 'Invitation sent'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final msg = vm.teamInviteError ?? 'Could not send invitation';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyViewModel>();

    return Container(
      padding: EdgeInsets.only(bottom: widget.bottomInset),
      decoration: const BoxDecoration(
        color: _headerBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.border2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Expanded(child: Text('Invite Mechanic', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.textMuted.withValues(alpha: 0.9))),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border2),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Email Address', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    hintText: 'mechanic@example.com',
                    hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.6)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border2)),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: vm.teamInviteSending ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: vm.teamInviteSending
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Send Invitation', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Company Profile (`CompanyProfile` / check.tsx) ──────────────────────────

class CompanyProfileFullView extends StatefulWidget {
  const CompanyProfileFullView({super.key});

  static Widget _profileStatTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  static Widget _profileSection({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Text(
              title,
              style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  static Widget _profileKv(String k, String v, {bool strong = false, bool mutedValue = false, Color? valueColor, bool multiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: multiline ? 2 : 1,
            child: Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          Expanded(
            flex: multiline ? 3 : 1,
            child: Text(
              v,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? (mutedValue ? AppColors.textMuted : (strong ? Colors.white : AppColors.textSecondary)),
                fontSize: 12,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
                height: multiline ? 1.35 : 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _profileNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF0F0F0F),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E1E1E)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textHint.withValues(alpha: 0.8), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<CompanyProfileFullView> createState() => _CompanyProfileFullViewState();
}

class _CompanyProfileFullViewState extends State<CompanyProfileFullView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CompanyViewModel>().loadCompanyMe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyViewModel>();
    final me = vm.companyMeSnapshot;
    final members = vm.teamMembers;
    final activeOnlineFallback =
        members.isEmpty ? (vm.dashboard?.onlineMechanics ?? 0) : members.where((m) => m.workStatusUi.key == 'active').length;
    final activeJobSumFallback = members.isEmpty ? (vm.dashboard?.activeJobs ?? 0) : members.fold<int>(0, (a, m) => a + m.activeJobs);
    final mechanicCountFallback =
        vm.teamMeta?.memberCount ?? (members.isNotEmpty ? members.length : (vm.dashboard?.mechanics ?? 0));

    final ov = me?.teamOverview;
    final totalMechanicsShown = ov != null ? ov.totalMechanics : mechanicCountFallback;
    final onlineNowShown = ov != null ? ov.onlineNow : activeOnlineFallback;
    final activeJobsShown = ov != null ? ov.activeJobs : activeJobSumFallback;

    final metrics = me?.metrics;
    final companyTitle = (me?.companyName ?? '').trim().isNotEmpty ? me!.companyName.trim() : 'Company';
    final ratingVal = metrics?.avgRating ?? 0;
    final filledStars = metrics?.starFilledCount ?? 0;

    final bank = me?.bankBilling;

    final listChildren = <Widget>[
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COMPANY',
              style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4),
            ),
            SizedBox(height: 4),
            Text('Profile', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
      if (vm.companyMeError != null && vm.companyMeError!.trim().isNotEmpty && me == null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(vm.companyMeError!.trim(), style: TextStyle(color: AppColors.red.withValues(alpha: 0.9), fontSize: 12)),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: vm.loadCompanyMe,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.30), width: 2),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child:
                      ((me?.profilePhotoUrl ?? '').trim().isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: me!.profilePhotoUrl.trim(),
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Icon(Icons.business_center_rounded, color: AppColors.primary, size: 40),
                              errorWidget: (_, __, ___) => Icon(Icons.business_center_rounded, color: AppColors.primary, size: 40),
                            )
                          : Icon(Icons.business_center_rounded, color: AppColors.primary, size: 40),
                ),
                if (me?.profileCompleted == true)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF080808), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: const Text('✓', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              companyTitle,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...List.generate(
                  5,
                  (i) =>
                      Icon(Icons.star_rounded, size: 16, color: i < filledStars ? AppColors.primary : AppColors.textHint.withValues(alpha: 0.35)),
                ),
                const SizedBox(width: 6),
                Text(
                  ratingVal > 0 ? (metrics?.avgRatingLabel ?? '') : '—',
                  style: TextStyle(color: ratingVal > 0 ? AppColors.primary : AppColors.textHint, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(child: CompanyProfileFullView._profileStatTile(metrics?.totalJobsLabel ?? '—', 'Total Jobs')),
            const SizedBox(width: 8),
            Expanded(child: CompanyProfileFullView._profileStatTile(metrics?.avgRatingLabel ?? '—', 'Avg Rating')),
            const SizedBox(width: 8),
            Expanded(child: CompanyProfileFullView._profileStatTile(metrics?.responseLabel ?? '—', 'Response')),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: FilledButton.icon(
          onPressed: () => vm.setScreen('company-edit-profile'),
          icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.black),
          label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CompanyProfileFullView._profileSection(
          title: 'COMPANY DETAILS',
          child: Column(
            children: [
              CompanyProfileFullView._profileKv(
                'Company Name',
                (me?.companyName ?? '').trim().isNotEmpty ? me!.companyName.trim() : '—',
                strong: true,
              ),
              CompanyProfileFullView._profileKv(
                'Registration',
                (me?.regNumber ?? '').trim().isNotEmpty ? me!.regNumber.trim() : '—',
                strong: true,
              ),
              CompanyProfileFullView._profileKv(
                'VAT Number',
                (me?.vatNumber ?? '').trim().isNotEmpty ? me!.vatNumber.trim() : '—',
                mutedValue: true,
              ),
              const Divider(height: 20, color: Color(0xFF1E1E1E)),
              CompanyProfileFullView._profileKv(
                'Base Location',
                (me?.baseLocationText ?? '').trim().isNotEmpty ? me!.baseLocationText.trim() : '—',
                strong: true,
              ),
              CompanyProfileFullView._profileKv(
                'Service Radius',
                (me != null && me.serviceRadiusMiles > 0) ? '${me.serviceRadiusMiles} miles' : '—',
                strong: true,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CompanyProfileFullView._profileSection(
          title: 'TEAM OVERVIEW',
          child: Column(
            children: [
              CompanyProfileFullView._profileKv('Total Mechanics', '$totalMechanicsShown', strong: true),
              CompanyProfileFullView._profileKv('Online Now', '$onlineNowShown', valueColor: AppColors.green),
              CompanyProfileFullView._profileKv('Active Jobs', '$activeJobsShown', valueColor: AppColors.orange),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CompanyProfileFullView._profileSection(
          title: 'BANK & BILLING',
          child: Column(
            children: [
              CompanyProfileFullView._profileKv('Bank', (bank?.bankName ?? '').isNotEmpty ? bank!.bankName : '—', strong: true),
              CompanyProfileFullView._profileKv(
                'Account',
                (bank?.accountMasked ?? '').isNotEmpty ? CompanyMeBankBilling.prettifyMasked(bank!.accountMasked) : '—',
                strong: true,
              ),
              CompanyProfileFullView._profileKv('Sort Code', (bank?.sortCode ?? '').trim().isNotEmpty ? bank!.sortCode.trim() : '—', strong: true),
              const Divider(height: 20, color: Color(0xFF1E1E1E)),
              CompanyProfileFullView._profileKv(
                'Billing Address',
                (bank?.billingAddress ?? '').trim().isNotEmpty ? bank!.billingAddress.trim() : '—',
                strong: true,
                multiline: true,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CompanyProfileFullView._profileNavTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Messages',
          subtitle: 'Chats with fleets, mechanics & TruckFix support',
          onTap: () => vm.setScreen('company-messages'),
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CompanyProfileFullView._profileNavTile(
          icon: Icons.payments_outlined,
          title: 'Earnings & Invoices',
          subtitle: 'View company revenue & job history',
          onTap: () => vm.setScreen('company-earnings'),
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CompanyProfileFullView._profileNavTile(
          icon: Icons.groups_outlined,
          title: 'Manage Team',
          subtitle: 'View & invite mechanics ($totalMechanicsShown total)',
          onTap: () => vm.setScreen('company-team'),
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CompanyProfileFullView._profileNavTile(
          icon: Icons.help_outline_rounded,
          title: 'Help & Support',
          subtitle: 'Contact TruckFix support team',
          onTap: () => showCompanyHelpSupportSheet(context),
        ),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: OutlinedButton.icon(
          onPressed: () async {
            await context.read<AuthViewModel>().logout();
            if (context.mounted) context.go(AppRoutes.login);
          },
          icon: const Icon(Icons.logout_rounded, color: AppColors.red, size: 18),
          label: const Text('Log Out', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600, fontSize: 12)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.red.withValues(alpha: 0.20)),
            backgroundColor: AppColors.red.withValues(alpha: 0.05),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Builder(
        builder: (_) {
          final since = (me?.memberSinceLabel ?? '').trim();
          final line = since.isEmpty ? 'TruckFix v2.4.1' : 'TruckFix v2.4.1 · Member since $since';
          return Text(
            line,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.7), fontSize: 10),
          );
        },
      ),
    ];

    return ColoredBox(
      color: const Color(0xFF080808),
      child: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: vm.loadCompanyMe,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: listChildren,
            ),
          ),
          if (vm.companyMeLoading && me == null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: const Color(0xFF1A1A1A),
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Earnings & Invoices (`CompanyEarnings` / check.tsx) ───────────────────

String _coFormatEarningsSummaryAmount(double v) {
  if (v.abs() >= 1000000) {
    final m = v / 1000000;
    return '£${m.toStringAsFixed(m == m.roundToDouble() ? 0 : 2)}M';
  }
  if (v.abs() >= 1000) {
    final k = v / 1000;
    return '£${k.toStringAsFixed(k == k.roundToDouble() ? (k.abs() >= 100 ? 0 : 1) : 2)}k';
  }
  if (v == v.roundToDouble()) return '£${v.round()}';
  return '£${v.toStringAsFixed(2)}';
}

String _coFormatBarAmount(double net) {
  if (net.abs() >= 1000) return '£${(net / 1000).toStringAsFixed(1)}k';
  if (net == net.roundToDouble()) return '£${net.round()}';
  return '£${net.toStringAsFixed(2)}';
}

String _earnPctLabel(double pct) => pct == pct.roundToDouble() ? '${pct.round()}' : pct.toStringAsFixed(1);

String _earnMoneyAbs(double amount, String currency) {
  final cur = currency.toUpperCase().trim().isEmpty ? 'GBP' : currency.trim().toUpperCase();
  if (cur == 'GBP') {
    if (amount == amount.roundToDouble()) return '£${amount.round()}';
    return '£${amount.toStringAsFixed(2)}';
  }
  if (amount == amount.roundToDouble()) return '$cur ${amount.round()}';
  return '$cur ${amount.toStringAsFixed(2)}';
}

String _earnNegativeMoney(double fee, String currency) {
  if (fee == 0) return _earnMoneyAbs(0, currency);
  return '-${_earnMoneyAbs(fee, currency)}'.replaceFirst('--', '-');
}

Map<String, dynamic>? _earningUnwrapEnvelope(Map<String, dynamic>? raw) {
  if (raw == null) return null;
  final d = raw['data'];
  if (d is Map<String, dynamic>) return d;
  return raw;
}

class CompanyEarningsView extends StatefulWidget {
  const CompanyEarningsView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<CompanyEarningsView> createState() => _CompanyEarningsViewState();
}

class _CompanyEarningsViewState extends State<CompanyEarningsView> {
  final Set<String> _expandedEarningJobIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<CompanyViewModel>();
      vm.loadCompanyEarningsSummary();
      vm.loadCompanyEarningsJobs();
    });
  }

  Future<void> _openViewInvoiceSheet(BuildContext context, CompanyViewModel vm, CompanyEarningsCompletedJob job) async {
    final messenger = ScaffoldMessenger.of(context);
    final href = job.primaryAction?.href?.trim();
    if (href == null || href.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('No invoice link for this job.')));
      return;
    }
    await showModalBottomSheet<void>(
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
                        future: vm.fetchCompanyAuthorizedGet(href),
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
                          final inv = _earningUnwrapEnvelope(envelope) ?? envelope;
                          return _earningInvoiceSheetBody(context, job, inv);
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

  Widget _earningInvoiceKv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(k, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ),
          Expanded(child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _earningInvoiceSheetBody(BuildContext context, CompanyEarningsCompletedJob job, Map<String, dynamic> inv) {
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
    final invoiceNoLine = invNoPick.isNotEmpty ? invNoPick : (job.invoice?.invoiceNo ?? '').trim();

    final statusPick = pickStr('status').trim();
    final statusLine = statusPick.isNotEmpty ? statusPick : (job.invoice?.status ?? '').trim();

    final paidPick = pickStr('paid_at', 'paidAt');
    final paidLine = paidPick.isNotEmpty ? paidPick : (job.invoice?.paidAtIso ?? '').trim();

    final grossPickStr = pickStr('gross_amount', 'grossAmount');
    final netPickStr = pickStr('net_amount', 'netAmount');
    final curPick = pickStr('currency');
    final cur = curPick.isEmpty ? job.currency : curPick;

    final pdfInline = pickStr('pdf_url', 'pdfUrl');
    final embeddedPdf = job.invoice?.pdfUrl?.trim();
    final effectivePdf = pdfInline.isNotEmpty ? pdfInline : (embeddedPdf ?? '');

    final rows = <Widget>[
      if (job.jobCode.isNotEmpty) _earningInvoiceKv('Job code', job.jobCode),
      if (invoiceNoLine.isNotEmpty) _earningInvoiceKv('Invoice #', invoiceNoLine),
      if (statusLine.isNotEmpty) _earningInvoiceKv('Status', statusLine),
      if (paidLine.isNotEmpty) _earningInvoiceKv('Paid', paidLine),
    ];

    final grossParsed = grossPickStr.isNotEmpty ? double.tryParse(grossPickStr) : null;
    rows.add(_earningInvoiceKv(
      'Gross',
      _earnMoneyAbs(grossParsed ?? job.grossAmount, cur),
    ));

    rows.add(_earningInvoiceKv(
      'Fee (${_earnPctLabel(job.platformFeePercent)}%)',
      _earnNegativeMoney(job.platformFee, cur),
    ));

    final netParsed = netPickStr.isNotEmpty ? double.tryParse(netPickStr) : null;
    rows.add(_earningInvoiceKv(
      'Net',
      _earnMoneyAbs(netParsed ?? job.netAmount, cur),
    ));

    if (effectivePdf.trim().startsWith('http')) {
      final url = effectivePdf.trim();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _summaryMini(String value, String label, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF374151), fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _earningJobCard(BuildContext context, CompanyViewModel vm, CompanyEarningsCompletedJob job) {
    final cid = job.id.trim().isNotEmpty ? job.id.trim() : job.jobCode.trim();
    final expanded = _expandedEarningJobIds.contains(cid);
    final mech = job.mechanic;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (expanded) {
                _expandedEarningJobIds.remove(cid);
              } else {
                _expandedEarningJobIds.add(cid);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
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
                            Text(
                              '${job.jobCode.isNotEmpty ? job.jobCode : '—'} · ${job.completedDateLabel.isNotEmpty ? job.completedDateLabel : '—'}',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              job.vehicleSubtitleLine,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              job.title.isNotEmpty ? job.title : job.description,
                              style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.95), fontSize: 12, height: 1.35),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (job.locationAddress.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                job.locationAddress,
                                style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.95), fontSize: 11),
                              ),
                            ],
                            if ((job.fleetCompanyName ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                job.fleetCompanyName!.trim(),
                                style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.9), fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _earnMoneyAbs(job.netAmount, job.currency),
                            style: TextStyle(color: AppColors.primary, fontSize: 19, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text('net earned', style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.9), fontSize: 9, fontWeight: FontWeight.w600)),
                          Icon(
                            expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (mech != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(width: 32, height: 32, child: _teamMemberAvatarCircle(mech.profilePhotoUrl, diameter: 32, iconScale: 0.5)),
                        const SizedBox(width: 10),
                        Icon(Icons.star_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(mech.ratingDisplay, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            mech.displayName,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (job.durationLabel.isNotEmpty) ...[
                          Icon(Icons.schedule_rounded, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            job.durationLabel,
                            style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.95), fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1A1A1A)),
                ),
                child: Column(
                  children: [
                    _earningBreakRow('Gross', _earnMoneyAbs(job.grossAmount, job.currency)),
                    const SizedBox(height: 10),
                    _earningBreakRow('Fee (${_earnPctLabel(job.platformFeePercent)}%)', _earnNegativeMoney(job.platformFee, job.currency)),
                    const SizedBox(height: 10),
                    _earningBreakRow('Net', _earnMoneyAbs(job.netAmount, job.currency), emphasize: true),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Builder(
              builder: (context) {
                final canInvoice = job.primaryAction?.href?.trim().isNotEmpty == true;
                return OutlinedButton.icon(
                  onPressed: canInvoice ? () => _openViewInvoiceSheet(context, vm, job) : null,
                  icon: Icon(Icons.description_outlined, size: 17, color: AppColors.primary.withValues(alpha: canInvoice ? 0.92 : 0.35)),
                  label: Text(
                    job.primaryAction?.label.isNotEmpty == true ? job.primaryAction!.label : 'View Invoice',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: canInvoice ? AppColors.primary : AppColors.textHint,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: canInvoice ? AppColors.border2 : AppColors.border2.withValues(alpha: 0.35)),
                    backgroundColor: const Color(0xFF111111),
                    minimumSize: const Size(double.infinity, 42),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _earningBreakRow(String label, String value, {bool emphasize = false}) {
    final vStyle = emphasize
        ? TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 14)
        : const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        Text(value, style: vStyle),
      ],
    );
  }

  List<Widget> _completedJobsTiles(BuildContext context, CompanyViewModel vm) {
    final err = vm.companyEarningsJobsError?.trim();
    final loading = vm.companyEarningsJobsLoading;
    final jobs = vm.companyEarningsJobs;

    if (loading && jobs.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Center(
            child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary)),
          ),
        ),
      ];
    }

    if (err != null && err.isNotEmpty && jobs.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(err, style: TextStyle(color: AppColors.red.withValues(alpha: 0.9), fontSize: 12, height: 1.35)),
        ),
        FilledButton(
          onPressed: () => vm.loadCompanyEarningsJobs(),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
          child: const Text('Retry jobs', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ];
    }

    if (jobs.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No completed jobs on this page.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      ];
    }

    return [
      for (final j in jobs) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _earningJobCard(context, vm, j),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyViewModel>();
    final sum = vm.companyEarningsSummary;
    final loading = vm.companyEarningsLoading;
    final errMsg = vm.companyEarningsError?.trim();

    Widget body;
    if (sum != null) {
      body = _loadedContent(context, vm, sum);
    } else if (loading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (errMsg != null && errMsg.isNotEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(errMsg, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.read<CompanyViewModel>().reloadCompanyEarningsScreen(),
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
    } else {
      body = Center(
        child: Text(
          'No earnings data yet.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFF080808),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Material(
                  color: const Color(0xFF111111),
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
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Icon(Icons.chevron_left_rounded, color: AppColors.textMuted, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COMPANY',
                        style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4),
                      ),
                      SizedBox(height: 2),
                      Text('Earnings & Invoices', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1A1A1A)),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _loadedContent(BuildContext context, CompanyViewModel vm, CompanyEarningsSummary sum) {
    final months = sum.monthlyNetIncome.months;
    final chart = sum.monthlyNetIncome;
    final maxNetRaw = months.isEmpty ? 0.0 : months.map((m) => m.netAmount).reduce(math.max);
    final maxDen = maxNetRaw <= 0 ? 1.0 : maxNetRaw;
    final metaTotal = vm.companyEarningsJobsMeta?.total ?? 0;
    final listedJobs = vm.companyEarningsJobs.length;
    final fallbackCount = sum.cards.completedJobs;
    final countForLabel = metaTotal > 0 ? metaTotal : (listedJobs > 0 ? listedJobs : fallbackCount);
    final jobLabel = '$countForLabel ${countForLabel == 1 ? 'job' : 'jobs'}';

    final listChildren = <Widget>[
      Row(
        children: [
          Expanded(
            child: _summaryMini(
              _coFormatEarningsSummaryAmount(sum.cards.monthGross),
              sum.display.monthGrossLabel.isNotEmpty ? sum.display.monthGrossLabel : 'GROSS',
              sum.display.monthGrossSubtext,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryMini(
              _coFormatEarningsSummaryAmount(sum.cards.monthNet),
              sum.display.monthNetLabel.isNotEmpty ? sum.display.monthNetLabel : 'NET',
              sum.display.monthNetSubtext,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryMini(
              _coFormatEarningsSummaryAmount(sum.cards.allTimeNet),
              sum.display.allTimeLabel.isNotEmpty ? sum.display.allTimeLabel : 'ALL-TIME',
              sum.display.allTimeSubtext,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1A1A1A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    chart.title.toUpperCase(),
                    style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                ),
                Text(
                  chart.rangeLabel,
                  style: TextStyle(color: AppColors.textHint, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (months.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No monthly data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textHint, fontSize: 11),
                ),
              )
            else
              SizedBox(
                height: 96,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final bar in months) ...[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _coFormatBarAmount(bar.netAmount),
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: bar.isCurrentMonth ? AppColors.primary : const Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 56,
                                width: double.infinity,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    widthFactor: 1,
                                    heightFactor: math.max(100 * bar.netAmount / maxDen, 4) / 100,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: bar.isCurrentMonth ? AppColors.primary : const Color(0xFF222222),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                bar.label.isNotEmpty ? bar.label : '—',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: bar.isCurrentMonth ? AppColors.primary : AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (chart.footnote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                chart.footnote,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF374151), fontSize: 9),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'COMPLETED JOBS',
            style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
          ),
          Text(jobLabel, style: TextStyle(color: AppColors.textHint, fontSize: 10)),
        ],
      ),
      const SizedBox(height: 10),
      ..._completedJobsTiles(context, vm),
    ];

    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.primary,
          onRefresh: vm.reloadCompanyEarningsScreen,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: listChildren,
          ),
        ),
        if (vm.companyEarningsLoading || vm.companyEarningsJobsLoading)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: const Color(0xFF1A1A1A),
              color: AppColors.primary,
            ),
          ),
      ],
    );
  }
}

// ─── Help & Support sheet (`HelpSupportSheet` / check.tsx) ─────────────────

enum CompanyHelpSupportRole { company, mechanicEmployee }

Future<void> showCompanyHelpSupportSheet(BuildContext context, {CompanyHelpSupportRole role = CompanyHelpSupportRole.company}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CompanyHelpSupportSheet(role: role),
  );
}

class _CompanyHelpSupportSheet extends StatefulWidget {
  const _CompanyHelpSupportSheet({required this.role});

  final CompanyHelpSupportRole role;

  @override
  State<_CompanyHelpSupportSheet> createState() => _CompanyHelpSupportSheetState();
}

class _CompanyHelpSupportSheetState extends State<_CompanyHelpSupportSheet> {
  String? _category;
  final _messageCtrl = TextEditingController();
  bool _sent = false;
  bool _submitting = false;

  final _supportApi = SupportApiService();

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  String _senderLine(String? email) {
    final e = email == null || email.trim().isEmpty ? 'your registered email' : email.trim();
    switch (widget.role) {
      case CompanyHelpSupportRole.company:
        return 'Sent from: $e · Company';
      case CompanyHelpSupportRole.mechanicEmployee:
        return 'Sent from: $e · Mechanic Employee';
    }
  }

  String _subjectForCategory(String id) {
    for (final c in _categories) {
      if (c.id == id) return c.label;
    }
    return id;
  }

  Future<void> _submit() async {
    if (!_canSend || _submitting || _category == null) return;
    final token = context.read<AuthViewModel>().session?.accessToken;
    if (token == null || token.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in again to send support messages.')));
      return;
    }
    final subjectLabel = _subjectForCategory(_category!);
    setState(() => _submitting = true);
    try {
      await _supportApi.createTicket(
        accessToken: token,
        subject: subjectLabel,
        message: _messageCtrl.text.trim(),
        category: supportTicketCategoryEnum(_category!),
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

  static const List<({String id, String label, IconData icon})> _categories = [
    (id: 'technical', label: 'Technical Issue', icon: Icons.build_outlined),
    (id: 'payment', label: 'Payment / Billing', icon: Icons.attach_money_rounded),
    (id: 'account', label: 'Account & Profile', icon: Icons.person_outline_rounded),
    (id: 'job', label: 'Job / Booking', icon: Icons.work_outline_rounded),
    (id: 'other', label: 'Other', icon: Icons.help_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final sessionEmail = context.watch<AuthViewModel>().session?.email;

    if (_sent) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0E0E0E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
          ),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: 20),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.check_circle_rounded, color: AppColors.green, size: 36),
                ),
                const SizedBox(height: 16),
                const Text('Message Sent!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(
                  'Our support team will respond within 24 hours via your registered email address.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sheetH = MediaQuery.of(context).size.height * 0.88;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: sheetH,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0E0E0E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
          ),
          child: Column(
            children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(999)))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Help & Support', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                        SizedBox(height: 2),
                        Text('We usually reply within 24 hours', style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: Icon(Icons.close_rounded, color: AppColors.textHint, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1A1A1A)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "WHAT'S THIS ABOUT?",
                      style: TextStyle(color: const Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.4,
                      children: _categories.map((c) {
                        final sel = _category == c.id;
                        return Material(
                          color: sel ? AppColors.primary.withValues(alpha: 0.08) : const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => setState(() => _category = c.id),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: sel ? AppColors.primary.withValues(alpha: 0.5) : const Color(0xFF1E1E1E)),
                              ),
                              child: Row(
                                children: [
                                  Icon(c.icon, size: 18, color: sel ? AppColors.primary : AppColors.textHint),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      c.label,
                                      style: TextStyle(
                                        color: sel ? AppColors.primary : const Color(0xFF9CA3AF),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'YOUR MESSAGE',
                      style: TextStyle(color: const Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _messageCtrl,
                      onChanged: (_) => setState(() {}),
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                      decoration: InputDecoration(
                        hintText: 'Describe your issue or question in as much detail as possible...',
                        hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.8), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF111111),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_senderLine(sessionEmail), style: TextStyle(color: AppColors.textHint, fontSize: 10)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
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
                          : Icon(Icons.send_rounded, size: 18, color: _sendButtonEnabled ? Colors.black : Colors.black.withValues(alpha: 0.4)),
                      label: Text(
                        'SEND MESSAGE',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.0,
                          color: _sendButtonEnabled ? Colors.black : Colors.black.withValues(alpha: 0.4),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: AppColors.textHint, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  bool get _canSend => _category != null && _messageCtrl.text.trim().isNotEmpty;

  bool get _sendButtonEnabled => _canSend && !_submitting;
}
