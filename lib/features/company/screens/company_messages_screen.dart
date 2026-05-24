import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../viewmodel/company_viewmodel.dart';

class CompanyMessagesListPage extends StatelessWidget {
  const CompanyMessagesListPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyViewModel>();
    final threads = vm.companyMessageThreads;

    return ColoredBox(
      color: AppColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CompanyMessageHeader(title: 'Messages', onBack: onBack),
          Expanded(
            child: vm.companyMessageThreadsLoading
                ? const Center(child: CircularProgressIndicator())
                : vm.companyMessageThreadsError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                vm.companyMessageThreadsError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => vm.loadCompanyMessageThreads(),
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
                          onTap: () => vm.openCompanyMessageChat(t),
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
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            t.timeLabel,
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
      child: const Icon(Icons.domain_rounded, color: AppColors.textMuted, size: 24),
    );
  }
}

class _CompanyMessageHeader extends StatelessWidget {
  const _CompanyMessageHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

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
          ],
        ),
      ),
    );
  }
}
