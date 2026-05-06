import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../v5_primitives.dart';
import '../v5_theme.dart';

class S01Welcome extends StatelessWidget {
  const S01Welcome({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: V5.heroBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -120,
            left: -120,
            child: _AtmosphericGlow(width: 360, height: 480, opacity: 0.28),
          ),
          const Positioned(
            right: -120,
            bottom: -120,
            child: _AtmosphericGlow(width: 340, height: 360, opacity: 0.14),
          ),
          const Positioned(top: 120, right: 36, child: Opacity(opacity: 0.55, child: V5Sparkle(size: 11))),
          const Positioned(top: 200, left: 42, child: Opacity(opacity: 0.40, child: V5Sparkle(size: 8))),
          const Positioned(top: 520, right: 60, child: Opacity(opacity: 0.45, child: V5Sparkle(size: 9))),
          const V5StatusBar(inverted: true),
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: V5FadeIn(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: V5.yellow,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: V5.yellow.withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'V',
                          style: V5.text(
                            context,
                            size: 16,
                            weight: FontWeight.w900,
                            color: V5.yellowInk,
                            letterSpacing: -0.6,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'vika',
                        style: V5.text(
                          context,
                          size: 24,
                          weight: FontWeight.w800,
                          color: V5.invInk,
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'HLV CÁ NHÂN HOÁ BẰNG AI',
                    style: V5.text(
                      context,
                      size: 9,
                      weight: FontWeight.w700,
                      color: V5.invInkSoft,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 160,
            left: 0,
            right: 0,
            bottom: 386,
            child: Center(
              // TODO(WELCOME-HERO-SWAP): Replace with looping video when asset is provided.
              // Final asset will be a 9:16 looping video (~3-5s) of a PT doing a squat
              // with MediaPipe skeleton overlay rendered on top. Use video_player package.
              // Video should: autoplay, loop, mute, no controls, no fullscreen.
              // Keep all surrounding chrome (wordmark, sparkles, glow, indicator pill, headline, CTA).
              child: WelcomeHero(),
            ),
          ),
          Positioned(
            bottom: 340,
            left: 0,
            right: 0,
            child: Center(
              child: V5FadeIn(
                child: V5Glass(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const V5PulseDot(),
                      const SizedBox(width: 6),
                      Text(
                        'CAMERA AI · PHÂN TÍCH FORM',
                        style: V5.text(
                          context,
                          size: 9,
                          weight: FontWeight.w700,
                          color: V5.invInk,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 170,
            child: V5FadeIn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tập đúng.\nTiến bộ thật.',
                    style: V5.text(
                      context,
                      size: 42,
                      weight: FontWeight.w800,
                      color: V5.invInk,
                      letterSpacing: -1.8,
                      height: 0.95,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Camera AI quan sát từng chuyển động & đưa ra hướng dẫn cá nhân hoá cho cơ thể bạn.',
                    style: V5.text(
                      context,
                      size: 13,
                      weight: FontWeight.w500,
                      color: V5.invInkSoft,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          V5PillCTA(
            label: 'Bắt đầu hành trình',
            onTap: onNext,
            yellow: true,
            bottom: 64,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 30,
            child: Text(
              'Phát triển tại Việt Nam · 16 bước trong 3 phút',
              textAlign: TextAlign.center,
              style: V5.text(
                context,
                size: 10,
                weight: FontWeight.w600,
                color: V5.invInkSoft,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AtmosphericGlow extends StatelessWidget {
  const _AtmosphericGlow({
    required this.width,
    required this.height,
    required this.opacity,
  });

  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    // RadialGradient instead of ImageFiltered+blur — same soft halo, no
    // filter pass that flashes the unblurred yellow disk on first frame.
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            V5.yellow.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class WelcomeHero extends StatefulWidget {
  const WelcomeHero({super.key});

  @override
  State<WelcomeHero> createState() => _WelcomeHeroState();
}

class _WelcomeHeroState extends State<WelcomeHero>
    with TickerProviderStateMixin {
  late final AnimationController _trace;
  late final AnimationController _halo;

  @override
  void initState() {
    super.initState();
    _trace = AnimationController(
      duration: const Duration(milliseconds: 1360),
      vsync: this,
    )..forward();
    _halo = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );
    Future<void>.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _halo.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _trace.dispose();
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return V5FadeIn(
      child: SizedBox(
        width: 280,
        height: 300,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Opacity(opacity: 0.85, child: V5HeroFigure(pose: 'squat')),
            AnimatedBuilder(
              animation: Listenable.merge([_trace, _halo]),
              builder: (context, _) => CustomPaint(
                painter: _SkeletonPainter(
                  trace: _trace.value,
                  halo: _halo.value,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter({required this.trace, required this.halo});

  final double trace;
  final double halo;

  static final _segments = <({Path path, double start})>[
    (path: Path()..moveTo(162, 85)..lineTo(162, 110), start: .15),
    (path: Path()..moveTo(142, 113)..lineTo(184, 113), start: .21),
    (path: Path()..moveTo(162, 113)..lineTo(168, 200)..lineTo(175, 268), start: .26),
    (path: Path()..moveTo(142, 113)..quadraticBezierTo(100, 165, 92, 200), start: .32),
    (path: Path()..moveTo(184, 113)..quadraticBezierTo(226, 165, 234, 200), start: .32),
    (path: Path()..moveTo(175, 268)..lineTo(156, 308)..lineTo(165, 350), start: .41),
    (path: Path()..moveTo(175, 268)..lineTo(196, 308)..lineTo(187, 350), start: .41),
  ];

  static const _points = <({Offset p, double start, double r})>[
    (p: Offset(162, 85), start: .15, r: 3),
    (p: Offset(142, 113), start: .24, r: 3),
    (p: Offset(184, 113), start: .24, r: 3),
    (p: Offset(92, 200), start: .35, r: 2.5),
    (p: Offset(234, 200), start: .35, r: 2.5),
    (p: Offset(175, 268), start: .30, r: 3),
    (p: Offset(156, 308), start: .44, r: 2.5),
    (p: Offset(196, 308), start: .44, r: 2.5),
    (p: Offset(165, 350), start: .51, r: 2.5),
    (p: Offset(187, 350), start: .51, r: 2.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = math.min(size.width / 320, size.height / 380);
    canvas.translate((size.width - 320 * scale) / 2, (size.height - 380 * scale) / 2);
    canvas.scale(scale);

    final stroke = Paint()
      ..color = V5.yellow.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (final segment in _segments) {
      final t = ((trace - segment.start) / 0.58).clamp(0.0, 1.0);
      final eased = 1 - math.pow(1 - t, 3);
      for (final metric in segment.path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * eased), stroke);
      }
    }

    final dotPaint = Paint()..color = V5.yellow;
    for (final point in _points) {
      final t = ((trace - point.start) / 0.24).clamp(0.0, 1.0);
      final pop = t < .6 ? t / .6 * 1.3 : 1.3 - ((t - .6) / .4) * .3;
      if (t > 0) canvas.drawCircle(point.p, point.r * pop, dotPaint);
    }

    final haloPaint = Paint()
      ..color = V5.yellow.withValues(alpha: 0.20 + halo * 0.20);
    canvas.drawCircle(const Offset(162, 85), 6 + 4 * halo, haloPaint);
    canvas.drawCircle(const Offset(175, 268), 6 + 4 * halo, haloPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter oldDelegate) =>
      oldDelegate.trace != trace || oldDelegate.halo != halo;
}
