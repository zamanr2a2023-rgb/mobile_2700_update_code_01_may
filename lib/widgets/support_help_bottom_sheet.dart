import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../data/models/session.dart';
import '../data/services/support_api_service.dart';
import '../features/auth/viewmodel/auth_viewmodel.dart';

/// Same Help & Support flow as fleet (`_FleetHelpOverlay`): categories, message, `POST /support/tickets`.
Future<void> showSupportHelpBottomSheet(
  BuildContext context, {
  required String roleSuffix,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SupportHelpSheet(roleSuffix: roleSuffix),
  );
}

class _SupportHelpSheet extends StatefulWidget {
  const _SupportHelpSheet({required this.roleSuffix});

  final String roleSuffix;

  @override
  State<_SupportHelpSheet> createState() => _SupportHelpSheetState();
}

class _SupportHelpSheetState extends State<_SupportHelpSheet> {
  String? _category;
  final _message = TextEditingController();
  bool _sent = false;
  bool _submitting = false;

  final _supportApi = SupportApiService();

  /// Same order and labels as fleet `[_FleetHelpOverlay]`.
  static const _categories = <(String id, String label, IconData icon)>[
    ('job', 'Job / Booking', Icons.bolt_rounded),
    ('payment', 'Payment / Invoice', Icons.credit_card_rounded),
    ('account', 'Account & Profile', Icons.person_rounded),
    ('mechanic', 'Mechanic Issue', Icons.build_rounded),
    ('other', 'Other', Icons.help_outline_rounded),
  ];

  String _senderLine(Session? session) {
    final e = session?.email.trim();
    final email = e == null || e.isEmpty ? 'your registered email' : e;
    return 'Sent from: $email · ${widget.roleSuffix}';
  }

  String _subjectForCategory(String id) {
    for (final c in _categories) {
      if (c.$1 == id) return c.$2;
    }
    return id;
  }

  Future<void> _submit() async {
    if (_category == null || _message.text.trim().isEmpty || _submitting) return;
    final token = context.read<AuthViewModel>().session?.accessToken;
    final messenger = ScaffoldMessenger.of(context);
    if (token == null || token.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Please sign in again to send support messages.')));
      return;
    }
    final subjectLabel = _subjectForCategory(_category!);
    setState(() => _submitting = true);
    try {
      await _supportApi.createTicket(
        accessToken: token,
        subject: subjectLabel,
        message: _message.text.trim(),
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
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(const SnackBar(content: Text('Could not send message. Please try again.')));
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authSession = context.watch<AuthViewModel>().session;
    final bottom = MediaQuery.paddingOf(context).bottom;

    if (_sent) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E0E0E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border2)),
        ),
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(99)),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.30)),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Message Sent!',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Our support team will respond within 24 hours via your registered email address.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      );
    }

    final canSend = _category != null && _message.text.trim().isNotEmpty;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E0E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Help & Support', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                      SizedBox(height: 2),
                      Text('We usually reply within 24 hours', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A)),
                  icon: Icon(Icons.close_rounded, color: AppColors.textMuted.withValues(alpha: 0.9), size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "WHAT'S THIS ABOUT?",
                    style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _catTile(0)),
                      const SizedBox(width: 8),
                      Expanded(child: _catTile(1)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _catTile(2)),
                      const SizedBox(width: 8),
                      Expanded(child: _catTile(3)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _catTile(4, fullWidth: true),
                  const SizedBox(height: 20),
                  Text(
                    'YOUR MESSAGE',
                    style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _message,
                    onChanged: (_) => setState(() {}),
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
                    decoration: InputDecoration(
                      hintText: 'Describe your issue or question in as much detail as possible...',
                      hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.85)),
                      filled: true,
                      fillColor: AppColors.card2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border2)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border2)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.40)),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _senderLine(authSession),
                    style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.75), fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (canSend && !_submitting) ? _submit : null,
                    icon: _submitting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black.withValues(alpha: 0.7)),
                          )
                        : Icon(Icons.send_rounded, size: 18, color: (canSend && !_submitting) ? Colors.black : Colors.black.withValues(alpha: 0.35)),
                    label: Text(
                      'SEND MESSAGE',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.8,
                        color: (canSend && !_submitting) ? Colors.black : Colors.black.withValues(alpha: 0.35),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.30),
                      disabledForegroundColor: Colors.black.withValues(alpha: 0.35),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _catTile(int index, {bool fullWidth = false}) {
    final c = _categories[index];
    final sel = _category == c.$1;
    final child = Material(
      color: sel ? AppColors.primary.withValues(alpha: 0.08) : AppColors.card2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _category = c.$1),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? AppColors.primary.withValues(alpha: 0.50) : const Color(0xFF1E1E1E)),
          ),
          child: Row(
            children: [
              Icon(c.$3, size: 18, color: sel ? AppColors.primary : AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.$2,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: sel ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (fullWidth) return child;
    return child;
  }
}
