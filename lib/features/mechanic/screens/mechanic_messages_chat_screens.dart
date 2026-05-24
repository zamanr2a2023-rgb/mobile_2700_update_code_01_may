import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../models/mechanic_profile_extras.dart';
import '../viewmodel/mechanic_viewmodel.dart';

// ─── Messages list ─────────────────────────────────────────────────────────

class MechanicMessagesListPage extends StatelessWidget {
  const MechanicMessagesListPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MechanicViewModel>();
    final threads = vm.messageThreads;

    return ColoredBox(
      color: AppColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SubScreenHeader(title: 'Messages', onBack: onBack),
          Expanded(
            child: vm.messageThreadsLoading
                ? const Center(child: CircularProgressIndicator())
                : vm.messageThreadsError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                vm.messageThreadsError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => vm.loadMessageThreads(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : threads.isEmpty
                        ? const Center(
                            child: Text('No conversations yet', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                          )
                        : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: threads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final t = threads[i];
                      return Material(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => vm.openMessageChat(t),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: (t.photoUrl != null && t.photoUrl!.isNotEmpty)
                                        ? CachedNetworkImage(
                                            imageUrl: t.photoUrl!,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => _avatarFallback(),
                                          )
                                        : _avatarFallback(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              t.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                          Text(
                                            t.timeLabel,
                                            style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.9), fontSize: 10, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        t.subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: AppColors.textHint.withValues(alpha: 0.8)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static Widget _avatarFallback() {
    return Container(
      color: AppColors.card2,
      alignment: Alignment.center,
      child: const Icon(Icons.local_shipping_rounded, color: AppColors.textMuted, size: 24),
    );
  }
}

// ─── Peer chat (mechanic = yellow outgoing) ────────────────────────────────

class _MechChatBubble {
  const _MechChatBubble({
    required this.id,
    required this.fromMechanic,
    required this.time,
    this.text = '',
    this.imageUrl,
    this.imageFilePath,
  });

  final int id;
  final bool fromMechanic;
  final String text;
  final String time;
  final String? imageUrl;
  final String? imageFilePath;
}

class MechanicPeerChatScreen extends StatefulWidget {
  const MechanicPeerChatScreen({super.key, required this.thread, required this.onBack});

  final MechanicMessageThread thread;
  final VoidCallback onBack;

  @override
  State<MechanicPeerChatScreen> createState() => _MechanicPeerChatScreenState();
}

class _MechanicPeerChatScreenState extends State<MechanicPeerChatScreen> {
  static const Color _bg = Color(0xFF080808);
  static const Color _incomingBubble = Color(0xFF1A1A1A);
  static const Color _barBg = Color(0xFF0F0F0F);
  static const Color _inputBg = Color(0xFF1A1A1A);
  static const Color _headerBtn = Color(0xFF1A1A1A);

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final ImagePicker _picker = ImagePicker();
  late List<_MechChatBubble> _messages;
  bool _showAttachMenu = false;
  int _nextId = 10;

  @override
  void initState() {
    super.initState();
    final t = widget.thread;
    _messages = [
      _MechChatBubble(
        id: 1,
        fromMechanic: false,
        text: 'Hi — are you still able to attend today?',
        time: '09:12',
      ),
      _MechChatBubble(
        id: 2,
        fromMechanic: true,
        text: 'Yes, on my way. ETA about 25 minutes.',
        time: '09:14',
      ),
      _MechChatBubble(
        id: 3,
        fromMechanic: false,
        text: t.preview,
        time: t.timeLabel,
      ),
    ];
    _nextId = 4;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  String _nowTime() {
    final t = TimeOfDay.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _sendText() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _showAttachMenu = false;
      _messages = [..._messages, _MechChatBubble(id: _nextId++, fromMechanic: true, text: t, time: _nowTime())];
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _showAttachMenu = false);
    final x = await _picker.pickImage(source: source, imageQuality: 82);
    if (!mounted || x == null) return;
    setState(() {
      _messages = [..._messages, _MechChatBubble(id: _nextId++, fromMechanic: true, text: '', time: _nowTime(), imageFilePath: x.path)];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  Future<void> _dial(String? raw) async {
    if (raw == null || raw.trim().isEmpty) return;
    final uri = Uri.parse('tel:${raw.replaceAll(RegExp(r'\s+'), '')}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String get _peerAvatar {
    final u = widget.thread.photoUrl?.trim();
    return (u != null && u.isNotEmpty) ? u! : AppAssets.truckWorkshop;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final t = widget.thread;

    return Material(
      color: _bg,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A)))),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    style: IconButton.styleFrom(
                      backgroundColor: _headerBtn,
                      minimumSize: const Size(36, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textMuted.withValues(alpha: 0.95)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: _peerAvatar,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 36,
                              height: 36,
                              color: _inputBg,
                              child: const Icon(Icons.person_rounded, color: AppColors.textMuted, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                t.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _dial(t.phone),
                    style: IconButton.styleFrom(
                      backgroundColor: _headerBtn,
                      minimumSize: const Size(36, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.phone_rounded, size: 18, color: AppColors.primary.withValues(alpha: t.phone != null ? 1 : 0.35)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final outgoing = m.fromMechanic;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: outgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                        child: Column(
                          crossAxisAlignment: outgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: outgoing ? AppColors.primary : _incomingBubble,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (m.imageUrl != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: CachedNetworkImage(
                                          imageUrl: m.imageUrl!,
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else if (m.imageFilePath != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.file(File(m.imageFilePath!), height: 180, width: double.infinity, fit: BoxFit.cover),
                                      ),
                                    if (m.text.isNotEmpty) ...[
                                      if (m.imageUrl != null || m.imageFilePath != null) const SizedBox(height: 8),
                                      Text(
                                        m.text,
                                        style: TextStyle(
                                          color: outgoing ? Colors.black : Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(m.time, style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.85), fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset),
            decoration: const BoxDecoration(color: _barBg, border: Border(top: BorderSide(color: Color(0xFF1A1A1A)))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => setState(() => _showAttachMenu = !_showAttachMenu),
                  icon: Icon(Icons.add_circle_outline, color: AppColors.primary.withValues(alpha: 0.95)),
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.75)),
                      filled: true,
                      fillColor: _inputBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5))),
                    ),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendText,
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                  icon: const Icon(Icons.send_rounded, size: 20),
                ),
              ],
            ),
          ),
          if (_showAttachMenu)
            Container(
              width: double.infinity,
              color: const Color(0xFF121212),
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined, color: AppColors.primary, size: 20),
                    label: const Text('Camera', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, color: AppColors.primary, size: 20),
                    label: const Text('Gallery', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubScreenHeader extends StatelessWidget {
  const _SubScreenHeader({required this.title, required this.onBack, this.trailing});

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
      decoration: const BoxDecoration(color: AppColors.bg, border: Border(bottom: BorderSide(color: AppColors.border))),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textSecondary),
            ),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
