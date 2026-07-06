import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../routes/app_routes.dart';
import '../features/auth/viewmodel/auth_viewmodel.dart';

/// Profile → **Delete Account** (Apple Guideline 5.1.1(v)).
///
/// Calls `DELETE /api/v1/users/me`, clears the local session, and routes to login.
class ProfileDeleteAccountButton extends StatefulWidget {
  const ProfileDeleteAccountButton({
    super.key,
    this.padding = EdgeInsets.zero,
    this.compact = false,
  });

  final EdgeInsetsGeometry padding;
  final bool compact;

  @override
  State<ProfileDeleteAccountButton> createState() => _ProfileDeleteAccountButtonState();
}

class _ProfileDeleteAccountButtonState extends State<ProfileDeleteAccountButton> {
  bool _busy = false;

  Future<void> _onTap() async {
    if (_busy) return;

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete account?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: const Text(
          'This permanently deletes your TruckFix account and personal profile data. '
          'You will be signed out immediately and will not be able to sign in again with this account.\n\n'
          'Completed job and payment records may be retained as required by law (up to 7 years).',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm deletion',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: const Text(
          'Tap Delete my account below to permanently remove your account. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete my account', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<AuthViewModel>().deleteAccount();
      if (!mounted) return;
      context.go(AppRoutes.login);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.compact
        ? TextButton.icon(
            onPressed: _busy ? null : _onTap,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.red),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red),
            label: const Text(
              'Delete Account',
              style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          )
        : SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: BorderSide(color: AppColors.red.withValues(alpha: 0.25)),
                backgroundColor: AppColors.red.withValues(alpha: 0.04),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.red),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red),
              label: const Text(
                'Delete Account',
                style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          );

    return Padding(padding: widget.padding, child: child);
  }
}
