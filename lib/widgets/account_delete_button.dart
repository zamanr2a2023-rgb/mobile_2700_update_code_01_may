import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../routes/app_routes.dart';
import '../features/auth/viewmodel/auth_viewmodel.dart';

/// Profile → **Delete Account** (Apple Guideline 5.1.1(v)).
///
/// Calls `DELETE /api/v1/users/me` with `{ "password": "..." }`, clears the local
/// session, and routes to login. Used on Profile for Fleet, Mechanic, Company, Employee.
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

  Future<String?> _askPassword() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _AccountDeletePasswordDialog(),
    );
  }

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

    final password = await _askPassword();
    if (password == null || password.isEmpty || !mounted) return;

    final auth = context.read<AuthViewModel>();
    final router = GoRouter.of(context);

    setState(() => _busy = true);
    var navigatedAway = false;
    try {
      await auth.deleteAccount(password: password);
      navigatedAway = true;
      router.go(AppRoutes.login);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted && !navigatedAway) setState(() => _busy = false);
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

class _AccountDeletePasswordDialog extends StatefulWidget {
  const _AccountDeletePasswordDialog();

  @override
  State<_AccountDeletePasswordDialog> createState() => _AccountDeletePasswordDialogState();
}

class _AccountDeletePasswordDialogState extends State<_AccountDeletePasswordDialog> {
  final _controller = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Confirm deletion',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter your account password to permanently delete your account. This cannot be undone.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF111111),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.red),
              ),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete my account', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
