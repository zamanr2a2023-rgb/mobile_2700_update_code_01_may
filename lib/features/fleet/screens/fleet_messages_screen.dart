import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../viewmodel/fleet_viewmodel.dart';

/// Fleet Profile → Messages (`GET /api/v1/chat/threads`), same inbox pattern as mechanic.
class FleetMessagesListPage extends StatelessWidget {
  const FleetMessagesListPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FleetViewModel>();
    final threads = vm.fleetInboxThreads;

    return ColoredBox(
      color: const Color(0xFF080808),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FleetMessagesHeader(onBack: onBack),
          Expanded(
            child: vm.fleetInboxLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : vm.fleetInboxError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                vm.fleetInboxError!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => vm.loadFleetInboxThreads(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : threads.isEmpty
                        ? Center(
                            child: Text(
                              'No conversations yet',
                              style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 14),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: threads.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final t = threads[i];
                              return Material(
                                color: const Color(0xFF121212),
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  onTap: () => vm.openFleetInboxChat(t),
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
                                            child: (t.counterpartyPhotoUrl != null &&
                                                    t.counterpartyPhotoUrl!.trim().isNotEmpty)
                                                ? CachedNetworkImage(
                                                    imageUrl: t.counterpartyPhotoUrl!,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, __, ___) => fleetInboxAvatarFallback(),
                                                  )
                                                : fleetInboxAvatarFallback(),
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
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    vm.threadTimeLabel(t),
                                                    style: TextStyle(
                                                      color: AppColors.textHint.withValues(alpha: 0.9),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                t.preview.isNotEmpty ? t.preview : t.subtitle,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: AppColors.textMuted.withValues(alpha: 0.95),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
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
}

Widget fleetInboxAvatarFallback() {
  return ColoredBox(
    color: const Color(0xFF1A1A1A),
    child: Center(
      child: Image.asset(AppAssets.mechanicPortrait, width: 40, height: 40, fit: BoxFit.cover),
    ),
  );
}

class _FleetMessagesHeader extends StatelessWidget {
  const _FleetMessagesHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F0F0F),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: Icon(Icons.chevron_left, color: AppColors.textMuted.withValues(alpha: 0.95), size: 28),
              ),
              const Expanded(
                child: Text(
                  'Messages',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}
