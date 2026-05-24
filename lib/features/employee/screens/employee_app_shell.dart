import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/services/mechanic_api_service.dart';
import '../../mechanic/screens/mechanic_app_shell.dart';
import '../../mechanic/viewmodel/mechanic_viewmodel.dart';
import 'employee_profile_page.dart';

class EmployeeViewModel extends ChangeNotifier {
  String screen = 'employee-jobs';

  void setScreen(String s) {
    screen = s;
    notifyListeners();
  }

  String get tabResolved => screen == 'employee-tracker' ? 'employee-jobs' : screen;
}

class EmployeeAppShell extends StatelessWidget {
  const EmployeeAppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (ctx) => MechanicViewModel(
            ctx.read<JobRepository>(),
            ctx.read<AuthRepository>(),
            MechanicApiService(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => EmployeeViewModel()),
      ],
      child: const _EmpScaffold(),
    );
  }
}

class _EmpScaffold extends StatelessWidget {
  const _EmpScaffold();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EmployeeViewModel>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const Expanded(
            child: _EmployeePageContent(),
          ),
          _EmpTabBar(vm: vm),
        ],
      ),
    );
  }
}

class _EmployeePageContent extends StatelessWidget {
  const _EmployeePageContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EmployeeViewModel>();
    if (vm.screen == 'employee-tracker') {
      return MechanicJobTrackerPage(
        onBack: () {
          context.read<MechanicViewModel>().clearJobTrackerSelection();
          vm.setScreen('employee-jobs');
        },
      );
    }
    if (vm.screen == 'employee-profile') {
      return const EmployeeProfilePage();
    }
    return const _EmployeeJobsList();
  }
}

class _EmpTabBar extends StatelessWidget {
  const _EmpTabBar({required this.vm});

  final EmployeeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final a = vm.tabResolved;
    Widget t(String id, IconData i, String l) {
      final on = a == id;
      return Expanded(
        child: InkWell(
          onTap: () => vm.setScreen(id),
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
                  child: Icon(i, size: 18, color: on ? Colors.black : AppColors.textMuted),
                ),
                Text(l, style: TextStyle(fontSize: 8, color: on ? AppColors.primary : AppColors.textHint)),
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
            t('employee-jobs', Icons.work_outline, 'My Jobs'),
            t('employee-profile', Icons.person_outline, 'Profile'),
          ],
        ),
      ),
    );
  }
}

/// Same API and list layout as mechanic **My Jobs** (`GET /api/v1/jobs?tab=active`).
class _EmployeeJobsList extends StatefulWidget {
  const _EmployeeJobsList();

  @override
  State<_EmployeeJobsList> createState() => _EmployeeJobsListState();
}

class _EmployeeJobsListState extends State<_EmployeeJobsList> {
  static const _kBlue = Color(0xFF60A5FA);
  static const _kYellow = Color(0xFFFACC15);
  static const _kAmber = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MechanicViewModel>().loadMyJobs();
    });
  }

  ({String label, Color dot, Color fg, Color bg, Color border, bool pulse}) _statusCfg(String tone, String label) {
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
    final mech = context.watch<MechanicViewModel>();
    final emp = context.read<EmployeeViewModel>();

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
                mech.myJobsLoading
                    ? 'Loading…'
                    : '${mech.myJobsTotalActive} accepted job${mech.myJobsTotalActive == 1 ? '' : 's'}',
                style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.85), fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(builder: (context) {
            if (mech.myJobsLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (mech.myJobsError != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.textMuted, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        mech.myJobsError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: mech.loadMyJobs,
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
            if (mech.myActiveJobs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.work_outline, color: AppColors.textMuted, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'No active jobs',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              itemCount: mech.myActiveJobs.length,
              itemBuilder: (context, i) {
                final job = mech.myActiveJobs[i];
                final cfg = _statusCfg(job.statusTone, job.statusLabel);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () {
                        final id = job.backendId.trim();
                        if (id.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Missing job id — cannot open tracker.')),
                          );
                          return;
                        }
                        mech.selectJobForTracker(id);
                        emp.setScreen('employee-tracker');
                      },
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
                                        _EmployeeStatusDot(color: cfg.dot, pulse: cfg.pulse),
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

class _EmployeeStatusDot extends StatefulWidget {
  const _EmployeeStatusDot({required this.color, required this.pulse});

  final Color color;
  final bool pulse;

  @override
  State<_EmployeeStatusDot> createState() => _EmployeeStatusDotState();
}

class _EmployeeStatusDotState extends State<_EmployeeStatusDot> with SingleTickerProviderStateMixin {
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
