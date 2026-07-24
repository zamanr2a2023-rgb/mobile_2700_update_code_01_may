import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/company_invite.dart';
import '../../../data/models/session.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../routes/app_routes.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../viewmodel/company_invites_viewmodel.dart';

/// Pending company invitations for an independent mechanic.
class CompanyInvitesScreen extends StatelessWidget {
  const CompanyInvitesScreen({
    super.key,
    this.highlightInviteId,
    this.onBack,
  });

  final String? highlightInviteId;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CompanyInvitesViewModel(
        auth: ctx.read<AuthRepository>(),
        authViewModel: ctx.read<AuthViewModel>(),
      )..load(),
      child: _CompanyInvitesBody(
        highlightInviteId: highlightInviteId,
        onBack: onBack,
      ),
    );
  }
}

class _CompanyInvitesBody extends StatelessWidget {
  const _CompanyInvitesBody({this.highlightInviteId, this.onBack});

  final String? highlightInviteId;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyInvitesViewModel>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: onBack ?? () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.mechanicHome);
            }
          },
        ),
        title: const Text(
          'Company invitations',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => vm.load(),
        child: _buildBody(context, vm),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CompanyInvitesViewModel vm) {
    if (vm.loading && vm.invites.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      );
    }

    if (vm.error != null && vm.invites.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Text(
            vm.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: () => vm.load(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (vm.invites.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.mail_outline_rounded, size: 48, color: AppColors.textHint.withValues(alpha: 0.8)),
          const SizedBox(height: 16),
          const Text(
            'No company invitations',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'When a workshop invites your account, it will appear here so you can accept or decline.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 12, height: 1.4),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: vm.invites.length + (vm.actionError != null ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (vm.actionError != null && index == 0) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.red.withValues(alpha: 0.25)),
            ),
            child: Text(
              vm.actionError!,
              style: const TextStyle(color: AppColors.red, fontSize: 12),
            ),
          );
        }
        final inviteIndex = vm.actionError != null ? index - 1 : index;
        final invite = vm.invites[inviteIndex];
        final highlight = highlightInviteId != null && highlightInviteId == invite.id;
        return _InviteCard(
          invite: invite,
          highlighted: highlight,
          busy: vm.actionInviteId == invite.id,
          onAccept: () => _onAccept(context, vm, invite),
          onDecline: () => _onDecline(context, vm, invite),
        );
      },
    );
  }

  Future<void> _onAccept(BuildContext context, CompanyInvitesViewModel vm, CompanyInvite invite) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Accept invitation?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Join ${(invite.companyName ?? 'this company').trim()} as a company mechanic? '
          'Your account will switch to an employee role.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final success = await vm.accept(invite.id);
    if (!context.mounted) return;
    if (success) {
      final role = context.read<AuthViewModel>().session?.role;
      if (role == UserRole.employee) {
        context.go(AppRoutes.employeeHome);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation accepted.')),
        );
      }
    }
  }

  Future<void> _onDecline(BuildContext context, CompanyInvitesViewModel vm, CompanyInvite invite) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Decline invitation?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Decline the invitation from ${(invite.companyName ?? 'this company').trim()}?',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final success = await vm.decline(invite.id);
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation declined.')),
      );
    }
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invite,
    required this.highlighted,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final CompanyInvite invite;
  final bool highlighted;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final company = (invite.companyName ?? 'Company').trim();
    final canAct = invite.isPending && !invite.isExpired && !busy;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted ? AppColors.primary.withValues(alpha: 0.55) : AppColors.border,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  company,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: invite.isExpired
                      ? AppColors.textMuted.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  invite.statusLabel.toUpperCase(),
                  style: TextStyle(
                    color: invite.isExpired ? AppColors.textMuted : AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          if (invite.email.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(invite.email, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
          if (invite.expiresAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Expires ${_formatDate(invite.expiresAt!)}',
              style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.95), fontSize: 10),
            ),
          ],
          if (canAct || busy) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: BorderSide(color: AppColors.red.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final local = d.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year}';
  }
}
