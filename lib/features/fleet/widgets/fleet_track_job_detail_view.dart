import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/fleet_track_job_detail.dart';
import '../models/fleet_chat_session.dart';
import '../viewmodel/fleet_viewmodel.dart';

String _moneyStr(double amount, String currency) {
  final sym = switch (currency.toUpperCase()) {
    'GBP' => '£',
    'USD' => r'$',
    'EUR' => '€',
    _ => '',
  };
  return '$sym${amount.round()}';
}

({Color dot, Color fg, Color bg, Color border, String shortLabel}) _statusBadge(FleetTrackJobDetailUi d) {
  final t = d.statusTone.toLowerCase();
  final label = d.statusLabel.toUpperCase();
  return switch (t) {
    'red' => (
        dot: AppColors.red,
        fg: AppColors.red,
        bg: AppColors.red.withValues(alpha: 0.10),
        border: AppColors.red.withValues(alpha: 0.30),
        shortLabel: label,
      ),
    'green' => (
        dot: AppColors.green,
        fg: AppColors.green,
        bg: AppColors.green.withValues(alpha: 0.10),
        border: AppColors.green.withValues(alpha: 0.30),
        shortLabel: label,
      ),
    'yellow' => (
        dot: const Color(0xFFFBBF24),
        fg: const Color(0xFFFBBF24),
        bg: const Color(0xFFFBBF24).withValues(alpha: 0.10),
        border: const Color(0xFFFBBF24).withValues(alpha: 0.30),
        shortLabel: label,
      ),
    'amber' => (
        dot: AppColors.orange,
        fg: AppColors.orange,
        bg: AppColors.orange.withValues(alpha: 0.10),
        border: AppColors.orange.withValues(alpha: 0.30),
        shortLabel: label,
      ),
    'blue' => (
        dot: const Color(0xFF60A5FA),
        fg: const Color(0xFF60A5FA),
        bg: const Color(0xFF60A5FA).withValues(alpha: 0.10),
        border: const Color(0xFF60A5FA).withValues(alpha: 0.30),
        shortLabel: label,
      ),
    _ => (
        dot: AppColors.textMuted,
        fg: AppColors.textSecondary,
        bg: AppColors.card2,
        border: AppColors.border2,
        shortLabel: label.isEmpty ? 'STATUS' : label,
      ),
  };
}

bool _cancelHasFee(FleetTrackJobDetailUi d) => d.cancellationCanCancel && !d.cancellationIsFree && d.cancellationFee > 0;

String _cancelFeeStr(FleetTrackJobDetailUi d) => _moneyStr(d.cancellationFee, d.cancellationCurrency);

Future<void> _openMaps(BuildContext context, FleetTrackJobDetailUi d) async {
  final lat = d.mapLat;
  final lng = d.mapLng;
  final Uri uri;
  if (lat != null && lng != null) {
    uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$lat,$lng')}');
  } else {
    uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(d.locationAddress)}');
  }
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
    }
  }
}

Future<void> _dial(BuildContext context, String phoneRaw) async {
  final digits = phoneRaw.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number')));
    }
    return;
  }
  final uri = Uri.parse('tel:$digits');
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start call')));
    }
  }
}

/// Fleet "Track job" detail — data from `GET /api/v1/jobs/:id`.
class FleetTrackJobDetailView extends StatefulWidget {
  const FleetTrackJobDetailView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<FleetTrackJobDetailView> createState() => _FleetTrackJobDetailViewState();
}

class _FleetTrackJobDetailViewState extends State<FleetTrackJobDetailView> with SingleTickerProviderStateMixin {
  bool _cancelOpen = false;
  bool _contactOpen = false;
  bool _ratingOpen = false;
  int _ratingValue = 0;
  final _ratingComment = TextEditingController();
  bool _ratingSubmitted = false;
  late final AnimationController _headerPulse;

  @override
  void initState() {
    super.initState();
    _headerPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _headerPulse.dispose();
    _ratingComment.dispose();
    super.dispose();
  }

  Widget _cancelSheet(FleetTrackJobDetailUi d) {
    final fee = _cancelHasFee(d);
    final feeStr = _cancelFeeStr(d);
    return _DetailBottomOverlay(
      onBarrierTap: () => setState(() => _cancelOpen = false),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cancel this job?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text(
                        fee
                            ? 'A cancellation fee ($feeStr) applies to this job.'
                            : 'You can cancel this job without a fee.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (fee) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.20)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.red.withValues(alpha: 0.9), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cancellation fee · $feeStr · Non-refundable',
                        style: TextStyle(color: AppColors.red.withValues(alpha: 0.95), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => _cancelOpen = false),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                fee ? 'Confirm Cancellation ($feeStr fee)' : 'Confirm Cancellation — Free',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => setState(() => _cancelOpen = false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Keep Job Active', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactSheet(FleetTrackJobDetailUi d) {
    return _DetailBottomOverlay(
      onBarrierTap: () => setState(() => _contactOpen = false),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(imageUrl: AppAssets.mechanicPortrait, width: 40, height: 40, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.mechanicName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(
                        d.mechanicPhone.isEmpty ? '—' : d.mechanicPhone,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _contactOpen = false),
                  icon: Icon(Icons.close_rounded, color: AppColors.textMuted.withValues(alpha: 0.8)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                _dial(context, d.mechanicPhone);
                setState(() => _contactOpen = false);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.call_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Call Mechanic', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                setState(() => _contactOpen = false);
                final phone = d.mechanicPhone.trim();
                context.read<FleetViewModel>().openJobChat(
                      FleetChatSession(
                        mechanicName: d.mechanicName,
                        mechanicPhone: phone.isEmpty ? null : phone,
                        mechanicPhotoUrl: AppAssets.mechanicPortrait,
                        jobCode: d.jobCode,
                        truckLine: d.subtitle,
                      ),
                    );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.textMuted),
                  SizedBox(width: 8),
                  Text('Send Message', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingSheet(FleetTrackJobDetailUi d) {
    return _DetailBottomOverlay(
      onBarrierTap: _ratingSubmitted ? null : () => setState(() => _ratingOpen = false),
      align: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF0E0E0E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: AppColors.border2)),
        ),
        child: SafeArea(
          top: false,
          child: _ratingSubmitted
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppColors.border2, borderRadius: BorderRadius.circular(10)),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.green, width: 2),
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 34),
                    ),
                    const SizedBox(height: 14),
                    const Text('Review Submitted!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      'Thanks for rating ${d.mechanicName}. Your feedback helps keep the network reliable.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border2, borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(imageUrl: AppAssets.mechanicPortrait, width: 48, height: 48, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.mechanicName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text('Job ${d.jobCode} · ${d.title}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('YOUR RATING', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final n = i + 1;
                        final on = n <= _ratingValue;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: InkWell(
                            onTap: () => setState(() => _ratingValue = n),
                            child: Icon(Icons.star_rounded, size: 36, color: on ? AppColors.primary : const Color(0xFF2A2A2A)),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _ratingValue == 0
                          ? ''
                          : switch (_ratingValue) {
                              1 => 'Poor',
                              2 => 'Fair',
                              3 => 'Good',
                              4 => 'Very Good',
                              _ => 'Excellent!',
                            },
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'COMMENT (OPTIONAL)',
                      style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ratingComment,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Punctuality, quality of repair, professionalism...',
                        hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.7)),
                        filled: true,
                        fillColor: AppColors.card2,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border2)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border2)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _ratingValue == 0
                          ? null
                          : () async {
                              setState(() => _ratingSubmitted = true);
                              await Future<void>.delayed(const Duration(milliseconds: 1800));
                              if (mounted) setState(() => _ratingOpen = false);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.card2,
                        foregroundColor: Colors.black,
                        disabledForegroundColor: AppColors.textHint,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('SUBMIT REVIEW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _ratingOpen = false),
                      child: const Text('Not now', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FleetViewModel>();

    if (vm.trackingDetailJobId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) widget.onBack();
      });
      return const ColoredBox(color: AppColors.bg, child: SizedBox.shrink());
    }

    if (vm.trackingDetailLoading && vm.trackingJobDetail == null) {
      return const ColoredBox(
        color: AppColors.bg,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (vm.trackingDetailError != null && vm.trackingJobDetail == null) {
      return ColoredBox(
        color: AppColors.bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  vm.trackingDetailError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: vm.loadTrackingJobDetail,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final d = vm.trackingJobDetail;
    if (d == null) {
      return const ColoredBox(color: AppColors.bg, child: SizedBox.shrink());
    }

    final badge = _statusBadge(d);
    final paymentCfg = switch (d.paymentStatusKey) {
      'authorised' => (label: d.paymentStatusLabel, fg: AppColors.orange, bg: AppColors.orange.withValues(alpha: 0.10), bd: AppColors.orange.withValues(alpha: 0.30)),
      'paid' => (label: d.paymentStatusLabel, fg: AppColors.green, bg: AppColors.green.withValues(alpha: 0.10), bd: AppColors.green.withValues(alpha: 0.30)),
      'refunded' => (label: d.paymentStatusLabel, fg: const Color(0xFF60A5FA), bg: const Color(0xFF60A5FA).withValues(alpha: 0.10), bd: const Color(0xFF60A5FA).withValues(alpha: 0.30)),
      _ => (label: d.paymentStatusLabel, fg: AppColors.primary, bg: AppColors.primary.withValues(alpha: 0.10), bd: AppColors.primary.withValues(alpha: 0.30)),
    };

    final pulseHeader = d.statusLabel.toUpperCase().contains('EN ROUTE') || d.statusLabel.toUpperCase().contains('EN_ROUTE');
    final etaText = d.etaMinutes != null ? '${d.etaMinutes} min' : '—';
    final ratingText = d.mechanicRating != null ? d.mechanicRating!.toStringAsFixed(1) : '—';

    return Stack(
      children: [
        ColoredBox(
          color: AppColors.bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Material(
                      color: AppColors.card2,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: widget.onBack,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border2),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textSecondary),
                        ),
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
                                  d.jobCode,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: badge.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: badge.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    pulseHeader
                                        ? AnimatedBuilder(
                                            animation: _headerPulse,
                                            builder: (context, c) => Opacity(opacity: 0.5 + 0.5 * _headerPulse.value, child: c),
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(color: badge.dot, shape: BoxShape.circle),
                                            ),
                                          )
                                        : Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(color: badge.dot, shape: BoxShape.circle),
                                          ),
                                    const SizedBox(width: 6),
                                    Text(
                                      badge.shortLabel,
                                      style: TextStyle(color: badge.fg, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d.subtitle,
                            style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 11, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E1E1E)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STATUS TIMELINE',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(d.timeline.length, (i) {
                            final step = d.timeline[i];
                            final isDone = step.done;
                            final isActive = step.active;
                            final isLast = i == d.timeline.length - 1;
                            final lineColor = !isDone
                                ? const Color(0xFF1E1E1E)
                                : (!isActive ? AppColors.primary.withValues(alpha: 0.50) : AppColors.primary.withValues(alpha: 0.30));

                            final timeStr = (step.time.isNotEmpty && step.time != '—') ? step.time : (isActive || isDone ? step.time : '—');

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDone ? AppColors.primary : AppColors.card,
                                        border: Border.all(
                                          color: isDone ? AppColors.primary : AppColors.border2,
                                          width: 2,
                                        ),
                                        boxShadow: isActive
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.primary.withValues(alpha: 0.45),
                                                  blurRadius: 12,
                                                  spreadRadius: 0,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: isDone
                                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.black)
                                          : Center(
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(color: Color(0xFF2A2A2A), shape: BoxShape.circle),
                                              ),
                                            ),
                                    ),
                                    if (!isLast)
                                      Container(
                                        width: 2,
                                        height: 22,
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        color: lineColor,
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            step.label,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: isActive
                                                  ? AppColors.primary
                                                  : isDone
                                                      ? Colors.white
                                                      : const Color(0xFF374151),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                            color: isActive
                                                ? AppColors.primary.withValues(alpha: 0.70)
                                                : isDone
                                                    ? AppColors.textMuted
                                                    : const Color(0xFF1F2937),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (d.hasMechanic)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1E1E1E)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ASSIGNED MECHANIC',
                              style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.6),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: AppAssets.mechanicPortrait,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d.mechanicName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text(ratingText, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        d.mechanicPhone.isEmpty ? '—' : d.mechanicPhone,
                                        style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Material(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: () => _dial(context, d.mechanicPhone),
                                    borderRadius: BorderRadius.circular(12),
                                    child: const SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Icon(Icons.call_rounded, color: Colors.black, size: 22),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.only(top: 12),
                              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                              child: Row(
                                children: [
                                  Icon(Icons.schedule_rounded, size: 16, color: AppColors.textHint),
                                  const SizedBox(width: 8),
                                  Text('ETA (from mechanic)', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), fontSize: 12)),
                                  const Spacer(),
                                  Text(etaText, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1E1E1E)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: AppColors.card2, borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.build_outlined, color: AppColors.textHint.withValues(alpha: 0.5)),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Awaiting mechanic assignment', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                                  SizedBox(height: 4),
                                  Text('A nearby mechanic will be assigned shortly', style: TextStyle(color: AppColors.textHint, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E1E1E)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BREAKDOWN LOCATION',
                            style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.6),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_on_outlined, size: 18, color: AppColors.textMuted.withValues(alpha: 0.9)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  d.locationAddress,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton(
                            onPressed: () => _openMaps(context, d),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.30)),
                              backgroundColor: AppColors.primary.withValues(alpha: 0.05),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.open_in_new_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Open in Google Maps', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.3)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E1E1E)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'PAYMENT',
                                style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.6),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: paymentCfg.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: paymentCfg.bd),
                                ),
                                child: Text(
                                  paymentCfg.label,
                                  style: TextStyle(color: paymentCfg.fg, fontSize: 10, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _payRow('Quote Amount', _moneyStr(d.quoteAmount, d.currency), brightValue: true),
                          _payRow('Platform Fee (${d.platformFeePctLabel})', _moneyStr(d.platformFee, d.currency), mutedValue: true),
                          _payRow('Pre-Auth Held', _moneyStr(d.preAuthHeld, d.currency), valueColor: AppColors.orange),
                          _payRow('Card', d.cardLabel, mutedValue: true),
                          const Divider(color: AppColors.border2, height: 20),
                          _payRow('Total Payable', _moneyStr(d.totalPayable, d.currency), brightValue: true, valueYellow: true),
                        ],
                      ),
                    ),
                    if (d.paymentStatusKey == 'released') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.task_alt_rounded, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Invoice Ready', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 2),
                                      Text('${d.jobCode} · ${d.subtitle}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download PDF'))),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.download_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('DOWNLOAD INVOICE (PDF)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (d.paymentStatusKey == 'released' && !_ratingSubmitted) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _ratingOpen = true;
                          _ratingSubmitted = false;
                          _ratingValue = 0;
                          _ratingComment.clear();
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.30)),
                          backgroundColor: AppColors.card,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star_rounded, size: 18, color: AppColors.primary),
                            SizedBox(width: 10),
                            Text('RATE YOUR MECHANIC', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (d.mechanicStartedJourney && d.paymentStatusKey != 'released')
                      FilledButton(
                        onPressed: () => setState(() => _contactOpen = true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 20),
                            SizedBox(width: 10),
                            Text('CONTACT MECHANIC', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8)),
                          ],
                        ),
                      ),
                    if (d.paymentStatusKey != 'released' && d.cancellationCanCancel) ...[
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => setState(() => _cancelOpen = true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                          side: BorderSide(color: AppColors.red.withValues(alpha: 0.30)),
                          backgroundColor: AppColors.red.withValues(alpha: 0.05),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _cancelHasFee(d) ? 'Cancel Job · ${_cancelFeeStr(d)} fee' : 'Cancel Job — Free',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_cancelOpen) _cancelSheet(d),
        if (_contactOpen) _contactSheet(d),
        if (_ratingOpen) _ratingSheet(d),
      ],
    );
  }

  Widget _payRow(String label, String value, {bool brightValue = false, bool mutedValue = false, bool valueYellow = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: valueYellow
                  ? AppColors.primary
                  : valueColor ?? (mutedValue ? AppColors.textMuted : (brightValue ? Colors.white : AppColors.textSecondary)),
              fontSize: 12,
              fontWeight: brightValue || valueYellow ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBottomOverlay extends StatelessWidget {
  const _DetailBottomOverlay({required this.child, this.onBarrierTap, this.align = Alignment.bottomCenter});

  final Widget child;
  final VoidCallback? onBarrierTap;
  final Alignment align;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.85),
        child: GestureDetector(
          onTap: onBarrierTap,
          behavior: HitTestBehavior.opaque,
          child: Align(
            alignment: align,
            child: GestureDetector(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
