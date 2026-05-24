import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/fleet_api_service.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../models/notification_navigation.dart';
import '../viewmodel/fleet_viewmodel.dart';

/// Fleet notifications (`NotificationsScreen` / fleet reference UI).
class FleetNotificationsOverlay extends StatefulWidget {
  const FleetNotificationsOverlay({super.key});

  @override
  State<FleetNotificationsOverlay> createState() => _FleetNotificationsOverlayState();
}

class _NotifRowModel {
  _NotifRowModel({
    required this.id,
    required this.type,
    required this.headline,
    required this.detail,
    required this.when,
    required this.unread,
    required this.leading,
  });

  final String id;
  final String type;
  final String headline;
  final String detail;
  final String when;
  bool unread;
  final Widget leading;
}

class _FleetNotificationsOverlayState extends State<FleetNotificationsOverlay> {
  /// Main screen background (very dark brown-black).
  static const Color _bg = Color(0xFF0A0A05);
  /// Unread row highlight.
  static const Color _unreadRowBg = Color(0xFF14140D);
  static const Color _divider = Color(0xFF252520);
  static const Color _bodyMuted = Color(0xFFA8A29E);
  static const Color _quotePurple = Color(0xFF6366F1);
  static const Color _supportBlue = Color(0xFF3B82F6);

  final _api = FleetApiService();
  List<_NotifRowModel> _rows = const [];
  bool _loading = true;
  String? _error;
  int _unreadCountFromApi = 0;
  String? _openingNotificationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  int get _unreadCount => _unreadCountFromApi > 0 ? _unreadCountFromApi : _rows.where((r) => r.unread).length;

  static String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hr ago';
      return '${diff.inDays} day ago';
    } catch (_) {
      return '';
    }
  }

  static ({Color bg, IconData icon}) _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'QUOTE_RECEIVED':
        return (bg: _quotePurple, icon: Icons.request_quote_rounded);
      case 'JOB_UPDATE':
        return (bg: AppColors.red, icon: Icons.directions_car_rounded);
      case 'SUPPORT_TICKET_CREATED':
        return (bg: _supportBlue, icon: Icons.support_agent_rounded);
      case 'CHAT_MESSAGE':
        return (bg: const Color(0xFF374151), icon: Icons.chat_bubble_outline_rounded);
      default:
        return (bg: const Color(0xFF374151), icon: Icons.notifications_rounded);
    }
  }

  static String? _notificationId(Map<String, dynamic> m) {
    final id = m['id'] ?? m['_id'];
    if (id == null) return null;
    final s = id.toString().trim();
    return s.isEmpty ? null : s;
  }

  Future<void> _onNotificationTap(_NotifRowModel row) async {
    if (_openingNotificationId != null) return;

    final token = context.read<AuthViewModel>().session?.accessToken?.trim();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again.')),
      );
      return;
    }

    setState(() => _openingNotificationId = row.id);

    try {
      final res = await _api.fetchNotificationById(accessToken: token, notificationId: row.id);
      if (!mounted) return;

      final raw = res['data'];
      if (raw is! Map) {
        throw FleetApiException('Invalid notification response.');
      }
      final data = Map<String, dynamic>.from(raw);

      final chatSession = fleetChatSessionFromNotificationData(data);
      if (chatSession == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This notification cannot be opened here.')),
        );
        return;
      }

      if (row.unread) {
        setState(() {
          row.unread = false;
          _unreadCountFromApi = (_unreadCountFromApi - 1).clamp(0, 999999);
        });
      }

      final vm = context.read<FleetViewModel>();
      vm.closeNotifications();
      vm.openJobChat(chatSession);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _openingNotificationId = null);
    }
  }

  Future<void> _load() async {
    final token = context.read<AuthViewModel>().session?.accessToken;
    if (token == null || token.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing access token';
        _rows = const [];
        _unreadCountFromApi = 0;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.fetchNotifications(accessToken: token, page: 1, limit: 20);
      final meta = (res['meta'] is Map<String, dynamic>) ? res['meta'] as Map<String, dynamic> : <String, dynamic>{};
      final unreadCount = (meta['unreadCount'] is num) ? (meta['unreadCount'] as num).toInt() : 0;

      final data = res['data'];
      final rows = <_NotifRowModel>[];
      if (data is List) {
        for (final item in data) {
          if (item is! Map) continue;
          final m = item.cast<String, dynamic>();
          final id = _notificationId(m);
          if (id == null) continue;

          final type = (m['type'] as String?) ?? '';
          final title = (m['title'] as String?) ?? '';
          final body = (m['body'] as String?) ?? '';
          final createdAt = (m['createdAt'] as String?) ?? '';
          final isRead = (m['isRead'] is bool) ? m['isRead'] as bool : false;

          final cfg = _iconForType(type);
          rows.add(
            _NotifRowModel(
              id: id,
              type: type,
              headline: title.isEmpty ? type : title,
              detail: body,
              when: createdAt.isEmpty ? '' : _timeAgo(createdAt),
              unread: !isRead,
              leading: _leadingSolid(cfg.bg, cfg.icon),
            ),
          );
        }
      }

      setState(() {
        _rows = rows;
        _unreadCountFromApi = unreadCount;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  static Widget _leadingSolid(Color bg, IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  void _markAllRead() {
    setState(() {
      for (final r in _rows) {
        r.unread = false;
      }
      _unreadCountFromApi = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FleetViewModel>();

    return Positioned.fill(
      child: Material(
        color: _bg,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Material(
                      color: const Color(0xFF1A1A1A),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: vm.closeNotifications,
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notifications',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _unreadCount == 0 ? 'All caught up' : '$_unreadCount unread',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: TextButton(
                        onPressed: _unreadCount == 0 ? null : _markAllRead,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'MARK ALL READ',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : (_error != null)
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 28),
                                  const SizedBox(height: 10),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: _bodyMuted, fontSize: 13, height: 1.35),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _load,
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : (_rows.isEmpty)
                            ? const Center(
                                child: Text(
                                  'All caught up',
                                  style: TextStyle(color: _bodyMuted, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 24),
                                itemCount: _rows.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: _divider),
                                itemBuilder: (context, i) {
                                  final r = _rows[i];
                                  final opening = _openingNotificationId == r.id;
                                  return Material(
                                    color: r.unread ? _unreadRowBg : _bg,
                                    child: InkWell(
                                      onTap: _openingNotificationId != null && !opening
                                          ? null
                                          : () => _onNotificationTap(r),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            r.leading,
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    r.headline,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    r.detail,
                                                    style: const TextStyle(
                                                      color: _bodyMuted,
                                                      fontSize: 13,
                                                      height: 1.4,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                  ),
                                                  if (r.when.trim().isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      r.when,
                                                      style: TextStyle(
                                                        color: AppColors.textMuted.withValues(alpha: 0.95),
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (opening)
                                              const Padding(
                                                padding: EdgeInsets.only(top: 2),
                                                child: SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              )
                                            else if (r.unread)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 6),
                                                child: Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: AppColors.primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              )
                                            else
                                              const SizedBox(width: 8),
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
        ),
      ),
    );
  }
}
