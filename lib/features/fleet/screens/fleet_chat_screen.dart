import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../models/fleet_chat_session.dart';

class _ChatBubble {
  const _ChatBubble({
    required this.id,
    required this.fromFleet,
    required this.time,
    this.text = '',
    this.imageUrl,
    this.imageFilePath,
  });

  final int id;
  final bool fromFleet;
  final String text;
  final String time;
  final String? imageUrl;
  final String? imageFilePath;
}

/// Full-screen chat matching `ChatScreen` in `check.tsx` (dark theme, yellow outgoing).
class FleetChatScreen extends StatefulWidget {
  const FleetChatScreen({super.key, required this.session, required this.onClose});

  final FleetChatSession session;
  final VoidCallback onClose;

  @override
  State<FleetChatScreen> createState() => _FleetChatScreenState();
}

class _FleetChatScreenState extends State<FleetChatScreen> {
  static const Color _bg = Color(0xFF080808);
  static const Color _incomingBubble = Color(0xFF1C1C1E);
  static const Color _barBg = Color(0xFF0F0F0F);
  static const Color _inputBg = Color(0xFF1A1A1A);
  static const Color _inputBorder = Color(0xFF2A2A2A);
  static const Color _headerBtn = Color(0xFF1A1A1A);

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final ImagePicker _picker = ImagePicker();

  late List<_ChatBubble> _messages;
  bool _showAttachMenu = false;
  int _nextId = 100;

  @override
  void initState() {
    super.initState();
    _messages = [
      const _ChatBubble(
        id: 1,
        fromFleet: false,
        text: 'On my way now, should be there in 15 min',
        time: '14:23',
      ),
      const _ChatBubble(
        id: 2,
        fromFleet: true,
        text: 'Great, driver will wait by the layby',
        time: '14:24',
      ),
      const _ChatBubble(
        id: 3,
        fromFleet: false,
        text: 'Can you send a photo of the tyre damage?',
        time: '14:25',
      ),
      const _ChatBubble(
        id: 4,
        fromFleet: true,
        text: '',
        time: '14:26',
        imageUrl: 'https://images.unsplash.com/photo-1486262715619-67b85e0b08d3?w=600',
      ),
      const _ChatBubble(
        id: 5,
        fromFleet: false,
        text: "Perfect, I can see it's the inner tyre. Bringing the right size.",
        time: '14:27',
      ),
    ];
    _nextId = 6;
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
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _sendText() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _showAttachMenu = false;
      _messages = [
        ..._messages,
        _ChatBubble(id: _nextId++, fromFleet: true, text: t, time: _nowTime()),
      ];
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _showAttachMenu = false);
    final x = await _picker.pickImage(source: source, imageQuality: 82);
    if (!mounted || x == null) return;
    setState(() {
      _messages = [
        ..._messages,
        _ChatBubble(id: _nextId++, fromFleet: true, text: '', time: _nowTime(), imageFilePath: x.path),
      ];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  Future<void> _dial(String? raw) async {
    if (raw == null || raw.trim().isEmpty) return;
    final uri = Uri.parse('tel:${raw.replaceAll(RegExp(r'\s+'), '')}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String get _avatarUrl {
    final u = widget.session.mechanicPhotoUrl?.trim();
    return (u != null && u.isNotEmpty) ? u : AppAssets.mechanicPortrait;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final s = widget.session;

    return Material(
      color: _bg,
      child: Stack(
        children: [
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: widget.onClose,
                        style: IconButton.styleFrom(
                          backgroundColor: _headerBtn,
                          padding: const EdgeInsets.all(8),
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
                                imageUrl: _avatarUrl,
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
                                    s.mechanicName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    'Online now',
                                    style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.85), fontSize: 10, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _dial(s.mechanicPhone),
                        style: IconButton.styleFrom(
                          backgroundColor: _headerBtn,
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(36, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(Icons.phone_rounded, size: 18, color: AppColors.primary.withValues(alpha: s.mechanicPhone != null ? 1 : 0.35)),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: _barBg,
                  border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s.jobCode} · ${s.truckLine}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final m = _messages[i];
                    final outgoing = m.fromFleet;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: outgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: outgoing ? AppColors.primary : _incomingBubble,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (m.imageUrl != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CachedNetworkImage(
                                          imageUrl: m.imageUrl!,
                                          height: 200,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else if (m.imageFilePath != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          File(m.imageFilePath!),
                                          fit: BoxFit.cover,
                                          height: 200,
                                          width: double.infinity,
                                        ),
                                      ),
                                    if (m.text.isNotEmpty) ...[
                                      if (m.imageUrl != null || m.imageFilePath != null) const SizedBox(height: 8),
                                      Text(
                                        m.text,
                                        style: TextStyle(
                                          color: outgoing ? Colors.black : Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      m.time,
                                      style: TextStyle(
                                        color: outgoing ? Colors.black.withValues(alpha: 0.55) : AppColors.textHint.withValues(alpha: 0.9),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
                decoration: const BoxDecoration(
                  color: _bg,
                  border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _showAttachMenu = !_showAttachMenu),
                      style: IconButton.styleFrom(
                        backgroundColor: _inputBg,
                        padding: const EdgeInsets.all(10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(Icons.photo_camera_outlined, size: 20, color: AppColors.textMuted.withValues(alpha: 0.95)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendText(),
                        decoration: InputDecoration(
                          hintText: 'Type a message…',
                          hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.65), fontSize: 14),
                          filled: true,
                          fillColor: _inputBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: _inputBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: _inputBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.55)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _input,
                      builder: (context, v, _) {
                        final canSend = v.text.trim().isNotEmpty;
                        return Material(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: canSend ? _sendText : null,
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(Icons.send_rounded, size: 20, color: canSend ? Colors.black : Colors.black.withValues(alpha: 0.35)),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_showAttachMenu)
            Positioned(
              left: 12,
              right: 12,
              bottom: 72 + bottomInset,
              child: Material(
                color: _inputBg,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: () => _pickImage(ImageSource.camera),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.photo_camera_rounded, size: 20, color: AppColors.primary),
                            const SizedBox(width: 12),
                            const Text('Take Photo', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: _inputBorder.withValues(alpha: 0.8)),
                    InkWell(
                      onTap: () => _pickImage(ImageSource.gallery),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.photo_library_outlined, size: 20, color: AppColors.primary),
                            const SizedBox(width: 12),
                            const Text('Choose from Gallery', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
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
