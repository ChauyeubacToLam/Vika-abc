// WorkoutSummaryScreen — "Cuốn Phim Form" (The Form Reel).
//
// A world-class finale rebuilt as ONE continuous warm-dark "reel of light",
// not six disconnected cards. The whole session is drawn as a single
// band-colored RIDGELINE built from every set's form score — the mountain
// you climbed IS the screen. The reel then curves into cream for the close,
// the only color transition (house lights coming up).
//
// Reel (top → bottom), all on one dark surface until the cream close:
//   1. Marquee        — wordmark + band-aware headline + the STARRING score
//   2. Ridgeline      — one polyline of every report.sets[].score + vital strip
//   3. Trophy billing — the earned highlight, billed like a lead film credit
//   4. Coach note     — AI pull-quote + two editorial labeled rows
//   5. Cast credits   — per-exercise indexed credits list (replaces the grid)
//   6. Lights-up close— dark→cream curve, share links, yellow Done CTA
//
// This is a pure reward screen — the difficulty popup fires on entry via
// _promptThenReveal() and the reveal cascade only plays once it resolves,
// so nothing animates behind the barrier.
//
// All values use Premium Ivory tokens via VikaColors. Reserved yellow is
// held to four uses: the sparkle dot, the score stat (gold band only), the
// coach underline, and the Done CTA. No emojis. Band thresholds (>=80 gold /
// 60-79 amber / <60 burnt) are the one evaluative signal.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/workout_session_report.dart';
import '../../services/session_summary_builder.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../../widgets/exercise/previous_exercise_rating_dialog.dart';
import '../../services/session_trophy_picker.dart';
import '../../services/session_coach_builder.dart';

/// Performance bands (mirrors the live form arc + transition monument):
/// >=80 gold (reserved yellow), 60-79 warm amber, <60 burnt orange. The ONE
/// evaluative color signal across the whole screen.
Color _bandColor(int score, Color yellow) {
  if (score >= 80) return yellow;
  if (score >= 60) return const Color(0xFFE89A4B);
  return const Color(0xFFD67B3E);
}

String _fmtClock(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String _fmtSeconds(double seconds) {
  final r = seconds.round();
  if (r < 60) return '${r}s';
  final m = r ~/ 60;
  final rem = r % 60;
  return rem == 0 ? '${m}m' : '${m}m ${rem}s';
}

String _formatReportWork(ExerciseSessionReport report) {
  if (report.report.isSecondBased) {
    final good = report.report.goodSeconds ?? 0;
    final total = report.report.totalSeconds ?? 0;
    return '${_fmtSeconds(good)}/${_fmtSeconds(total)}';
  }
  return '${report.goodReps ?? 0}/${report.totalReps ?? 0} rep';
}

class WorkoutSummaryScreen extends StatefulWidget {
  const WorkoutSummaryScreen({
    super.key,
    required this.reports,
    required this.sessionSummary,
    required this.totalDuration,
    required this.totalCalories,
    required this.onDone,
    required this.trophy,
    required this.coach,
    this.onShare,
    this.onShareToZalo,
    this.onLastExerciseDifficulty,
    this.onSessionRpe,
  });

  final List<ExerciseSessionReport> reports;
  final SessionSummary sessionSummary;
  final Duration totalDuration;
  final int totalCalories;
  final VoidCallback onDone;
  final VoidCallback? onShare;
  final VoidCallback? onShareToZalo;
  final ValueChanged<String>? onLastExerciseDifficulty;
  final Trophy trophy;
  final SessionCoach coach;

  // TODO(wiring): RPE is removed from the summary UI pending a separate
  // decision. This param is intentionally retained but currently unused; do
  // not wire it until that decision lands.
  final ValueChanged<String>? onSessionRpe;

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _shimmer;
  late final AnimationController _heroPulse;

  late final Animation<double> _b0;
  late final Animation<double> _b1;
  late final Animation<double> _b2;
  late final Animation<double> _b3;
  late final Animation<double> _b4;
  late final Animation<double> _b5;
  late final Animation<double> _b6;

  /// Drives BOTH the marquee score count-up AND the ridgeline draw-on, so the
  /// pen and the number always land on the same frame. Gated behind [_entry]
  /// so the climb plays when the celebration lands, not behind the popup.
  late final Animation<double> _heroClimb;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _heroPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    // Seven beats mapped to the reel's strata: marquee top, marquee score,
    // ridgeline, trophy, coach, credits, close.
    _b0 = _beat(0.00, 0.20);
    _b1 = _beat(0.10, 0.40);
    _b2 = _beat(0.22, 0.52);
    _b3 = _beat(0.40, 0.66);
    _b4 = _beat(0.50, 0.76);
    _b5 = _beat(0.60, 0.88);
    _b6 = _beat(0.72, 1.0);

    _heroClimb = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.12, 0.97, curve: Curves.linear),
    );

    // Gate the celebration: fire the post-exercise reflection popup for the
    // last exercise on entry, then play the reveal once it resolves. The dark
    // popup barrier covers the un-revealed (opacity-0) reel behind it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptThenReveal());
  }

  Future<void> _promptThenReveal() async {
    if (!mounted) return;
    final reports = widget.reports;
    if (reports.isNotEmpty && reports.last.userDifficulty == null) {
      final last = reports.last;
      final difficulty = await showPreviousExerciseRatingDialog(
        context,
        exerciseName: last.exerciseName,
        formScore: last.formScore,
        issueQuestion: last.report.issueQuestion,
      );
      if (!mounted) return;
      last.userDifficulty = difficulty;
      widget.onLastExerciseDifficulty?.call(difficulty);
    }
    if (mounted) _entry.forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    _shimmer.dispose();
    _heroPulse.dispose();
    super.dispose();
  }

  Animation<double> _beat(double a, double b) => CurvedAnimation(
        parent: _entry,
        curve: Interval(a, b, curve: Curves.easeOutCubic),
      );

  // ── Session aggregates ────────────────────────────────────────
  int get _totalSets =>
      widget.reports.fold<int>(0, (s, r) => s + r.report.sets.length);

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);

    // Clamp accessibility text scaling so the 132pt starring numeral and the
    // tabular figures can't overflow at maxed-out system text.
    final mq = MediaQuery.of(context);
    final clampedScaler = mq.textScaler.clamp(
      minScaleFactor: 0.92,
      maxScaleFactor: 1.15,
    );
    final maxWidth = mq.size.width > 640.0 ? 640.0 : mq.size.width;
    final topInset = mq.viewPadding.top;
    final bottomInset = mq.viewPadding.bottom;

    return MediaQuery(
      data: mq.copyWith(textScaler: clampedScaler),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: c.bg,
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildReel(c, topInset),
                    // The cream close rises into the dark reel: a 36pt
                    // rounded-top curve pulled up over the reel's bottom edge
                    // reveals the dark behind its corners — the signature
                    // stage-hero curve, inverted (house lights up).
                    Transform.translate(
                      offset: const Offset(0, -36),
                      child: _LightsUpClose(
                        beat: _b6,
                        shimmer: _shimmer,
                        bottomInset: bottomInset,
                        onDone: widget.onDone,
                        onShare: widget.onShare ?? () => _stub('Chia sẻ'),
                        onShareToZalo:
                            widget.onShareToZalo ?? () => _stub('Zalo'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── The continuous warm-dark reel: one surface behind sections 1-5 ──
  Widget _buildReel(VikaColors c, double topInset) {
    final summary = widget.sessionSummary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.8, -1),
          end: const Alignment(0.8, 1),
          colors: [c.bgInverse, c.bgInverseHi],
        ),
      ),
      child: Stack(
        children: [
          // Breathing yellow ambient glow, top-right.
          Positioned(
            top: -120,
            right: -100,
            child: AnimatedBuilder(
              animation: _heroPulse,
              builder: (context, _) => IgnorePointer(
                child: Opacity(
                  opacity: 0.55 + (_heroPulse.value * 0.25),
                  child: SizedBox(
                    width: 440,
                    height: 440,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            c.yellow.withValues(alpha: 0.20),
                            c.yellow.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Amber bloom, bottom-left.
          const Positioned(
            bottom: -200,
            left: -140,
            child: IgnorePointer(
              child: SizedBox(
                width: 440,
                height: 380,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0x44CD7C45), Color(0x00CD7C45)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Deterministic film grain over the whole reel (never time-based).
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _HeroGrainPainter()),
            ),
          ),
          // Two quiet sparkle dots.
          Positioned(
            top: topInset + 120,
            left: 26,
            child: _Sparkle(color: c.yellow, size: 3),
          ),
          Positioned(
            top: topInset + 330,
            right: 40,
            child: _Sparkle(color: c.yellow, size: 2),
          ),
          // Foreground content column.
          Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BeatReveal(
                  animation: _b0,
                  child: _Marquee(
                    sessionFormScore: summary.sessionFormScore,
                    streakBonus: summary.streakBonus,
                    streakDays: summary.streakDays,
                    exerciseCount: widget.reports.length,
                    totalDuration: widget.totalDuration,
                    climb: _heroClimb,
                    headlineBeat: _b1,
                  ),
                ),
                const SizedBox(height: 26),
                _BeatReveal(
                  animation: _b2,
                  child: _RidgeSection(
                    reports: widget.reports,
                    totalSets: _totalSets,
                    climb: _heroClimb,
                    sessionFormScore: summary.sessionFormScore,
                    totalDuration: widget.totalDuration,
                    totalCalories: widget.totalCalories,
                  ),
                ),
                const SizedBox(height: 30),
                _BeatReveal(
                  animation: _b3,
                  child: _TrophyBilling(trophy: widget.trophy),
                ),
                const SizedBox(height: 30),
                _BeatReveal(
                  animation: _b4,
                  child: _CoachNote(coach: widget.coach),
                ),
                const SizedBox(height: 30),
                _BeatReveal(
                  animation: _b5,
                  child: _CreditsList(reports: widget.reports),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _stub(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label sẽ được bật ở bản sau.')),
    );
  }
}

// ─── Beat reveal — fade + 20px rise ───
class _BeatReveal extends StatelessWidget {
  const _BeatReveal({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, child) {
        final v = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 20),
            child: child,
          ),
        );
      },
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MARQUEE — title card. Wordmark + meta, sparkle eyebrow, band-aware
// verdict headline, then the STARRING session score (band-colored,
// count-up, /105 superscript). No box — type floating on the reel.
// ═══════════════════════════════════════════════════════════════

class _Marquee extends StatelessWidget {
  const _Marquee({
    required this.sessionFormScore,
    required this.streakBonus,
    required this.streakDays,
    required this.exerciseCount,
    required this.totalDuration,
    required this.climb,
    required this.headlineBeat,
  });

  final int sessionFormScore;
  final int streakBonus;
  final int streakDays;
  final int exerciseCount;
  final Duration totalDuration;
  final Animation<double> climb;
  final Animation<double> headlineBeat;

  String get _headline => sessionFormScore >= 80
      ? 'Form đỉnh.'
      : sessionFormScore >= 60
          ? 'Form chắc.'
          : 'Buổi đặt nền.';

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final hasBonus = streakBonus > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wordmark + hairline meta
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'VIKA',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: -1,
                color: c.invInk,
              ),
            ),
            const Spacer(),
            Text(
              '$exerciseCount BÀI · ${_fmtClock(totalDuration)}',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: c.invInkFaint,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        // Sparkle eyebrow
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: c.yellow,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: c.yellow, blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'TỔNG KẾT BUỔI TẬP',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: c.invInkFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Band-aware verdict headline
        Text(
          _headline,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 44,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            height: 0.96,
            letterSpacing: -2.4,
            color: c.invInk,
          ),
        ),
        const SizedBox(height: 22),
        // Score block gets its own staged reveal (the second marquee beat).
        _BeatReveal(
          animation: headlineBeat,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Starring score eyebrow
              Text(
                'BUỔI NÀY',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                  color: c.invInkFaint,
                ),
              ),
              const SizedBox(height: 6),
              // Starring numeral — counts up + inks to band color on the climb.
              AnimatedBuilder(
                animation: climb,
                builder: (context, _) {
            final v = climb.value.clamp(0.0, 1.0);
            // Count up from 0 → sessionFormScore on every session; the climb
            // naturally passes through the raw score, with any streak bonus
            // landing as the final few digits + the caption reveal below.
            final eased = Curves.easeOutCubic.transform(v);
            final display = (sessionFormScore * eased).round();
            final band = _bandColor(sessionFormScore, c.yellow);
            // "print strike": ink from soft-invInk to full band over the climb.
            final inkProg = ((v - 0.4) / 0.6).clamp(0.0, 1.0);
            final numeralColor = Color.lerp(
              c.invInk.withValues(alpha: 0.85),
              band,
              inkProg,
            )!;
            final bonusReveal =
                hasBonus ? ((v - 0.68) / 0.32).clamp(0.0, 1.0) : 0.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$display',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 132,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -8,
                              height: 0.85,
                              color: numeralColor,
                              fontFeatures: VikaIvoryMain.tabularFigures,
                              shadows: [
                                Shadow(
                                  color: band.withValues(
                                      alpha: 0.35 * inkProg),
                                  blurRadius: 36,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        '/105',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.5,
                          color: c.invInkFaint,
                          fontFeatures: VikaIvoryMain.tabularFigures,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasBonus) ...[
                  const SizedBox(height: 10),
                  Opacity(
                    opacity: bonusReveal,
                    child: Row(
                      children: [
                        Container(
                          width: 24 * bonusReveal,
                          height: 2,
                          decoration: BoxDecoration(
                            color: band,
                            borderRadius: BorderRadius.circular(1),
                            boxShadow: [
                              BoxShadow(
                                color: band.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '+$streakBonus chuỗi · $streakDays ngày',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.1,
                            color: c.invInkSoft,
                            fontFeatures: VikaIvoryMain.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// RIDGELINE — the unification. One band-colored polyline built from
// every set's form score concatenated across exercises, with set-node
// rings, per-exercise boundary ticks + labels, and a glowing summit.
// Below: a hairline-divided vital strip.
// ═══════════════════════════════════════════════════════════════

class _RidgeSection extends StatelessWidget {
  const _RidgeSection({
    required this.reports,
    required this.totalSets,
    required this.climb,
    required this.sessionFormScore,
    required this.totalDuration,
    required this.totalCalories,
  });

  final List<ExerciseSessionReport> reports;
  final int totalSets;
  final Animation<double> climb;
  final int sessionFormScore;
  final Duration totalDuration;
  final int totalCalories;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section eyebrow
        Row(
          children: [
            Flexible(
              child: Text(
                'ĐƯỜNG FORM CẢ BUỔI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: c.invInkFaint,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$totalSets HIỆP',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: c.invInkFaint,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: AnimatedBuilder(
            animation: climb,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _RidgelinePainter(
                  reports: reports,
                  progress: climb.value,
                  yellow: c.yellow,
                  invInk: c.invInk,
                  invInkSoft: c.invInkSoft,
                  invInkFaint: c.invInkFaint,
                  sessionBand: _bandColor(sessionFormScore, c.yellow),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          padding: const EdgeInsets.only(top: 14),
          child: _VitalStrip(
            reports: reports,
            totalDuration: totalDuration,
            totalCalories: totalCalories,
          ),
        ),
      ],
    );
  }
}

class _RidgelinePainter extends CustomPainter {
  _RidgelinePainter({
    required this.reports,
    required this.progress,
    required this.yellow,
    required this.invInk,
    required this.invInkSoft,
    required this.invInkFaint,
    required this.sessionBand,
  });

  final List<ExerciseSessionReport> reports;
  final double progress;
  final Color yellow;
  final Color invInk;
  final Color invInkSoft;
  final Color invInkFaint;
  final Color sessionBand;

  @override
  void paint(Canvas canvas, Size size) {
    // Concatenate every set's score across exercises, tracking boundaries.
    final scores = <int>[];
    final boundaryStart = <int>[]; // first vertex index of each exercise
    final names = <String>[];
    for (final r in reports) {
      final s = r.report.sets.map((e) => e.score).toList();
      if (s.isEmpty) continue;
      boundaryStart.add(scores.length);
      names.add(r.exerciseName);
      scores.addAll(s);
    }
    if (scores.isEmpty) return;

    const padX = 26.0;
    const padTop = 22.0;
    const padBottom = 26.0;
    final bottomY = size.height - padBottom;
    final usableH = size.height - padTop - padBottom;
    double yFor(num s) => bottomY - (s.clamp(0, 100) / 100) * usableH;

    // ── Guide grid (full width, ahead of the pen) ──
    final grid = Paint()
      ..color = invInkFaint.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(padX, bottomY), Offset(size.width - padX, bottomY),
        grid..color = invInkFaint.withValues(alpha: 0.22));
    for (final v in [50, 100]) {
      final y = yFor(v);
      const dash = 4.0, gap = 5.0;
      double x = padX;
      while (x < size.width - padX) {
        final next = math.min(x + dash, size.width - padX);
        canvas.drawLine(Offset(x, y), Offset(next, y),
            grid..color = invInkFaint.withValues(alpha: 0.16));
        x = next + gap;
      }
      _label(canvas, '$v', Offset(2, y),
          TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: invInkFaint,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
          anchor: _Anchor.midLeft);
    }

    // ── Build the vertex polyline. N==1 → a centered crest. ──
    final List<Offset> pts;
    final bool singleCrest = scores.length == 1;
    if (singleCrest) {
      final cx = size.width / 2;
      final spread = math.min(size.width * 0.22, 90.0);
      final footY = bottomY - usableH * 0.06;
      pts = [
        Offset(cx - spread, footY),
        Offset(cx, yFor(scores[0])),
        Offset(cx + spread, footY),
      ];
    } else {
      final stepX = (size.width - padX * 2) / (scores.length - 1);
      pts = [
        for (var i = 0; i < scores.length; i++)
          Offset(padX + stepX * i, yFor(scores[i])),
      ];
    }

    // Pen position by arc-length, so fill + line reveal together.
    final segLens = <double>[];
    var totalLen = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final l = (pts[i + 1] - pts[i]).distance;
      segLens.add(l);
      totalLen += l;
    }
    final target = totalLen * progress.clamp(0.0, 1.0);
    var walked = 0.0;
    var penX = pts.first.dx;
    for (var i = 0; i < pts.length - 1; i++) {
      final l = segLens[i];
      if (walked + l <= target) {
        penX = pts[i + 1].dx;
      } else {
        final f = l == 0 ? 0.0 : (target - walked) / l;
        penX = pts[i].dx + (pts[i + 1].dx - pts[i].dx) * f.clamp(0.0, 1.0);
        break;
      }
      walked += l;
    }
    if (progress >= 1.0) penX = pts.last.dx;

    // ── Underglow fill + the colored line, clipped to the pen. ──
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, penX + 0.5, size.height));

    final fillPath = Path()..moveTo(pts.first.dx, bottomY);
    for (final p in pts) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath
      ..lineTo(pts.last.dx, bottomY)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            sessionBand.withValues(alpha: 0.26),
            sessionBand.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTRB(0, padTop, size.width, bottomY)),
    );

    // Per-segment band-colored line.
    for (var i = 0; i < pts.length - 1; i++) {
      final sa = singleCrest ? scores[0] : scores[i];
      final sb = singleCrest ? scores[0] : scores[i + 1];
      final col = _bandColor(((sa + sb) / 2).round(), yellow);
      canvas.drawLine(
        pts[i],
        pts[i + 1],
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();

    // ── Exercise-boundary ticks (skip the first), full height, faint ──
    if (!singleCrest) {
      for (var b = 1; b < boundaryStart.length; b++) {
        final x = pts[boundaryStart[b]].dx;
        if (x > penX + 0.5) continue;
        canvas.drawLine(
          Offset(x, padTop - 4),
          Offset(x, bottomY),
          Paint()
            ..color = invInkFaint.withValues(alpha: 0.25)
            ..strokeWidth = 1,
        );
      }
    }

    // ── Summit dot (global max) — the only filled node ──
    final maxScore = scores.reduce(math.max);
    final summitIdx = singleCrest ? 1 : scores.indexOf(maxScore);
    final summitPt = singleCrest ? pts[1] : pts[summitIdx];
    final summitColor = _bandColor(maxScore, yellow);

    // ── Set-node rings, revealed after the pen passes ──
    final nodePts = singleCrest ? [pts[1]] : pts;
    final nodeScores = singleCrest ? [scores[0]] : scores;
    for (var i = 0; i < nodePts.length; i++) {
      final p = nodePts[i];
      if (p.dx > penX + 0.5) continue;
      final isSummit = !singleCrest && i == summitIdx;
      if (isSummit) continue; // drawn below with halo
      canvas.drawCircle(
        p,
        2.6,
        Paint()
          ..color = _bandColor(nodeScores[i], yellow).withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // Summit with halo, only once the pen reaches it.
    if (summitPt.dx <= penX + 0.5) {
      canvas.drawCircle(
          summitPt, 13, Paint()..color = summitColor.withValues(alpha: 0.20));
      canvas.drawCircle(
          summitPt, 6, Paint()..color = summitColor.withValues(alpha: 0.5));
      canvas.drawCircle(summitPt, 3.4, Paint()..color = summitColor);
    }

    // ── Per-exercise name labels under each segment's midpoint ──
    if (!singleCrest) {
      // Width-aware truncation so adjacent labels never collide on a narrow
      // (e.g. 320pt) phone when there are many exercises.
      final slotPx = (size.width - padX * 2) / boundaryStart.length;
      final maxChars = (slotPx * 0.9 / 5.8).floor().clamp(3, 14);
      for (var b = 0; b < boundaryStart.length; b++) {
        final start = boundaryStart[b];
        final end =
            b + 1 < boundaryStart.length ? boundaryStart[b + 1] : scores.length;
        final midIdx = (start + end - 1) / 2;
        final midX = pts[midIdx.floor()].dx +
            (pts[midIdx.ceil()].dx - pts[midIdx.floor()].dx) *
                (midIdx - midIdx.floor());
        final alpha = ((penX - midX) / 24 + 0.3).clamp(0.0, 1.0);
        if (alpha <= 0) continue;
        var name = names[b].toUpperCase();
        if (name.length > maxChars) {
          name = '${name.substring(0, maxChars)}…';
        }
        _label(
          canvas,
          name,
          Offset(midX, bottomY + 13),
          TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: invInkSoft.withValues(alpha: alpha),
          ),
        );
      }
    } else {
      _label(
        canvas,
        names.first.toUpperCase(),
        Offset(size.width / 2, bottomY + 13),
        TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: invInkSoft.withValues(alpha: progress.clamp(0.0, 1.0)),
        ),
      );
    }
  }

  void _label(Canvas canvas, String text, Offset at, TextStyle style,
      {_Anchor anchor = _Anchor.midCenter}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final origin = switch (anchor) {
      _Anchor.midCenter =>
        Offset(at.dx - painter.width / 2, at.dy - painter.height / 2),
      _Anchor.midLeft => Offset(at.dx, at.dy - painter.height / 2),
    };
    painter.paint(canvas, origin);
  }

  @override
  bool shouldRepaint(covariant _RidgelinePainter old) =>
      old.progress != progress ||
      old.reports != reports ||
      old.sessionBand != sessionBand ||
      old.yellow != yellow ||
      old.invInk != invInk ||
      old.invInkSoft != invInkSoft ||
      old.invInkFaint != invInkFaint;
}

enum _Anchor { midCenter, midLeft }

// ─── Vital strip — 4-up tabular figures, hairline-divided, on dark ───
class _VitalStrip extends StatelessWidget {
  const _VitalStrip({
    required this.reports,
    required this.totalDuration,
    required this.totalCalories,
  });

  final List<ExerciseSessionReport> reports;
  final Duration totalDuration;
  final int totalCalories;

  @override
  Widget build(BuildContext context) {
    // "Đúng form": branch per modality — never sum reps across holds.
    final hasRep =
        reports.any((r) => !r.report.isSecondBased && (r.totalReps ?? 0) > 0);
    final hasHold = reports
        .any((r) => r.report.isSecondBased && (r.report.totalSeconds ?? 0) > 0);

    final String workLabel;
    final String workValue;
    if (hasHold && !hasRep) {
      final good = reports.fold<double>(
          0, (s, r) => s + (r.report.goodSeconds ?? 0));
      final total = reports.fold<double>(
          0, (s, r) => s + (r.report.totalSeconds ?? 0));
      workLabel = 'GIÂY';
      workValue = '${_fmtSeconds(good)}/${_fmtSeconds(total)}';
    } else {
      final good = reports.fold<int>(0, (s, r) => s + (r.goodReps ?? 0));
      final total = reports.fold<int>(0, (s, r) => s + (r.totalReps ?? 0));
      workLabel = 'ĐÚNG FORM';
      workValue = '$good/$total';
    }

    return Row(
      children: [
        Expanded(child: _VitalStat(label: 'BÀI', value: '${reports.length}')),
        _VitalDivider(),
        Expanded(child: _VitalStat(label: workLabel, value: workValue)),
        _VitalDivider(),
        Expanded(
            child: _VitalStat(label: 'GIỜ', value: _fmtClock(totalDuration))),
        _VitalDivider(),
        Expanded(child: _VitalStat(label: 'KCAL', value: '~$totalCalories')),
      ],
    );
  }
}

class _VitalStat extends StatelessWidget {
  const _VitalStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: c.invInkFaint,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 17,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            color: c.invInk,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
      ],
    );
  }
}

class _VitalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TROPHY BILLING — the earned highlight, billed like a lead credit.
// Hairline-ruled, no box, no icon — pure type, deferential to the ridge.
// ═══════════════════════════════════════════════════════════════

class _TrophyBilling extends StatelessWidget {
  const _TrophyBilling({required this.trophy});
  final Trophy trophy;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Text(
                trophy.tag,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: c.invInkSoft,
                ),
              ),
            ),
            const Spacer(),
            Text(
              'KHOẢNH KHẮC',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.7,
                color: c.invInkFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Text(
                  trophy.value,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 76,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -4,
                    height: 0.88,
                    color: c.invInk,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  trophy.label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                    letterSpacing: -0.3,
                    color: c.invInkSoft,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COACH NOTE — AI pull-quote (yellow left-rule) + two editorial rows.
// ═══════════════════════════════════════════════════════════════

class _CoachNote extends StatelessWidget {
  const _CoachNote({required this.coach});
  final SessionCoach coach;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final (IconData watchIcon, Color watchAccent) = switch (coach.kind) {
      CoachWatchKind.perfect => (Icons.check_circle_rounded, c.yellow),
      CoachWatchKind.fault => (Icons.center_focus_strong_rounded, c.attention),
      CoachWatchKind.lowForm => (Icons.self_improvement_rounded, c.invInkSoft),
    };
    final watchBody = coach.watchExerciseName == null
        ? coach.watch
        : '${coach.watchExerciseName}: ${coach.watch}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI monogram + standfirst
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              alignment: Alignment.center,
              child: Text(
                'AI',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: c.yellow,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HLV AI',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: c.invInkFaint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Đánh giá cuối buổi',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.3,
                    color: c.invInk,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Pull-quote with a single 3px yellow left-rule.
        Container(
          padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: c.yellow, width: 3)),
          ),
          child: Text(
            coach.quote,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              height: 1.55,
              letterSpacing: -0.1,
              color: c.invInk,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _CoachRow(
          label: 'ĐỂ Ý',
          body: watchBody,
          glyph: watchIcon,
          glyphColor: watchAccent,
        ),
        const SizedBox(height: 14),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        const SizedBox(height: 14),
        _CoachRow(
          label: 'BUỔI SAU',
          body: coach.next,
          glyph: Icons.east_rounded,
          glyphColor: c.invInk,
        ),
      ],
    );
  }
}

class _CoachRow extends StatelessWidget {
  const _CoachRow({
    required this.label,
    required this.body,
    required this.glyph,
    required this.glyphColor,
  });
  final String label;
  final String body;
  final IconData glyph;
  final Color glyphColor;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: c.invInkFaint,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(glyph, size: 13, color: glyphColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            body,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              height: 1.4,
              letterSpacing: -0.2,
              color: c.invInk,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CAST CREDITS — per-exercise indexed credits list. Replaces the old
// stat-card grid; reads as the ridge's key, scales 1→N gracefully.
// ═══════════════════════════════════════════════════════════════

class _CreditsList extends StatelessWidget {
  const _CreditsList({required this.reports});
  final List<ExerciseSessionReport> reports;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section eyebrow
        Row(
          children: [
            Flexible(
              child: Text(
                'DIỄN VIÊN',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: c.invInkFaint,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${reports.length} BÀI',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: c.invInkFaint,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < reports.length; i++) ...[
          if (i > 0)
            Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          _CreditRow(report: reports[i], index: i),
        ],
      ],
    );
  }
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.report, required this.index});
  final ExerciseSessionReport report;
  final int index;

  String _difficultyLabel(String? d) => switch (d) {
        'light' => 'Nhẹ',
        'medium' => 'Vừa',
        'heavy' => 'Nặng',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final score = report.formScore;
    final band = _bandColor(score, c.yellow);
    final setScores = report.report.sets.map((s) => s.score).toList();
    final difficulty = _difficultyLabel(report.userDifficulty);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Credits page-number index
              SizedBox(
                width: 34,
                child: Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1,
                    color: c.invInkFaint,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  report.exerciseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.5,
                    color: c.invInk,
                  ),
                ),
              ),
              // Dotted leader
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    height: 2,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _DottedLeaderPainter(
                        color: c.invInkFaint.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                '$score',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  height: 1,
                  letterSpacing: -1.4,
                  color: band,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '${report.report.sets.length} hiệp · ${_formatReportWork(report)}'
                    '${difficulty.isEmpty ? '' : ' · $difficulty'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: c.invInkSoft,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Inline per-set spark — this exercise's slice of the ridge.
                SizedBox(
                  width: math.min(40.0 + setScores.length * 14.0, 120.0),
                  height: 34,
                  child: ClipRect(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _SetSparkPainter(
                        scores: setScores,
                        accent: band,
                        dim: c.invInkFaint,
                      ),
                    ),
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

class _DottedLeaderPainter extends CustomPainter {
  const _DottedLeaderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const gap = 5.0;
    final y = size.height / 2;
    double x = 0;
    while (x < size.width) {
      canvas.drawCircle(Offset(x, y), 0.9, paint);
      x += gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLeaderPainter old) => old.color != color;
}

class _SetSparkPainter extends CustomPainter {
  const _SetSparkPainter({
    required this.scores,
    required this.accent,
    required this.dim,
  });
  final List<int> scores;
  final Color accent;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;
    const padX = 6.0;
    const topY = 6.0;
    final bottomY = size.height - 14.0;
    final usable = bottomY - topY;
    final stepX = scores.length <= 1
        ? 0.0
        : (size.width - padX * 2) / (scores.length - 1);
    final pts = <Offset>[];
    for (var i = 0; i < scores.length; i++) {
      final x = scores.length == 1 ? size.width / 2 : padX + stepX * i;
      final y = bottomY - (scores[i] / 100) * usable;
      pts.add(Offset(x, y));
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < pts.length; i++) {
      canvas.drawCircle(
          pts[i], 3, Paint()..color = accent.withValues(alpha: 0.95));
      final lp = TextPainter(
        text: TextSpan(
          text: 'S${i + 1}',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: dim,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      lp.paint(canvas, Offset(pts[i].dx - lp.width / 2, bottomY + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SetSparkPainter old) =>
      old.scores != scores || old.accent != accent || old.dim != dim;
}

// ═══════════════════════════════════════════════════════════════
// LIGHTS-UP CLOSE — the one color transition. Dark reel curves into
// cream; HẾT wordmark, ghost share links, and the yellow Done CTA.
// ═══════════════════════════════════════════════════════════════

class _LightsUpClose extends StatelessWidget {
  const _LightsUpClose({
    required this.beat,
    required this.shimmer,
    required this.bottomInset,
    required this.onDone,
    required this.onShare,
    required this.onShareToZalo,
  });

  final Animation<double> beat;
  final AnimationController shimmer;
  final double bottomInset;
  final VoidCallback onDone;
  final VoidCallback onShare;
  final VoidCallback onShareToZalo;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      ),
      // +36 top to compensate for the -36 overlap translate in the parent.
      padding: EdgeInsets.fromLTRB(20, 36 + 30, 20, 28 + bottomInset),
      child: _BeatReveal(
        animation: beat,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'HẾT',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      height: 1.0,
                      letterSpacing: -1.6,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 24,
                    height: 2,
                    decoration: BoxDecoration(
                      color: c.yellow,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [
                        BoxShadow(
                          color: c.yellow.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            // Quiet ghost share links on a hairline row (not buttons).
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: c.border),
                  bottom: BorderSide(color: c.border),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: _ShareLink(
                        label: 'Chỉnh ảnh & chia sẻ', onTap: onShare),
                  ),
                  Container(
                    width: 1,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    color: c.border,
                  ),
                  _ShareLink(label: 'Zalo', onTap: onShareToZalo),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _DoneCta(shimmer: shimmer, onTap: onDone),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Hẹn bạn ở buổi sau.',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.1,
                  color: c.inkFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareLink extends StatelessWidget {
  const _ShareLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: c.inkSoft,
            ),
          ),
          const SizedBox(height: 3),
          Container(width: 18, height: 1, color: c.borderHi),
        ],
      ),
    );
  }
}

// ─── Done CTA — yellow halo pill with slow diagonal shimmer ───
class _DoneCta extends StatefulWidget {
  const _DoneCta({required this.shimmer, required this.onTap});
  final AnimationController shimmer;
  final VoidCallback onTap;

  @override
  State<_DoneCta> createState() => _DoneCtaState();
}

class _DoneCtaState extends State<_DoneCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedBuilder(
          animation: widget.shimmer,
          builder: (context, _) {
            final v = widget.shimmer.value;
            return Container(
              height: 62,
              decoration: BoxDecoration(
                color: c.yellow,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: c.yellow.withValues(alpha: 0.5),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: c.yellow.withValues(alpha: 0.25),
                    blurRadius: 56,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1.6 + (v * 3.2), -1),
                            end: Alignment(-0.6 + (v * 3.2), 1),
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.32),
                              Colors.white.withValues(alpha: 0),
                            ],
                            stops: const [0.35, 0.5, 0.65],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Hoàn thành buổi tập',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -0.3,
                                  color: c.yellowInk,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: c.yellowInk,
                            ),
                          ],
                        ),
                      ),
                    ),
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

// ─── Hero grain — deterministic, seed-based (never time-based) ───
class _HeroGrainPainter extends CustomPainter {
  const _HeroGrainPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(1402);
    final p = Paint();
    for (var i = 0; i < 220; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      p.color = Colors.white.withValues(alpha: 0.015 + rng.nextDouble() * 0.02);
      canvas.drawCircle(Offset(x, y), 0.7, p);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroGrainPainter old) => false;
}
