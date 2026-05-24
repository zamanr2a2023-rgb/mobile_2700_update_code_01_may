import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TruckFixLoadingScreen extends StatefulWidget {
  const TruckFixLoadingScreen({super.key, this.onAnimationComplete});

  /// Fired once when the gear ring animation finishes a full forward cycle (same moment [totalDuration] elapses).
  final VoidCallback? onAnimationComplete;

  static const Color accent = Color(0xFFFFD700);

  /// Must match [AnimationController] duration below (intro gate uses [onAnimationComplete]).
  static const Duration totalDuration = Duration(milliseconds: 2200);

  @override
  State<TruckFixLoadingScreen> createState() => _TruckFixLoadingScreenState();
}

class _TruckFixLoadingScreenState extends State<TruckFixLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: TruckFixLoadingScreen.totalDuration)
      ..addStatusListener(_onAnimStatus)
      ..forward();
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onAnimationComplete?.call();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimStatus);
    _controller.dispose();
    super.dispose();
  }

  int _wordPhase(double t) {
    if (t >= 0.84) return 2;
    if (t >= 0.70) return 1;
    if (t >= 0.55) return 0;
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    const words = ['EASY', 'FAST', 'RELIABLE'];

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.linear.transform(_controller.value.clamp(0, 1));
              final phase = _wordPhase(t);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: Text.rich(
                      TextSpan(
                        style: GoogleFonts.bebasNeue(
                          fontSize: 52,
                          letterSpacing: 8,
                          height: 1,
                        ),
                        children: const [
                          TextSpan(
                            text: 'TRUCK',
                            style: TextStyle(color: TruckFixLoadingScreen.accent),
                          ),
                          TextSpan(
                            text: 'FIX',
                            style: TextStyle(color: Color(0xFFFFFFFF)),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Transform.scale(
                    scaleX: Curves.easeOut.transform((t / 0.35).clamp(0, 1)),
                    child: Container(
                      width: 120,
                      height: 1,
                      color: TruckFixLoadingScreen.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GearPainter(progress: t),
                          ),
                        ),
                        Center(
                          child: Transform.rotate(
                            angle: -30 * math.pi / 180,
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (context, _) {
                                final wobble = math.sin(_controller.value * 2 * math.pi * 2) *
                                    (8 * math.pi / 180);
                                return Transform.rotate(
                                  angle: wobble,
                                  child: const Icon(
                                    Icons.build_outlined,
                                    size: 44,
                                    color: Color(0xFF888888),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(words.length, (i) {
                      final show = phase >= i;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedOpacity(
                            opacity: show ? 1 : 0,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                            child: AnimatedSlide(
                              offset: show ? Offset.zero : const Offset(0, 0.35),
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  words[i],
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 4,
                                    color: const Color(0xFF666666),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (i < words.length - 1)
                            AnimatedOpacity(
                              opacity: phase >= i ? 1 : 0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              child: const Text(
                                '·',
                                style: TextStyle(
                                  color: Color(0xFF2A2A2A),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GearPainter extends CustomPainter {
  const _GearPainter({required this.progress});

  final double progress; // 0..1

  static const double _s = 180;
  static const double _cx = _s / 2;
  static const double _cy = _s / 2;
  static const double _ro = 68;
  static const double _ri = 50;
  static const int _n = 8;

  Path _buildGearPath() {
    final seg = (2 * math.pi) / _n;
    final p = Path();
    Offset P(double r, double a) => Offset(_cx + r * math.cos(a), _cy + r * math.sin(a));

    for (var i = 0; i < _n; i++) {
      final base = i * seg - math.pi / 2;
      final riseInner = P(_ri, base + seg * 0.20);
      final tipLead = P(_ro, base + seg * 0.30);
      final tipTrail = P(_ro, base + seg * 0.70);
      final fallInner = P(_ri, base + seg * 0.80);

      if (i == 0) {
        p.moveTo(riseInner.dx, riseInner.dy);
      } else {
        p.arcToPoint(
          riseInner,
          radius: const Radius.circular(_ri),
          clockwise: true,
        );
      }
      p.lineTo(tipLead.dx, tipLead.dy);
      p.arcToPoint(
        tipTrail,
        radius: const Radius.circular(_ro),
        clockwise: true,
      );
      p.lineTo(fallInner.dx, fallInner.dy);
    }

    final firstRise = P(_ri, -math.pi / 2 + seg * 0.20);
    p.arcToPoint(
      firstRise,
      radius: const Radius.circular(_ri),
      clockwise: true,
    );
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildGearPath();

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..color = const Color(0xFF1A1A1A)
      ..isAntiAlias = true;

    canvas.drawPath(path, basePaint);

    final metrics = path.computeMetrics().toList(growable: false);
    final totalLen = metrics.fold<double>(0, (sum, m) => sum + m.length);

    // Near end of the sweep, path extraction can leave a visible gap on the closed gear; draw the full ring.
    if (progress >= 0.999) {
      final glowPaintFull = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = TruckFixLoadingScreen.accent.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      final paintFull = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = TruckFixLoadingScreen.accent
        ..isAntiAlias = true;
      canvas.drawPath(path, glowPaintFull);
      canvas.drawPath(path, paintFull);
      return;
    }

    final drawLen = totalLen * progress.clamp(0, 1);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = TruckFixLoadingScreen.accent.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = TruckFixLoadingScreen.accent
      ..isAntiAlias = true;

    final partial = Path();
    var remaining = drawLen;
    for (final m in metrics) {
      if (remaining <= 0) break;
      final len = math.min(m.length, remaining);
      partial.addPath(m.extractPath(0, len), Offset.zero);
      remaining -= len;
    }

    canvas.drawPath(partial, glowPaint);
    canvas.drawPath(partial, paint);
  }

  @override
  bool shouldRepaint(covariant _GearPainter oldDelegate) => oldDelegate.progress != progress;
}

