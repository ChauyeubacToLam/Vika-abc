// The 5-second cinematic moment between exercises. Designed to be
// visible (and impressive) from across the room — the user just finished
// their last rep and put the phone down a few meters away. Big score,
// big motion, big restraint.
//
// Choreography (5000ms total):
//   0   →  800  : backdrop in, vignette tightens, ember particles rise,
//                 atmospheric glows fade up
//   400 → 2400  : score reveal — 3 concentric rings pulse outward,
//                 score digit ticker counts up (eased), star burst on
//                 completion, score arc traces around it
//   1800 → 3600 : praise line types in word-by-word over a thin yellow
//                 underline trace
//   3000 → 4500 : "BÀI TIẾP THEO · X" eyebrow lifts; chevron pulse
//   4500 → 5000 : glide out (translate up + fade)
//
// Visual elements (all painted, no assets):
//   • Warm-dark gradient + radial yellow + amber atmospheric stack
//   • Vignette
//   • Drifting ember particles (12 dots, deterministic seed)
//   • 3 concentric rings pulsing on a 1200ms loop
//   • Yellow score arc growing 0 → progress
//   • Star burst (8 rays) flaring out at score completion
//   • Word-by-word reveal with mask-trace underline
//   • Yellow corner ray accents (4 corners)
//   • Bottom progress ticker
//
// Auto-advances via [onComplete] at [totalDurationMs].

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

class ExerciseTransitionMoment extends StatefulWidget {
  const ExerciseTransitionMoment({
    super.key,
    required this.exerciseName,
    required this.formScore,
    required this.praiseLine,
    required this.nextExerciseName,
    required this.onComplete,
    this.totalDurationMs = 5000,
  });

  final String exerciseName;
  final int formScore;
  final String praiseLine;

  /// e.g. "Bài tiếp theo · Lunge" or "Tổng kết buổi tập" when final.
  final String nextExerciseName;

  final VoidCallback onComplete;
  final int totalDurationMs;

  @override
  State<ExerciseTransitionMoment> createState() =>
      _ExerciseTransitionMomentState();
}

class _ExerciseTransitionMomentState extends State<ExerciseTransitionMoment>
    with TickerProviderStateMixin {
  late final AnimationController _master;
  late final AnimationController _ringPulse;
  late final AnimationController _embers;

  // Choreographed sub-animations, normalized to the 5s master timeline.
  late final Animation<double> _enter;        // 0.00 → 0.16
  late final Animation<double> _scoreCount;   // 0.08 → 0.48
  late final Animation<double> _starBurst;    // 0.40 → 0.56
  late final Animation<double> _praiseIn;     // 0.36 → 0.72
  late final Animation<double> _underline;    // 0.42 → 0.78
  late final Animation<double> _nextIn;       // 0.60 → 0.90
  late final Animation<double> _exit;         // 0.90 → 1.00

  @override
  void initState() {
    super.initState();
    _master = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.totalDurationMs),
    );
    _ringPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _embers = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _enter = _slice(0.00, 0.16, Curves.easeOutCubic);
    _scoreCount = _slice(0.08, 0.48, Curves.easeOutCubic);
    _starBurst = _slice(0.40, 0.56, Curves.easeOutCubic);
    _praiseIn = _slice(0.36, 0.72, Curves.easeOutCubic);
    _underline = _slice(0.42, 0.78, Curves.easeInOutCubic);
    _nextIn = _slice(0.60, 0.90, Curves.easeOutCubic);
    _exit = _slice(0.90, 1.00, Curves.easeInCubic);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _master.forward().whenComplete(() {
        if (!mounted) return;
        widget.onComplete();
      });
    });
  }

  Animation<double> _slice(double a, double b, Curve curve) {
    return CurvedAnimation(
      parent: _master,
      curve: Interval(a, b, curve: curve),
    );
  }

  @override
  void dispose() {
    _master.dispose();
    _ringPulse.dispose();
    _embers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // Clamp text scaling so the giant 132pt italic score can't blow up
    // past the screen at maxed-out accessibility text.
    final mq = MediaQuery.of(context);
    final clampedScaler = mq.textScaler.clamp(
      minScaleFactor: 0.9,
      maxScaleFactor: 1.1,
    );
    return MediaQuery(
      data: mq.copyWith(textScaler: clampedScaler),
      child: Scaffold(
      backgroundColor: c.bgInverse,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_master, _ringPulse, _embers]),
          builder: (context, _) {
            final exitFade = 1.0 - _exit.value;
            return Opacity(
              opacity: exitFade,
              child: Transform.translate(
                offset: Offset(0, -20 * _exit.value),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Backdrop(enter: _enter.value),
                    CustomPaint(
                      painter: _EmbersPainter(
                        progress: _embers.value,
                        opacity: _enter.value,
                      ),
                    ),
                    CustomPaint(
                      painter: _CornerRaysPainter(opacity: _enter.value * 0.65),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Eyebrow(
                              opacity: _enter.value,
                              text:
                                  'BÀI VỪA RỒI · ${widget.exerciseName.toUpperCase()}',
                            ),
                            const SizedBox(height: 30),
                            _ScoreMonument(
                              targetScore: widget.formScore,
                              countProgress: _scoreCount.value,
                              ringPulse: _ringPulse.value,
                              starBurst: _starBurst.value,
                            ),
                            const SizedBox(height: 38),
                            _PraiseTypewriter(
                              text: widget.praiseLine,
                              progress: _praiseIn.value,
                              underlineProgress: _underline.value,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 64,
                      child: _NextBanner(
                        text: widget.nextExerciseName,
                        opacity: _nextIn.value,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 26,
                      child: _ProgressTicker(animation: _master),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}

// ─── BACKDROP: warm-dark gradient + ambient glow stack + vignette ───
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.enter});
  final double enter;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.8, -1),
              end: const Alignment(0.8, 1),
              colors: [c.bgInverse, c.bgInverseHi],
            ),
          ),
        ),
        Positioned(
          top: -180,
          right: -140,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.55 + (enter * 0.45),
              child: SizedBox(
                width: 540,
                height: 540,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        c.yellow.withValues(alpha: 0.28),
                        c.yellow.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -240,
          left: -180,
          child: IgnorePointer(
            child: Opacity(
              opacity: enter,
              child: SizedBox(
                width: 520,
                height: 460,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0x55CD7C45), Color(0x00CD7C45)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.95,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55 * enter),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: const _GrainPainter()),
        ),
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(2718);
    final paint = Paint();
    for (var i = 0; i < 260; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      paint.color =
          Colors.white.withValues(alpha: 0.014 + rng.nextDouble() * 0.022);
      canvas.drawCircle(Offset(dx, dy), 0.7, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => false;
}

// ─── EMBERS: 12 deterministic particles drifting upward ───
class _EmbersPainter extends CustomPainter {
  const _EmbersPainter({required this.progress, required this.opacity});
  final double progress;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final rng = math.Random(91021);
    final yellow = const Color(0xFFFFB701);
    final amber = const Color(0xFFCD7C45);
    final paint = Paint();
    for (var i = 0; i < 14; i++) {
      final seedX = rng.nextDouble();
      final speed = 0.55 + rng.nextDouble() * 0.65;
      final phase = rng.nextDouble();
      final t = (progress * speed + phase) % 1.0;
      final dx = (0.08 + seedX * 0.84) * size.width +
          math.sin(t * 2 * math.pi + i) * 16;
      final dy = (1 - t) * size.height + 20;
      final r = 1.4 + rng.nextDouble() * 2.6;
      final alpha = opacity *
          (1 - t).clamp(0.0, 1.0) *
          (0.35 + rng.nextDouble() * 0.45);
      paint.color = (i % 3 == 0 ? amber : yellow).withValues(alpha: alpha);
      canvas.drawCircle(Offset(dx, dy), r, paint);
      paint.color =
          (i % 3 == 0 ? amber : yellow).withValues(alpha: alpha * 0.16);
      canvas.drawCircle(Offset(dx, dy), r * 6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmbersPainter old) =>
      old.progress != progress || old.opacity != opacity;
}

// ─── CORNER RAYS: 4 thin yellow lines marking each corner ───
class _CornerRaysPainter extends CustomPainter {
  const _CornerRaysPainter({required this.opacity});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final yellow = const Color(0xFFFFB701);
    final p = Paint()
      ..color = yellow.withValues(alpha: 0.42 * opacity)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    // Top-left
    canvas.drawLine(const Offset(28, 28), const Offset(28, 64), p);
    canvas.drawLine(const Offset(28, 28), const Offset(64, 28), p);
    // Top-right
    canvas.drawLine(Offset(size.width - 28, 28),
        Offset(size.width - 28, 64), p);
    canvas.drawLine(Offset(size.width - 28, 28),
        Offset(size.width - 64, 28), p);
    // Bottom-left
    canvas.drawLine(Offset(28, size.height - 28),
        Offset(28, size.height - 64), p);
    canvas.drawLine(Offset(28, size.height - 28),
        Offset(64, size.height - 28), p);
    // Bottom-right
    canvas.drawLine(Offset(size.width - 28, size.height - 28),
        Offset(size.width - 28, size.height - 64), p);
    canvas.drawLine(Offset(size.width - 28, size.height - 28),
        Offset(size.width - 64, size.height - 28), p);
  }

  @override
  bool shouldRepaint(covariant _CornerRaysPainter old) =>
      old.opacity != opacity;
}

// ─── EYEBROW ───
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.opacity, required this.text});
  final double opacity;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, -8 * (1 - opacity)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 1.5,
              decoration: BoxDecoration(
                color: c.yellow,
                boxShadow: [
                  BoxShadow(
                    color: c.yellow.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                  color: c.yellow,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 22,
              height: 1.5,
              decoration: BoxDecoration(
                color: c.yellow,
                boxShadow: [
                  BoxShadow(
                    color: c.yellow.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SCORE MONUMENT: 3 rings + count-up + star burst + arc ───
class _ScoreMonument extends StatelessWidget {
  const _ScoreMonument({
    required this.targetScore,
    required this.countProgress,
    required this.ringPulse,
    required this.starBurst,
  });

  final int targetScore;
  final double countProgress;
  final double ringPulse;
  final double starBurst;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final display = (targetScore * countProgress).round();
    final ringOpacity = (countProgress * 1.3).clamp(0.0, 1.0);
    final introScale = 0.86 + (countProgress * 0.14);

    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 3 pulsing concentric rings
          CustomPaint(
            size: const Size(320, 320),
            painter: _PulsingRingsPainter(
              pulse: ringPulse,
              opacity: ringOpacity,
              color: c.yellow,
            ),
          ),
          // Star burst (peaks at starBurst.value)
          CustomPaint(
            size: const Size(320, 320),
            painter: _StarBurstPainter(
              progress: starBurst,
              color: c.yellow,
            ),
          ),
          // Yellow score arc
          Transform.scale(
            scale: introScale,
            child: SizedBox(
              width: 240,
              height: 240,
              child: CustomPaint(
                painter: _ScoreArcPainter(
                  progress: countProgress,
                  color: c.yellow,
                  opacity: ringOpacity,
                ),
              ),
            ),
          ),
          // Score numeral + axis ticks
          Transform.scale(
            scale: introScale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FORM SCORE',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                    color: c.invInkFaint,
                  ),
                ),
                const SizedBox(height: 12),
                // FittedBox lets the 132pt numeral shrink on very small
                // phones (e.g. iPhone SE 320pt-wide) while keeping its
                // intended size on regular and large devices.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      display.toString(),
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 132,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -7,
                        height: 0.92,
                        color: c.invInk,
                        fontFeatures: VikaIvoryMain.tabularFigures,
                        shadows: [
                          Shadow(
                            color: c.yellow
                                .withValues(alpha: 0.32 * ringOpacity),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 14,
                      height: 1,
                      color: c.invInkFaint,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '/ 100',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.3,
                        color: c.invInkSoft,
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 14,
                      height: 1,
                      color: c.invInkFaint,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingRingsPainter extends CustomPainter {
  const _PulsingRingsPainter({
    required this.pulse,
    required this.opacity,
    required this.color,
  });
  final double pulse;
  final double opacity;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (var i = 0; i < 3; i++) {
      final t = ((pulse + i / 3) % 1.0);
      final radius = 100 + (t * 80);
      final a = (1 - t) * 0.45 * opacity;
      paint.color = color.withValues(alpha: a);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsingRingsPainter old) =>
      old.pulse != pulse || old.opacity != opacity || old.color != color;
}

class _StarBurstPainter extends CustomPainter {
  const _StarBurstPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55 * progress * (1 - progress) * 4)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const rays = 12;
    final inner = 92 + (progress * 26);
    final outer = inner + 28 + (progress * 18);
    for (var i = 0; i < rays; i++) {
      final theta = (i / rays) * 2 * math.pi;
      final from = Offset(
        center.dx + math.cos(theta) * inner,
        center.dy + math.sin(theta) * inner,
      );
      final to = Offset(
        center.dx + math.cos(theta) * outer,
        center.dy + math.sin(theta) * outer,
      );
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarBurstPainter old) =>
      old.progress != progress;
}

class _ScoreArcPainter extends CustomPainter {
  const _ScoreArcPainter({
    required this.progress,
    required this.color,
    required this.opacity,
  });
  final double progress;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - 10) / 2,
    );
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.07 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final fg = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: opacity),
          color.withValues(alpha: opacity * 0.9),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      fg,
    );
    // End-of-arc glow dot
    if (progress > 0.02) {
      final theta = -math.pi / 2 + 2 * math.pi * progress;
      final dot = Offset(
        size.width / 2 + rect.width / 2 * math.cos(theta),
        size.height / 2 + rect.height / 2 * math.sin(theta),
      );
      final dotGlow = Paint()
        ..color = color.withValues(alpha: 0.55 * opacity);
      canvas.drawCircle(dot, 9, dotGlow);
      final dotCore = Paint()..color = color.withValues(alpha: opacity);
      canvas.drawCircle(dot, 4, dotCore);
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreArcPainter old) =>
      old.progress != progress ||
      old.opacity != opacity ||
      old.color != color;
}

// ─── PRAISE TYPEWRITER: word-by-word reveal + underline trace ───
class _PraiseTypewriter extends StatelessWidget {
  const _PraiseTypewriter({
    required this.text,
    required this.progress,
    required this.underlineProgress,
  });

  final String text;
  final double progress;
  final double underlineProgress;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final words = text.split(' ');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DefaultTextStyle(
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 19,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              height: 1.5,
              letterSpacing: -0.3,
              color: c.invInk,
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: [
                for (var i = 0; i < words.length; i++)
                  _WordCell(
                    word: words[i],
                    activate:
                        ((progress * words.length) - i).clamp(0.0, 1.0),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CustomPaint(
            size: const Size(140, 2),
            painter: _UnderlinePainter(
              progress: underlineProgress,
              color: c.yellow,
            ),
          ),
        ],
      ),
    );
  }
}

class _WordCell extends StatelessWidget {
  const _WordCell({required this.word, required this.activate});
  final String word;
  final double activate;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(activate.clamp(0.0, 1.0));
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 8),
        child: Text(word),
      ),
    );
  }
}

class _UnderlinePainter extends CustomPainter {
  const _UnderlinePainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final half = size.width / 2;
    final reach = half * progress.clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    canvas.drawLine(Offset(half - reach, y), Offset(half + reach, y), paint);
    // Soft glow
    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(half - reach, y), Offset(half + reach, y), glow);
  }

  @override
  bool shouldRepaint(covariant _UnderlinePainter old) =>
      old.progress != progress || old.color != color;
}

// ─── NEXT BANNER: bottom eyebrow "BÀI TIẾP THEO · X" with chevrons ───
class _NextBanner extends StatelessWidget {
  const _NextBanner({required this.text, required this.opacity});
  final String text;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final parts = text.toUpperCase().split(' · ');
    final eyebrow = parts.length > 1 ? parts.first : 'BÀI TIẾP THEO';
    final headline =
        parts.length > 1 ? parts.sublist(1).join(' · ') : parts.first;
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, (1 - opacity) * 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              eyebrow,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
                color: c.invInkFaint,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ChevronStrip(opacity: opacity),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.8,
                      color: c.invInk,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _ChevronStrip(opacity: opacity, reverse: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChevronStrip extends StatelessWidget {
  const _ChevronStrip({required this.opacity, this.reverse = false});
  final double opacity;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final icon = reverse
        ? Icons.chevron_left_rounded
        : Icons.chevron_right_rounded;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            icon,
            size: 18,
            color: c.yellow.withValues(alpha: (0.25 + i * 0.25) * opacity),
          ),
      ],
    );
  }
}

// ─── PROGRESS TICKER: thin yellow bar at the bottom ───
class _ProgressTicker extends StatelessWidget {
  const _ProgressTicker({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Center(
      child: Container(
        width: 160,
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(2),
        ),
        child: AnimatedBuilder(
          animation: animation,
          builder: (_, __) {
            return FractionallySizedBox(
              widthFactor: animation.value,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: c.yellow,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(color: c.yellow, blurRadius: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
