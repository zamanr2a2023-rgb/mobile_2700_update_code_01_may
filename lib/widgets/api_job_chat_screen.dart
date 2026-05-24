import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_assets.dart';
import '../core/theme/app_colors.dart';
import '../data/models/job_chat_models.dart';
import '../data/services/chat_api_service.dart';

/// Job chat backed by REST (`/api/v1/chat/jobs/:jobId/messages`).
class ApiJobChatScreen extends StatefulWidget {
  const ApiJobChatScreen({
    super.key,
    this.chatApi,
    required this.accessToken,
    required this.jobId,
    required this.headerTitle,
    required this.headerSubtitle,
    this.headerAvatarUrl,
    this.peerPhone,
    required this.onClose,
    this.avatarFallbackAsset = AppAssets.truckWorkshop,
  });

  final ChatApiService? chatApi;
  final String accessToken;
  final String jobId;
  final String headerTitle;
  final String headerSubtitle;
  final String? headerAvatarUrl;
  final String? peerPhone;
  final VoidCallback onClose;
  final String avatarFallbackAsset;

  @override
  State<ApiJobChatScreen> createState() => _ApiJobChatScreenState();
}

class _ApiJobChatScreenState extends State<ApiJobChatScreen> {
  static const Color _bg = Color(0xFF080808);
  static const Color _incomingBubble = Color(0xFF1A1A1A);
  static const Color _barBg = Color(0xFF0F0F0F);
  static const Color _inputBg = Color(0xFF1A1A1A);
  static const Color _headerBtn = Color(0xFF1A1A1A);

  late final ChatApiService _api = widget.chatApi ?? ChatApiService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<JobChatMessage> _items = [];
  bool _loading = true;
  String? _error;
  bool _sendBusy = false;
  bool _uploadBusy = false;
  bool _showAttachMenu = false;

  String _displayTitle = '';
  String _displaySubtitle = '';
  String _avatarResolved = '';

  @override
  void initState() {
    super.initState();
    _displayTitle = widget.headerTitle;
    _displaySubtitle = widget.headerSubtitle;
    final h = widget.headerAvatarUrl?.trim();
    _avatarResolved = (h != null && h.isNotEmpty) ? h : widget.avatarFallbackAsset;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _reload(silentBanner: false);
    if (!mounted) return;
    if (_error == null && _items.isNotEmpty) {
      try {
        await _api.markJobMessagesRead(accessToken: widget.accessToken, jobId: widget.jobId);
      } catch (_) {}
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  Future<void> _reload({required bool silentBanner}) async {
    setState(() {
      _loading = true;
      if (!silentBanner) _error = null;
    });
    try {
      final env = await _api.fetchJobMessages(
        accessToken: widget.accessToken,
        jobId: widget.jobId,
        limit: 50,
      );
      final page = JobChatMessagesPage.tryParse(env);
      if (!mounted) return;
      setState(() {
        if (page != null) {
          _items = page.items;
          if (page.peerTitle.trim().isNotEmpty) _displayTitle = page.peerTitle;
          if (page.peerSubtitle.trim().isNotEmpty) _displaySubtitle = page.peerSubtitle;
          if (page.peerPhotoUrl != null && page.peerPhotoUrl!.trim().isNotEmpty) {
            _avatarResolved = page.peerPhotoUrl!.trim();
          }
        } else {
          _items = [];
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _sendText() async {
    final t = _input.text.trim();
    if (t.isEmpty || _sendBusy) return;
    setState(() {
      _showAttachMenu = false;
      _sendBusy = true;
    });
    try {
      final env = await _api.sendJobMessage(accessToken: widget.accessToken, jobId: widget.jobId, text: t);
      _input.clear();
      final raw = env['data'];
      if (!mounted) return;
      if (raw is Map<String, dynamic>) {
        try {
          final m = JobChatMessage.fromJson(raw);
          setState(() {
            _items = [..._items, m];
            _sendBusy = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
          return;
        } catch (_) {}
      }
      await _reload(silentBanner: true);
      if (!mounted) return;
      setState(() => _sendBusy = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _pickAndSend(ImageSource source) async {
    setState(() => _showAttachMenu = false);
    final file = await _picker.pickImage(source: source, imageQuality: 82);
    if (!mounted || file == null) return;
    setState(() => _uploadBusy = true);
    try {
      final up = await _api.uploadJobChatAttachment(
        accessToken: widget.accessToken,
        jobId: widget.jobId,
        filePath: file.path,
      );
      final url = ChatApiService.parseAttachmentUrlFromUpload(up);
      if (url == null || url.isEmpty) throw ChatApiException('Upload returned no URL');
      final env = await _api.sendJobMessage(
        accessToken: widget.accessToken,
        jobId: widget.jobId,
        text: '',
        attachments: [url],
      );
      final raw = env['data'];
      if (!mounted) return;
      if (raw is Map<String, dynamic>) {
        final m = JobChatMessage.fromJson(raw);
        setState(() {
          _items = [..._items, m];
          _uploadBusy = false;
        });
      } else {
        await _reload(silentBanner: true);
        if (!mounted) return;
        setState(() => _uploadBusy = false);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _dial(String? raw) async {
    if (raw == null || raw.trim().isEmpty) return;
    final uri = Uri.parse('tel:${raw.replaceAll(RegExp(r'\s+'), '')}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Keep a little safe-area clearance without stacking large padding above the fleet bottom nav.
    final composerBottomPad = 6.0 + (bottomInset > 16 ? 12.0 : bottomInset.toDouble());

    Widget body = const SizedBox.shrink();
    if (_loading && _items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _items.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _reload(silentBanner: false),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else {
      body = ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final m = _items[i];
          final outgoing = m.isOwn;
          final hasAttach = m.attachments.isNotEmpty;
          final outgoingAttachStyle = outgoing && hasAttach;
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
                          color: outgoingAttachStyle
                              ? const Color(0xFF121212)
                              : (outgoing ? AppColors.primary : _incomingBubble),
                          borderRadius: BorderRadius.circular(16),
                          border: outgoingAttachStyle
                              ? Border.all(color: AppColors.primary, width: 1)
                              : null,
                        ),
                        child: Padding(
                          padding: outgoingAttachStyle
                              ? const EdgeInsets.all(3)
                              : const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final u in m.attachments)
                                Padding(
                                  padding: EdgeInsets.only(bottom: m.text.isNotEmpty ? 8 : 0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: u,
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        height: 120,
                                        color: _incomingBubble,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
                                      ),
                                    ),
                                  ),
                                ),
                              if (m.text.isNotEmpty)
                                Text(
                                  m.text,
                                  style: TextStyle(
                                    color: outgoingAttachStyle ? Colors.white : (outgoing ? Colors.black : Colors.white),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(m.timeLabel, style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.85), fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

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
                    onPressed: widget.onClose,
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
                            imageUrl: _avatarResolved,
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
                                _displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                _displaySubtitle,
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
                    onPressed: () => _dial(widget.peerPhone),
                    style: IconButton.styleFrom(
                      backgroundColor: _headerBtn,
                      minimumSize: const Size(36, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(
                      Icons.phone_rounded,
                      size: 18,
                      color: AppColors.primary.withValues(alpha: widget.peerPhone != null && widget.peerPhone!.trim().isNotEmpty ? 1 : 0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: body),
          if ((_sendBusy || _uploadBusy) && !_loading)
            const LinearProgressIndicator(minHeight: 2, backgroundColor: _barBg),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, 8, 12, composerBottomPad),
            decoration: const BoxDecoration(color: _barBg, border: Border(top: BorderSide(color: Color(0xFF1A1A1A)))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: (_loading && _items.isEmpty) || _uploadBusy ? null : () => setState(() => _showAttachMenu = !_showAttachMenu),
                  icon: Icon(Icons.add_circle_outline, color: AppColors.primary.withValues(alpha: 0.95)),
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !_uploadBusy,
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
                  onPressed: (_sendBusy || _uploadBusy) ? null : _sendText,
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
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8 + (bottomInset > 16 ? 12 : bottomInset)),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _uploadBusy ? null : () => _pickAndSend(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined, color: AppColors.primary, size: 20),
                    label: const Text('Camera', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: _uploadBusy ? null : () => _pickAndSend(ImageSource.gallery),
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
