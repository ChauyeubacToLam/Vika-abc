// The 5-second cinematic moment between exercises. Designed to be
// visible (and impressive) from across the room — the user just finished
// their last rep and put the phone down a few meters away. Big score,
// big motion, big restraint. No sentences: the screen is a glanceable
// reward, readable from several meters.
//
// Choreography (5000ms total):
//   0   →  800  : backdrop in, vignette tightens, ember particles rise,
//                 atmospheric glows fade up
//   400 → 2400  : score reveal — 3 concentric rings pulse outward,
//                 score digit ticker counts up (eased), arc traces around it.
//                 The numeral / arc / glow / rings all take the performance
//                 BAND color (gold → amber → burnt orange) for instant read.
//   2000 → 2800 : star burst flares; ray count + reach scale with the
//                 clean-rep ratio of the whole exercise
//   2100 → 3700 : effort replay — each set's work ignites left→right, set by
//                 set, as a ~1.6s replay. Rep-based exercises show clean reps
//                 as glowing gold discs and faulted reps as hollow orange
//                 rings (the active-screen rep-tally fault encoding).
//                 Time-based exercises (isSecondBased) instead replay each
//                 timed HOLD as a stadium bar that sweeps full like a
//                 stopwatch — clean holds fill gold, faulted holds fill orange.
//   3000 → 4500 : "BÀI TIẾP THEO · X" eyebrow lifts; chevron pulse
//   4500 → 5000 : glide out (translate up + fade)
//
// Visual elements (all painted, no assets):
//   • Warm-dark gradient + radial yellow + amber atmospheric stack
//   • Vignette
//   • Drifting ember particles (count + brightness scale with clean ratio)
//   • 3 concentric rings pulsing on a 1400ms loop (band-colored)
//   • Band-colored score arc growing 0 → progress
//   • Star burst flaring out at score completion (intensity = clean ratio)
//   • Per-set rep-orb replay field (clean = lit gold disc, fault = orange ring)
//   • Yellow corner ray accents (4 corners)
//   • Bottom progress ticker
//
// Auto-advances via [onComplete] at [totalDurationMs].

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../models/post_exercise_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

/// Performance bands, mirroring the active-screen `LiveFormScoreArc`:
///   ≥ 80  gold (reserved yellow — the score is a "stat" usage)
///   60–79 warm amber
///   < 60  burnt orange ("needs work")
/// Fixed values so the read is identical regardless of platform brightness
/// (this screen is always a dark cinematic stage).
Color _scoreBandColor(int score, VikaColors c) {
  if (score >= 80) return c.yellow; // #FFB701
  if (score >= 60) return const Color(0xFFE89A4B);
  return const Color(0xFFD67B3E);
}

class ExerciseTransitionMoment extends StatefulWidget {
  const ExerciseTransitionMoment({
    super.key,
    required this.exerciseName,
    required this.formScore,
    required this.setResults,
    required this.nextExerciseName,
    required this.onComplete,
    this.timeBased = false,
    this.totalDurationMs = 5000,
  });

  final String exerciseName;
  final int formScore;

  /// Per-set results for this exercise. Each [SetReportData.repResults] is a
  /// `List<bool>` — for rep-based exercises one entry per rep (true = clean),
  /// for time-based exercises one entry per timed hold (true = good form).
  /// Drives the effort-replay field and the celebration intensity.
  final List<SetReportData> setResults;

  /// True for time-under-tension exercises (plank, warrior hold, …), carried
  /// from [PostExerciseData.isSecondBased]. Swaps the rep-orb field for the
  /// timed-hold bar replay.
  final bool timeBased;

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
  late final Animation<double> _enter; // 0.00 → 0.16
  late final Animation<double> _scoreCount; // 0.08 → 0.48
  late final Animation<double> _starBurst; // 0.40 → 0.56
  late final Animation<double> _repReplay; // 0.42 → 0.74 (~1.6s)
  late final Animation<double> _nextIn; // 0.60 → 0.90
  late final Animation<double> _exit; // 0.90 → 1.00

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
    _repReplay = _slice(0.42, 0.74, Curves.easeInOut);
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

  /// Performance ratio (0..1) that scales the celebration — star-burst reach
  /// + ray count and ember intensity. The displayed [formScore] already
  /// encodes the right metric for each exercise type (good/total reps, or
  /// good/total seconds for time-based), so one expression covers both.
  double get _celebration => (widget.formScore / 100.0).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final band = _scoreBandColor(widget.formScore, c);
    final celebration = _celebration;
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
                          intensity: celebration,
                        ),
                      ),
                      CustomPaint(
                        painter:
                            _CornerRaysPainter(opacity: _enter.value * 0.65),
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
                              const SizedBox(height: 26),
                              _ScoreMonument(
                                targetScore: widget.formScore,
                                countProgress: _scoreCount.value,
                                ringPulse: _ringPulse.value,
                                starBurst: _starBurst.value,
                                bandColor: band,
                                celebration: celebration,
                              ),
                              const SizedBox(height: 30),
                              if (widget.timeBased)
                                _HoldReplayField(
                                  sets: widget.setResults,
                                  replay: _repReplay.value,
                                  cleanColor: c.yellow,
                                  faultColor: c.attention,
                                )
                              else
                                _RepReplayField(
                                  sets: widget.setResults,
                                  replay: _repReplay.value,
                                  cleanColor: c.yellow,
                                  faultColor: c.attention,
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

// ─── EMBERS: deterministic particles drifting upward. Count + brightness
//     scale with the clean-rep ratio (a cleaner set burns brighter). ───
class _EmbersPainter extends CustomPainter {
  const _EmbersPainter({
    required this.progress,
    required this.opacity,
    required this.intensity,
  });
  final double progress;
  final double opacity;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final rng = math.Random(91021);
    final yellow = const Color(0xFFFFB701);
    final amber = const Color(0xFFCD7C45);
    final paint = Paint();
    final count = 8 + (intensity * 12).round(); // 8 → 20
    for (var i = 0; i < count; i++) {
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
          (0.30 + rng.nextDouble() * 0.45) *
          (0.55 + 0.45 * intensity);
      paint.color = (i % 3 == 0 ? amber : yellow).withValues(alpha: alpha);
      canvas.drawCircle(Offset(dx, dy), r, paint);
      paint.color =
          (i % 3 == 0 ? amber : yellow).withValues(alpha: alpha * 0.16);
      canvas.drawCircle(Offset(dx, dy), r * 6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmbersPainter old) =>
      old.progress != progress ||
      old.opacity != opacity ||
      old.intensity != intensity;
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
    canvas.drawLine(
        Offset(size.width - 28, 28), Offset(size.width - 28, 64), p);
    canvas.drawLine(
        Offset(size.width - 28, 28), Offset(size.width - 64, 28), p);
    // Bottom-left
    canvas.drawLine(
        Offset(28, size.height - 28), Offset(28, size.height - 64), p);
    canvas.drawLine(
        Offset(28, size.height - 28), Offset(64, size.height - 28), p);
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
    required this.bandColor,
    required this.celebration,
  });

  final int targetScore;
  final double countProgress;
  final double ringPulse;
  final double starBurst;
  final Color bandColor;
  final double celebration;

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
              color: bandColor,
            ),
          ),
          // Star burst (peaks at starBurst.value; reach scales with clean ratio)
          CustomPaint(
            size: const Size(320, 320),
            painter: _StarBurstPainter(
              progress: starBurst,
              color: bandColor,
              intensity: celebration,
            ),
          ),
          // Focus pedestal: a soft dark disc + faint band halo directly behind
          // the numeral so the score lifts off the busy backdrop and reads
          // cleanly from a distance.
          Center(
            child: Container(
              width: 232,
              height: 232,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.24 * ringOpacity),
                    bandColor.withValues(alpha: 0.05 * ringOpacity),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.62, 1.0],
                ),
              ),
            ),
          ),
          // Band-colored score arc
          Transform.scale(
            scale: introScale,
            child: SizedBox(
              width: 240,
              height: 240,
              child: CustomPaint(
                painter: _ScoreArcPainter(
                  progress: countProgress,
                  color: bandColor,
                  opacity: ringOpacity,
                ),
              ),
            ),
          ),
          // Score numeral + scale tick
          Transform.scale(
            scale: introScale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Constrained to an inscribed width well inside the 240 arc,
                // so even a 3-digit "100" keeps a clear margin to the ring.
                // FittedBox then scales down only on the rare wide value or a
                // very small phone (e.g. iPhone SE 320pt-wide).
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 158),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      display.toString(),
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 112,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -5,
                        height: 0.9,
                        color: bandColor,
                        fontFeatures: VikaIvoryMain.tabularFigures,
                        shadows: [
                          Shadow(
                            color: bandColor.withValues(
                                alpha: 0.45 * ringOpacity),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 16,
                      height: 1,
                      color: c.invInkFaint,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '/ 100',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.2,
                        color: c.invInkSoft,
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      width: 16,
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
  const _StarBurstPainter({
    required this.progress,
    required this.color,
    required this.intensity,
  });
  final double progress;
  final Color color;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);
    final baseAlpha = 0.35 + 0.65 * intensity;
    final paint = Paint()
      ..color =
          color.withValues(alpha: baseAlpha * progress * (1 - progress) * 4)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final rays = 8 + (intensity * 10).round(); // 8 → 18
    final inner = 92 + (progress * 26);
    final outer = inner + 28 + (progress * 18) + intensity * 16;
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
      old.progress != progress ||
      old.intensity != intensity ||
      old.color != color;
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
      final dotGlow = Paint()..color = color.withValues(alpha: 0.55 * opacity);
      canvas.drawCircle(dot, 9, dotGlow);
      final dotCore = Paint()..color = color.withValues(alpha: opacity);
      canvas.drawCircle(dot, 4, dotCore);
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreArcPainter old) =>
      old.progress != progress || old.opacity != opacity || old.color != color;
}

// ─── REP REPLAY FIELD: one row of orbs per set, igniting set-by-set ───
//
// Each set's reps light up left→right within its slice of the replay window,
// and the sets fire in order — a ~1.6s replay of the effort. Clean reps are
// lit gold discs; faulted reps are hollow orange rings (the active-screen
// rep-tally fault encoding, scaled up for across-the-room legibility).
class _RepReplayField extends StatelessWidget {
  const _RepReplayField({
    required this.sets,
    required this.replay,
    required this.cleanColor,
    required this.faultColor,
  });

  final List<SetReportData> sets;
  final double replay;
  final Color cleanColor;
  final Color faultColor;

  @override
  Widget build(BuildContext context) {
    final n = sets.length;
    if (n == 0) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(height: 15),
          _SetRepRow(
            results: sets[i].repResults,
            // Set i owns the window [i/n, (i+1)/n] of the replay.
            setProgress: ((replay * n) - i).clamp(0.0, 1.0),
            cleanColor: cleanColor,
            faultColor: faultColor,
          ),
        ],
      ],
    );
  }
}

class _SetRepRow extends StatelessWidget {
  const _SetRepRow({
    required this.results,
    required this.setProgress,
    required this.cleanColor,
    required this.faultColor,
  });

  final List<bool> results;
  final double setProgress;
  final Color cleanColor;
  final Color faultColor;

  @override
  Widget build(BuildContext context) {
    final n = results.length;
    if (n == 0) return const SizedBox.shrink();
    // Most exercises (squat/lunge/push-up: 6–8 reps) sit comfortably at full
    // size; high-rep sets (e.g. jumping jacks) scale down to stay one line.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < n; r++) ...[
              if (r > 0) const SizedBox(width: 7),
              _RepOrb(
                clean: results[r],
                // Stagger reps left→right; the (+1) leaves a beat before the
                // set's window closes so the last orb fully settles.
                ignite: ((setProgress * (n + 1)) - r).clamp(0.0, 1.0),
                cleanColor: cleanColor,
                faultColor: faultColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RepOrb extends StatelessWidget {
  const _RepOrb({
    required this.clean,
    required this.ignite,
    required this.cleanColor,
    required this.faultColor,
  });

  final bool clean;
  final double ignite;
  final Color cleanColor;
  final Color faultColor;

  static const double _slot = 15;

  @override
  Widget build(BuildContext context) {
    final e = ignite.clamp(0.0, 1.0);
    final fade = Curves.easeOutCubic.transform(e);
    final pop = Curves.easeOutBack.transform(e);
    final color = clean ? cleanColor : faultColor;
    return SizedBox(
      width: _slot,
      height: _slot,
      child: Center(
        child: Opacity(
          opacity: fade,
          child: Transform.scale(
            scale: 0.5 + 0.5 * pop,
            child: Container(
              width: _slot,
              height: _slot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: clean ? color : color.withValues(alpha: 0.14),
                border:
                    clean ? null : Border.all(color: color, width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: (clean ? 0.55 : 0.32) * e),
                    blurRadius: clean ? 11 : 7,
                  ),
                ],
              ),
              // Faulted orbs keep a dim core so the ring reads as "missed",
              // not "empty", from a distance.
              child: clean
                  ? null
                  : Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── HOLD REPLAY FIELD: time-based counterpart of the rep-orb field ───
//
// Each timed HOLD is a stadium bar that sweeps full left→right like a
// stopwatch, set by set, over the same ~1.6s replay window. Clean holds fill
// gold (with a leading comet + glow); faulted holds fill orange. The number
// of bars in a row is the set's hold count, so a longer row reads as more
// time under tension from across the room.
class _HoldReplayField extends StatelessWidget {
  const _HoldReplayField({
    required this.sets,
    required this.replay,
    required this.cleanColor,
    required this.faultColor,
  });

  final List<SetReportData> sets;
  final double replay;
  final Color cleanColor;
  final Color faultColor;

  @override
  Widget build(BuildContext context) {
    final n = sets.length;
    if (n == 0) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(height: 15),
          _HoldSetRow(
            results: sets[i].repResults,
            // Set i owns the window [i/n, (i+1)/n] of the replay.
            setProgress: ((replay * n) - i).clamp(0.0, 1.0),
            cleanColor: cleanColor,
            faultColor: faultColor,
          ),
        ],
      ],
    );
  }
}

class _HoldSetRow extends StatelessWidget {
  const _HoldSetRow({
    required this.results,
    required this.setProgress,
    required this.cleanColor,
    required this.faultColor,
  });

  final List<bool> results;
  final double setProgress;
  final Color cleanColor;
  final Color faultColor;

  @override
  Widget build(BuildContext context) {
    final n = results.length;
    if (n == 0) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var h = 0; h < n; h++) ...[
              if (h > 0) const SizedBox(width: 8),
              _HoldBar(
                clean: results[h],
                // Holds sweep in sequence; the (+1) leaves a beat before the
                // set's window closes so the last bar settles full.
                fill: ((setProgress * (n + 1)) - h).clamp(0.0, 1.0),
                cleanColor: cleanColor,
                faultColor: faultColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HoldBar extends StatelessWidget {
  const _HoldBar({
    required this.clean,
    required this.fill,
    required this.cleanColor,
    required this.faultColor,
  });

  final bool clean;
  final double fill;
  final Color cleanColor;
  final Color faultColor;

  static const double _w = 46;
  static const double _h = 13;

  @override
  Widget build(BuildContext context) {
    final f = fill.clamp(0.0, 1.0);
    // Fade the bar in quickly as its slot opens, then sweep the fill.
    final appear = Curves.easeOut.transform((f * 5).clamp(0.0, 1.0));
    final swept = Curves.easeInOutCubic.transform(f);
    return Opacity(
      opacity: appear,
      child: CustomPaint(
        size: const Size(_w, _h),
        painter: _HoldBarPainter(
          clean: clean,
          fill: swept,
          color: clean ? cleanColor : faultColor,
        ),
      ),
    );
  }
}

class _HoldBarPainter extends CustomPainter {
  const _HoldBarPainter({
    required this.clean,
    required this.fill,
    required this.color,
  });

  final bool clean;
  final double fill;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final r = Radius.circular(h / 2);
    final trackRRect = RRect.fromRectAndRadius(Offset.zero & size, r);

    // Dim track in the bar's own hue.
    canvas.drawRRect(trackRRect, Paint()..color = color.withValues(alpha: 0.16));

    final fillLen = (w * fill).clamp(0.0, w);
    if (fillLen <= 0) return;

    // Soft glow under a clean (gold) fill so good holds bloom.
    if (clean) {
      final glow = Paint()
        ..color = color.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, fillLen, h), r),
        glow,
      );
    }

    // Clip to the stadium so the sweeping fill keeps rounded caps.
    canvas.save();
    canvas.clipRRect(trackRRect);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, fillLen, h),
      Paint()..color = color.withValues(alpha: clean ? 1.0 : 0.92),
    );
    canvas.restore();

    // Leading "comet" while the bar is still filling — the stopwatch tell.
    if (fill > 0.02 && fill < 0.99) {
      final center = Offset(fillLen, h / 2);
      canvas.drawCircle(
        center,
        h * 0.6,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(center, h * 0.34, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _HoldBarPainter old) =>
      old.fill != fill || old.clean != clean || old.color != color;
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
    final icon =
        reverse ? Icons.chevron_left_rounded : Icons.chevron_right_rounded;
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
