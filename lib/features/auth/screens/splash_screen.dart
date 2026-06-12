import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onNavigate});

  final void Function(String) onNavigate;

  static const Color _kBg = Color(0xFF080808);
  static const Color _kAccentYellow = Color(0xFFFFCC00);
  static const Color _kWrench = Color(0xFF000000);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: ColoredBox(color: _kBg)),
          const Positioned.fill(
            child: CustomPaint(
              painter: _SplashDiagonalStripesPainter(),
            ),
          ),
          // Top glow (matches React: yellow blur at top-center).
          Positioned(
            top: -30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 300,
                height: 200,
                decoration: BoxDecoration(
                  color: _kAccentYellow.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon block with soft glow behind.
                          SizedBox(
                            width: 96,
                            height: 96,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 14, sigmaY: 14),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: _kAccentYellow.withValues(
                                              alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(28),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 96,
                                  height: 96,
                                  clipBehavior: Clip.antiAlias,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _kAccentYellow,
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _kAccentYellow.withValues(
                                            alpha: 0.30),
                                        blurRadius: 20,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Transform.translate(
                                    offset: const Offset(-1.0, -1.5),
                                    child: Transform.rotate(
                                      angle: -math.pi / -2,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.build_outlined,
                                        size: 48,
                                        color: _kWrench,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text.rich(
                              textAlign: TextAlign.center,
                              TextSpan(
                                style: const TextStyle(
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                  height: 1.0,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 3),
                                      blurRadius: 0,
                                      color: Color(0xFF000000),
                                    ),
                                  ],
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'TRUCK',
                                    style: TextStyle(color: Color(0xFFFFFFFF)),
                                  ),
                                  TextSpan(
                                    text: 'FIX',
                                    style: TextStyle(color: _kAccentYellow),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                  height: 1,
                                  width: 56,
                                  color: _kAccentYellow.withValues(alpha: 0.5)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  'PRO',
                                  style: TextStyle(
                                    color: _kAccentYellow,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 4,
                                  ),
                                ),
                              ),
                              Container(
                                  height: 1,
                                  width: 56,
                                  color: _kAccentYellow.withValues(alpha: 0.5)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Emergency breakdown assistance. Connect\ninstantly with certified mechanics.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => onNavigate('role-select-signup'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kAccentYellow,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              shadowColor:
                                  _kAccentYellow.withValues(alpha: 0.35),
                            ),
                            child: const Text(
                              'GET STARTED →',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                                color: Color(0xFF000000),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFFFFFF),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => onNavigate('login'),
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                              color: Color(0xFFFFFFFF),
                            ),
                            children: [
                              const TextSpan(text: 'Already registered? '),
                              TextSpan(
                                text: 'Login',
                                style: TextStyle(
                                  color: _kAccentYellow,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashDiagonalStripesPainter extends CustomPainter {
  const _SplashDiagonalStripesPainter();

  static const Color _stripe = Color(0xFFFFCC00);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _stripe.withValues(alpha: 0.035)
      ..strokeWidth = 1
      ..isAntiAlias = true;

    // Match React: repeating diagonal stripes with wide gaps.
    // Equivalent to `repeating-linear-gradient(45deg, yellow 0..2px, transparent ..28px)`.
    const double spacing = 28;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
