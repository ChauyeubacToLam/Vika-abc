import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../v5_primitives.dart';
import '../v5_theme.dart';

/// S01 — Welcome. The first frame. Designed to feel like the opening of a
/// premium athletic app (Future, Caliber, Whoop): big confident brand mark,
/// a living visualization that hints at the AI-camera differentiator, and a
/// headline that lands without explaining itself.
class S01Welcome extends StatelessWidget {
  const S01Welcome({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    final bottomInset = r.viewPadding.bottom;
    return V5Screen(
      index: 1,
      inverted: true,
      background: V5.heroBg,
      showChrome: false,
      children: [
        // Background layers
        const Positioned(
          top: -160,
          left: -140,
          child: V5AmbientGlow(
            size: Size(420, 480),
            opacity: 0.28,
            color: V5.yellow,
          ),
        ),
        const Positioned(
          right: -170,
          bottom: -180,
          child: V5AmbientGlow(
            size: Size(380, 380),
            opacity: 0.14,
            color: Color(0xFFCD7C45),
          ),
        ),
        const Positioned.fill(child: V5Texture(opacity: 0.06, density: 1.2)),

        // Main body
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                V5.gutter,
                r.viewPadding.top + r.pick(cozy: 28.0, short: 18.0, veryShort: 10.0),
                V5.gutter,
                bottomInset + r.pick(cozy: 132.0, short: 116.0, veryShort: 102.0),
              ),
              child: Column(
                children: [
                  V5FadeIn(child: const _WelcomeBrand()),
                  SizedBox(height: r.pick(cozy: V5.space20, short: V5.space12)),
                  Expanded(
                    child: V5FadeIn(
                      delay: const Duration(milliseconds: 140),
                      slideY: 12,
                      child: const _WelcomeStage(),
                    ),
                  ),
                  SizedBox(height: r.pick(cozy: V5.space20, short: V5.space14)),
                  V5FadeIn(
                    delay: const Duration(milliseconds: 260),
                    slideY: 8,
                    child: const _CameraAiPill(),
                  ),
                  SizedBox(height: r.pick(cozy: V5.space24, short: V5.space16)),
                  V5FadeIn(
                    delay: const Duration(milliseconds: 340),
                    slideY: 14,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _WelcomeHeadline(responsive: r),
                    ),
                  ),
                  SizedBox(height: r.pick(cozy: V5.space12, short: V5.space8)),
                  V5FadeIn(
                    delay: const Duration(milliseconds: 420),
                    slideY: 8,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Camera AI quan sát từng chuyển động và đưa ra hướng dẫn cá nhân hoá cho cơ thể bạn.',
                        maxLines: r.isVeryShort ? 2 : 3,
                        style: V5.bodyLg(context, color: V5.invInkSoft),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Primary CTA
        V5PillCTA(
          label: 'Bắt đầu hành trình',
          onTap: onNext,
          yellow: true,
          bottom: 32 + bottomInset,
        ),

        // Footer signature
        if (!r.isVeryShort)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12 + bottomInset,
            child: Text(
              'Phát triển tại Việt Nam  ·  16 bước trong 3 phút',
              textAlign: TextAlign.center,
              style: V5
                  .caption(context, color: V5.invInkFaint)
                  .copyWith(letterSpacing: 0.4),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Brand mark
// ─────────────────────────────────────────────────────────────

class _WelcomeBrand extends StatelessWidget {
  const _WelcomeBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: V5.accentGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: V5.yellowGlow(0.28),
              ),
              alignment: Alignment.center,
              child: Text(
                'V',
                style: V5.text(
                  context,
                  size: 18,
                  weight: FontWeight.w900,
                  color: V5.yellowInk,
                  letterSpacing: -0.6,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: V5.space10),
            Text(
              'vika',
              style: V5.text(
                context,
                size: 26,
                weight: FontWeight.w800,
                color: V5.invInk,
                letterSpacing: -1.1,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: V5.space8),
        Text(
          'HUẤN LUYỆN VIÊN AI CỦA BẠN',
          style: V5
              .eyebrow(context, color: V5.invInkSoft)
              .copyWith(letterSpacing: 1.4),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Camera AI pill (glass)
// ─────────────────────────────────────────────────────────────

class _CameraAiPill extends StatelessWidget {
  const _CameraAiPill();

  @override
  Widget build(BuildContext context) {
    return V5Glass(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const V5PulseDot(color: V5.yellow),
          const SizedBox(width: V5.space8),
          Text(
            'CAMERA AI  ·  PHÂN TÍCH FORM THỜI GIAN THỰC',
            style: V5
                .eyebrow(context, color: V5.invInk)
                .copyWith(letterSpacing: 1.0),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Headline — two lines that wrap naturally
// ─────────────────────────────────────────────────────────────

class _WelcomeHeadline extends StatelessWidget {
  const _WelcomeHeadline({required this.responsive});

  final V5Responsive responsive;

  @override
  Widget build(BuildContext context) {
    final size = responsive.pick(
      cozy: 44.0,
      short: 40.0,
      veryShort: 34.0,
      tall: 48.0,
    );
    final style = V5.text(
      context,
      size: size,
      weight: FontWeight.w800,
      color: V5.invInk,
      letterSpacing: -2.0,
      height: 0.95,
    );
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'Tập đúng.\n'),
          TextSpan(
            text: 'Tiến bộ thật.',
            style: TextStyle(color: V5.yellow),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Welcome stage — the animated hero (pose detection visualization)
// ─────────────────────────────────────────────────────────────

class _WelcomeStage extends StatefulWidget {
  const _WelcomeStage();

  @override
  State<_WelcomeStage> createState() => _WelcomeStageState();
}

class _WelcomeStageState extends State<_WelcomeStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      duration: const Duration(milliseconds: 6800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 0.94,
        child: AnimatedBuilder(
          animation: _loop,
          builder: (context, _) => CustomPaint(
            painter: _WelcomeStagePainter(progress: _loop.value),
          ),
        ),
      ),
    );
  }
}

class _WelcomeStagePainter extends CustomPainter {
  const _WelcomeStagePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * 0.46;

    // Soft halo
    final breathe = 0.5 + math.sin(progress * math.pi * 2) * 0.5;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            V5.yellow.withValues(alpha: 0.18 + breathe * 0.06),
            Colors.white.withValues(alpha: 0.04),
            Colors.transparent,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // Concentric rings
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        center,
        r * (0.36 + i * 0.14),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 4 ? 1.4 : 1
          ..color = (i == 4 ? V5.yellow : V5.invInk)
              .withValues(alpha: i == 4 ? 0.38 : 0.10),
      );
    }

    // Rotating accent arcs
    final arcPaint = Paint()
      ..color = V5.yellow.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final outer = Rect.fromCircle(center: center, radius: r * 0.93);
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        outer,
        progress * math.pi * 2 + i * math.pi * 2 / 3,
        math.pi / 8,
        false,
        arcPaint,
      );
    }

    // Pose skeleton — abstract figure that "breathes"
    final skeletonProgress = progress * 2 * math.pi;
    final flex = math.sin(skeletonProgress) * 0.06;

    final figureScale = r * 0.78;
    final fx = center.dx;
    final fy = center.dy;
    final head = Offset(fx, fy - figureScale * 0.42);
    final neck = head + Offset(0, figureScale * 0.10);
    final hip = Offset(fx, fy + figureScale * 0.06);
    final shoulderL = neck + Offset(-figureScale * 0.16, figureScale * 0.02);
    final shoulderR = neck + Offset(figureScale * 0.16, figureScale * 0.02);
    final elbowL = shoulderL +
        Offset(-figureScale * 0.10, figureScale * (0.16 - flex));
    final elbowR = shoulderR +
        Offset(figureScale * 0.10, figureScale * (0.16 - flex));
    final handL = elbowL + Offset(-figureScale * 0.04, figureScale * 0.14);
    final handR = elbowR + Offset(figureScale * 0.04, figureScale * 0.14);
    final kneeL = hip +
        Offset(-figureScale * 0.10, figureScale * (0.22 + flex * 1.4));
    final kneeR = hip +
        Offset(figureScale * 0.10, figureScale * (0.22 + flex * 1.4));
    final footL = Offset(kneeL.dx, fy + figureScale * 0.46);
    final footR = Offset(kneeR.dx, fy + figureScale * 0.46);

    final bonePaint = Paint()
      ..color = V5.invInk.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Bones
    canvas.drawLine(neck, hip, bonePaint);
    canvas.drawLine(shoulderL, shoulderR, bonePaint);
    canvas.drawLine(shoulderL, elbowL, bonePaint);
    canvas.drawLine(elbowL, handL, bonePaint);
    canvas.drawLine(shoulderR, elbowR, bonePaint);
    canvas.drawLine(elbowR, handR, bonePaint);
    canvas.drawLine(hip, kneeL, bonePaint);
    canvas.drawLine(kneeL, footL, bonePaint);
    canvas.drawLine(hip, kneeR, bonePaint);
    canvas.drawLine(kneeR, footR, bonePaint);

    // Head
    canvas.drawCircle(
      head,
      figureScale * 0.06,
      Paint()..color = V5.invInk.withValues(alpha: 0.86),
    );

    // Joint highlights — yellow accent dots that scan around the body
    final joints = [
      neck,
      hip,
      shoulderL,
      shoulderR,
      elbowL,
      elbowR,
      handL,
      handR,
      kneeL,
      kneeR,
      footL,
      footR,
    ];
    final activeIndex = (progress * joints.length * 1.6).floor() % joints.length;
    for (var i = 0; i < joints.length; i++) {
      final j = joints[i];
      final isActive = i == activeIndex;
      final ringR = isActive ? 5.5 : 3.2;
      canvas.drawCircle(
        j,
        ringR,
        Paint()..color = V5.yellow.withValues(alpha: isActive ? 0.95 : 0.42),
      );
      if (isActive) {
        canvas.drawCircle(
          j,
          ringR + 4,
          Paint()
            ..color = V5.yellow.withValues(alpha: 0.20)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WelcomeStagePainter old) =>
      old.progress != progress;
}
