// WorkoutSummaryScreen — "Đỉnh form" (the verdict, then the climb).
//
// A world-class finale rebuilt to speak the app's OWN language instead of a
// borrowed cinema metaphor. It follows the exact stage-hero shape every
// primary tab uses — a warm-dark hero that curves at 36pt into the cream
// body — so the summary reads as one app, not a separate dark experience.
//
// Two movements:
//   1. HERO (dark)  — the VERDICT. The Vika ring (the same instrument that
//      fills during rest between sets) resolves into the final form score,
//      counting up inside it. Verdict headline + earned highlight fold into
//      this one composition — the single triumphant focal point.
//   2. BODY (cream) — the CLIMB. On the app's primary surface, with varied
//      rhythm so nothing reads as stacked boxes: a wide calm form-journey
//      chart (how the score was earned), a hairline vitals line, an intimate
//      coach pull-quote, a lean exercise list, and the app-standard CTA.
//
// The ring (your grade) and the journey (how you got there) tell different
// stories, so they complement rather than duplicate.
//
// This is a pure reward screen — the difficulty popup fires on entry via
// _promptThenReveal() and the reveal cascade only plays once it resolves,
// so nothing animates behind the barrier.
//
// All values use Premium Ivory tokens via VikaColors. Reserved yellow is held
// to its sanctioned uses: the ring fill, the sparkle dot, the gold-band score,
// the coach left-rule/underline, and the Done CTA. No emojis. Band thresholds
// (>=80 gold / 60-79 amber / <60 burnt) are the one evaluative signal.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/workout_session_report.dart';
import '../../services/session_summary_builder.dart';
import '../../services/streak_tier.dart';
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

  /// Drives BOTH the ring score count-up AND the journey draw-on, so the
  /// gauge and the chart land on the same frames. Gated behind [_entry] so the
  /// climb plays when the celebration lands, not behind the popup.
  late final Animation<double> _climb;

  bool _reduceMotion = false;
  bool _depsReady = false;

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
    );
    _heroPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // Six beats mapped to the strata: verdict headline, ring, journey, vitals,
    // coach, then the exercise list + close.
    _b0 = _beat(0.00, 0.26);
    _b1 = _beat(0.10, 0.42);
    _b2 = _beat(0.30, 0.62);
    _b3 = _beat(0.44, 0.74);
    _b4 = _beat(0.56, 0.86);
    _b5 = _beat(0.68, 1.0);

    _climb = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.12, 0.97, curve: Curves.linear),
    );

    // Gate the celebration: fire the post-exercise reflection popup for the
    // last exercise on entry, then play the reveal once it resolves. The dark
    // popup barrier covers the un-revealed (opacity-0) body behind it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptThenReveal());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!_reduceMotion) {
      _shimmer.repeat();
      _heroPulse.repeat(reverse: true);
    }
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
    if (!mounted) return;
    if (_reduceMotion) {
      _entry.value = 1.0;
    } else {
      _entry.forward();
    }
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

  int get _totalSets =>
      widget.reports.fold<int>(0, (s, r) => s + r.report.sets.length);

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);

    // Clamp accessibility text scaling so the big ring numeral and the tabular
    // figures can't overflow at maxed-out system text.
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
                    _buildHero(c, topInset),
                    // The cream body rises into the dark hero: a 36pt
                    // rounded-top curve pulled up over the hero's bottom edge
                    // reveals the dark behind its corners — the signature
                    // stage-hero curve (house lights coming up).
                    Transform.translate(
                      offset: const Offset(0, -36),
                      child: _buildBody(c, bottomInset),
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

  // ── HERO — the verdict. Warm-dark stage with the Vika ring at its heart ──
  Widget _buildHero(VikaColors c, double topInset) {
    final summary = widget.sessionSummary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.8, -1),
          end: const Alignment(0.8, 1),
          colors: [c.bgInverse, c.bgInverseHi],
        ),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.22),
            blurRadius: 48,
            offset: const Offset(0, 14),
          ),
        ],
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
            bottom: -160,
            left: -140,
            child: IgnorePointer(
              child: SizedBox(
                width: 420,
                height: 360,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0x40CD7C45), Color(0x00CD7C45)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Deterministic film grain (never time-based).
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _HeroGrainPainter()),
            ),
          ),
          // Two quiet sparkle dots.
          Positioned(
            top: topInset + 116,
            left: 28,
            child: _SparkleDot(color: c.yellow, size: 3),
          ),
          Positioned(
            top: topInset + 300,
            right: 36,
            child: _SparkleDot(color: c.yellow, size: 2),
          ),
          // Foreground content column.
          Padding(
            padding: EdgeInsets.fromLTRB(22, topInset + 16, 22, 64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WordmarkRow(
                  exerciseCount: widget.reports.length,
                  totalDuration: widget.totalDuration,
                ),
                const SizedBox(height: 30),
                // Eyebrow + band-aware verdict headline.
                _BeatReveal(
                  animation: _b0,
                  child: _Verdict(sessionFormScore: summary.sessionFormScore),
                ),
                const SizedBox(height: 26),
                // The signature: the Vika ring resolving into the final score.
                _BeatReveal(
                  animation: _b1,
                  child: Center(
                    child: _VerdictRing(
                      sessionFormScore: summary.sessionFormScore,
                      streakBonus: summary.streakBonus,
                      streakWeeks: summary.streakWeeks,
                      climb: _climb,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // The earned highlight, folded in as one quiet line.
                _BeatReveal(
                  animation: _b1,
                  child: Center(child: _TrophyLine(trophy: widget.trophy)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── BODY — the climb. Cream editorial surface, varied rhythm ──
  Widget _buildBody(VikaColors c, double bottomInset) {
    final summary = widget.sessionSummary;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      ),
      // +36 top compensates for the -36 overlap translate in the parent.
      padding: EdgeInsets.fromLTRB(22, 36 + 30, 22, 26 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. The climb — how the score was earned.
          _BeatReveal(
            animation: _b2,
            child: _JourneySection(
              reports: widget.reports,
              totalSets: _totalSets,
              sessionFormScore: summary.sessionFormScore,
              climb: _climb,
            ),
          ),
          const SizedBox(height: 26),
          // 2. Hairline vitals line — one slim band, not a card grid.
          _BeatReveal(
            animation: _b3,
            child: _VitalsLine(
              reports: widget.reports,
              totalDuration: widget.totalDuration,
              totalCalories: widget.totalCalories,
            ),
          ),
          const SizedBox(height: 28),
          // 3. The coach voice — intimate pull-quote.
          _BeatReveal(
            animation: _b4,
            child: _CoachNote(coach: widget.coach),
          ),
          const SizedBox(height: 28),
          // 4. The lean exercise list.
          _BeatReveal(
            animation: _b5,
            child: _ExerciseList(reports: widget.reports),
          ),
          const SizedBox(height: 30),
          // 5. The close.
          _BeatReveal(
            animation: _b5,
            child: _Close(
              shimmer: _shimmer,
              reduceMotion: _reduceMotion,
              onDone: widget.onDone,
              onShare: widget.onShare ?? () => _stub('Chia sẻ'),
              onShareToZalo: widget.onShareToZalo ?? () => _stub('Zalo'),
            ),
          ),
        ],
      ),
    );
  }

  void _stub(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label sẽ có ở phiên bản sau.')),
    );
  }
}

// ─── Beat reveal — fade + 18px rise ───
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
            offset: Offset(0, (1 - v) * 18),
            child: child,
          ),
        );
      },
    );
  }
}

class _SparkleDot extends StatelessWidget {
  const _SparkleDot({required this.color, required this.size});
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
// WORDMARK ROW — inverted VIKA lockup + hairline session meta.
// ═══════════════════════════════════════════════════════════════

class _WordmarkRow extends StatelessWidget {
  const _WordmarkRow({
    required this.exerciseCount,
    required this.totalDuration,
  });
  final int exerciseCount;
  final Duration totalDuration;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.asset(
            'assets/branding/Logo.jpeg',
            width: 26,
            height: 26,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'VIKA',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// VERDICT — sparkle eyebrow + band-aware italic headline.
// ═══════════════════════════════════════════════════════════════

class _Verdict extends StatelessWidget {
  const _Verdict({required this.sessionFormScore});
  final int sessionFormScore;

  String get _headline => sessionFormScore >= 80
      ? 'Form đỉnh.'
      : sessionFormScore >= 60
          ? 'Form chắc.'
          : 'Buổi tập nền.';

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// VERDICT RING — the signature. The same instrument that fills during
// rest between sets, here resolving into the final form score: a fine
// arc filling to score/105 on the climb, with the count-up numeral at
// its center. One iconic focal point.
// ═══════════════════════════════════════════════════════════════

class _VerdictRing extends StatelessWidget {
  const _VerdictRing({
    required this.sessionFormScore,
    required this.streakBonus,
    required this.streakWeeks,
    required this.climb,
  });

  final int sessionFormScore;
  final int streakBonus;
  final int streakWeeks;
  final Animation<double> climb;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final band = _bandColor(sessionFormScore, c.yellow);
    final hasBonus = streakBonus > 0;
    const dim = 208.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: dim,
          height: dim,
          child: AnimatedBuilder(
            animation: climb,
            builder: (context, _) {
              final v = climb.value.clamp(0.0, 1.0);
              final eased = Curves.easeOutCubic.transform(v);
              final display = (sessionFormScore * eased).round();
              // Ink the numeral from soft cream to full band over the climb.
              final inkProg = ((v - 0.35) / 0.65).clamp(0.0, 1.0);
              final numeralColor = Color.lerp(
                c.invInk.withValues(alpha: 0.85),
                band,
                inkProg,
              )!;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Soft glow behind the arc.
                  SizedBox(
                    width: dim,
                    height: dim,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            band.withValues(alpha: 0.12 * inkProg),
                            band.withValues(alpha: 0),
                          ],
                          stops: const [0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  CustomPaint(
                    size: const Size(dim, dim),
                    painter: _RingPainter(
                      progress: (sessionFormScore.clamp(0, 105) / 105) * eased,
                      band: band,
                      track: c.invInkFaint.withValues(alpha: 0.20),
                      tick: c.invInkFaint.withValues(alpha: 0.30),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$display',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 84,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -4,
                              height: 0.9,
                              color: numeralColor,
                              fontFeatures: VikaIvoryMain.tabularFigures,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              '/105',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                fontStyle: FontStyle.italic,
                                letterSpacing: -0.4,
                                color: c.invInkFaint,
                                fontFeatures: VikaIvoryMain.tabularFigures,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ĐIỂM FORM',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                          color: c.invInkFaint,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        if (hasBonus) ...[
          const SizedBox(height: 18),
          _BonusCaption(
            band: band,
            streakBonus: streakBonus,
            streakWeeks: streakWeeks,
            climb: climb,
          ),
        ],
      ],
    );
  }
}

class _BonusCaption extends StatelessWidget {
  const _BonusCaption({
    required this.band,
    required this.streakBonus,
    required this.streakWeeks,
    required this.climb,
  });
  final Color band;
  final int streakBonus;
  final int streakWeeks;
  final Animation<double> climb;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return AnimatedBuilder(
      animation: climb,
      builder: (context, _) {
        final reveal = ((climb.value - 0.68) / 0.32).clamp(0.0, 1.0);
        return Opacity(
          opacity: reveal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22 * reveal,
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
                '+$streakBonus chuỗi · ${streakTierLabel(streakWeeks)}',
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
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.band,
    required this.track,
    required this.tick,
  });

  final double progress; // 0..1
  final Color band;
  final Color track;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 12;
    const stroke = 7.0;

    // Track — full circle, hairline.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    // Tick marks every 30° — subtle, on the track.
    for (var i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * math.pi - math.pi / 2;
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - stroke / 2 - 2),
        center.dy + math.sin(angle) * (radius - stroke / 2 - 2),
      );
      final outer = Offset(
        center.dx + math.cos(angle) * (radius - stroke / 2 - 6),
        center.dy + math.sin(angle) * (radius - stroke / 2 - 6),
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = tick
          ..strokeWidth = 1,
      );
    }

    if (progress <= 0.001) return;

    // Band-colored fill arc — sweep from top clockwise.
    final sweep = progress.clamp(0.0, 1.0) * 2 * math.pi;
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: [band.withValues(alpha: 0.5), band, band],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fillPaint,
    );

    // Bright tip dot.
    final tipAngle = -math.pi / 2 + sweep;
    final tip = Offset(
      center.dx + math.cos(tipAngle) * radius,
      center.dy + math.sin(tipAngle) * radius,
    );
    canvas.drawCircle(
      tip,
      stroke / 2 + 5,
      Paint()
        ..color = band.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(tip, stroke / 2 + 1, Paint()..color = band);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.band != band ||
      old.track != track ||
      old.tick != tick;
}

// ═══════════════════════════════════════════════════════════════
// TROPHY LINE — the earned highlight, folded into the hero as one
// quiet pill. Deferential to the ring; never a giant billing.
// ═══════════════════════════════════════════════════════════════

class _TrophyLine extends StatelessWidget {
  const _TrophyLine({required this.trophy});
  final Trophy trophy;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: 14, color: c.yellow),
          const SizedBox(width: 8),
          Text(
            trophy.tag,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: c.invInkFaint,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: c.invInkFaint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              trophy.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.2,
                color: c.invInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// JOURNEY — the climb. One calm area chart of every set's form score
// concatenated across exercises, band-colored, with set nodes, exercise
// boundary labels, and a glowing summit. Retoned for the cream surface.
// ═══════════════════════════════════════════════════════════════

class _JourneySection extends StatelessWidget {
  const _JourneySection({
    required this.reports,
    required this.totalSets,
    required this.sessionFormScore,
    required this.climb,
  });

  final List<ExerciseSessionReport> reports;
  final int totalSets;
  final int sessionFormScore;
  final Animation<double> climb;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'HÀNH TRÌNH FORM', trailing: '$totalSets HIỆP'),
        const SizedBox(height: 18),
        SizedBox(
          height: 158,
          child: AnimatedBuilder(
            animation: climb,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _JourneyPainter(
                  reports: reports,
                  progress: climb.value,
                  yellow: c.yellow,
                  ink: c.ink,
                  inkSoft: c.inkSoft,
                  inkFaint: c.inkFaint,
                  sessionBand: _bandColor(sessionFormScore, c.yellow),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _JourneyPainter extends CustomPainter {
  _JourneyPainter({
    required this.reports,
    required this.progress,
    required this.yellow,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.sessionBand,
  });

  final List<ExerciseSessionReport> reports;
  final double progress;
  final Color yellow;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color sessionBand;

  @override
  void paint(Canvas canvas, Size size) {
    // Concatenate every set's score across exercises, tracking boundaries.
    final scores = <int>[];
    final boundaryStart = <int>[];
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
    final grid = Paint()..strokeWidth = 1;
    canvas.drawLine(
      Offset(padX, bottomY),
      Offset(size.width - padX, bottomY),
      grid..color = inkFaint.withValues(alpha: 0.30),
    );
    for (final v in [50, 100]) {
      final y = yFor(v);
      const dash = 4.0, gap = 5.0;
      double x = padX;
      while (x < size.width - padX) {
        final next = math.min(x + dash, size.width - padX);
        canvas.drawLine(Offset(x, y), Offset(next, y),
            grid..color = inkFaint.withValues(alpha: 0.22));
        x = next + gap;
      }
      _label(canvas, '$v', Offset(2, y),
          TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: inkFaint,
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
            sessionBand.withValues(alpha: 0.22),
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
            ..color = inkFaint.withValues(alpha: 0.28)
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
      if (isSummit) continue;
      canvas.drawCircle(
        p,
        2.6,
        Paint()
          ..color = _bandColor(nodeScores[i], yellow).withValues(alpha: 0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // Summit with halo, only once the pen reaches it.
    if (summitPt.dx <= penX + 0.5) {
      canvas.drawCircle(
          summitPt, 13, Paint()..color = summitColor.withValues(alpha: 0.18));
      canvas.drawCircle(
          summitPt, 6, Paint()..color = summitColor.withValues(alpha: 0.5));
      canvas.drawCircle(summitPt, 3.4, Paint()..color = summitColor);
    }

    // ── Per-exercise name labels under each segment's midpoint ──
    if (!singleCrest) {
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
            color: inkSoft.withValues(alpha: alpha),
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
          color: inkSoft.withValues(alpha: progress.clamp(0.0, 1.0)),
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
  bool shouldRepaint(covariant _JourneyPainter old) =>
      old.progress != progress ||
      old.reports != reports ||
      old.sessionBand != sessionBand ||
      old.yellow != yellow ||
      old.ink != ink ||
      old.inkSoft != inkSoft ||
      old.inkFaint != inkFaint;
}

enum _Anchor { midCenter, midLeft }

// ═══════════════════════════════════════════════════════════════
// VITALS LINE — one slim hairline-divided band of tabular figures.
// ═══════════════════════════════════════════════════════════════

class _VitalsLine extends StatelessWidget {
  const _VitalsLine({
    required this.reports,
    required this.totalDuration,
    required this.totalCalories,
  });

  final List<ExerciseSessionReport> reports;
  final Duration totalDuration;
  final int totalCalories;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);

    // "Đúng form": branch per modality — never sum reps across holds.
    final hasRep =
        reports.any((r) => !r.report.isSecondBased && (r.totalReps ?? 0) > 0);
    final hasHold = reports
        .any((r) => r.report.isSecondBased && (r.report.totalSeconds ?? 0) > 0);

    final String workLabel;
    final String workValue;
    if (hasHold && !hasRep) {
      final good =
          reports.fold<double>(0, (s, r) => s + (r.report.goodSeconds ?? 0));
      final total =
          reports.fold<double>(0, (s, r) => s + (r.report.totalSeconds ?? 0));
      workLabel = 'GIÂY';
      workValue = '${_fmtSeconds(good)}/${_fmtSeconds(total)}';
    } else {
      final good = reports.fold<int>(0, (s, r) => s + (r.goodReps ?? 0));
      final total = reports.fold<int>(0, (s, r) => s + (r.totalReps ?? 0));
      workLabel = 'ĐÚNG FORM';
      workValue = '$good/$total';
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.border),
          bottom: BorderSide(color: c.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: _VitalStat(label: 'GIỜ', value: _fmtClock(totalDuration))),
          _VitalDivider(),
          Expanded(child: _VitalStat(label: workLabel, value: workValue)),
          _VitalDivider(),
          Expanded(child: _VitalStat(label: 'KCAL', value: '~$totalCalories')),
        ],
      ),
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
            color: c.inkFaint,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 19,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            color: c.ink,
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
    final c = VikaColors.of(context);
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: c.border,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COACH NOTE — the voice. AI pull-quote (yellow left-rule) + two rows.
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
      CoachWatchKind.lowForm => (Icons.self_improvement_rounded, c.inkSoft),
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
                color: c.ink,
                borderRadius: BorderRadius.circular(9),
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
                    color: c.inkFaint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Đánh giá buổi tập',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.3,
                    color: c.ink,
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
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              height: 1.55,
              letterSpacing: -0.1,
              color: c.ink,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _CoachRow(
          label: 'CẦN CHÚ Ý',
          body: watchBody,
          glyph: watchIcon,
          glyphColor: watchAccent,
        ),
        const SizedBox(height: 14),
        Container(height: 1, color: c.border),
        const SizedBox(height: 14),
        _CoachRow(
          label: 'BUỔI SAU',
          body: coach.next,
          glyph: Icons.east_rounded,
          glyphColor: c.ink,
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
              color: c.inkFaint,
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
              color: c.ink,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EXERCISE LIST — lean ranked rows: index, name, dotted leader, band
// score, and a calm row of band-colored set dots (no micro-chart soup).
// ═══════════════════════════════════════════════════════════════

class _ExerciseList extends StatelessWidget {
  const _ExerciseList({required this.reports});
  final List<ExerciseSessionReport> reports;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'CÁC BÀI ĐÃ TẬP', trailing: '${reports.length} BÀI'),
        const SizedBox(height: 4),
        for (var i = 0; i < reports.length; i++) ...[
          if (i > 0) Container(height: 1, color: c.border),
          _ExerciseRow(report: reports[i], index: i),
        ],
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.report, required this.index});
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
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1,
                    color: c.inkFaint,
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
                    color: c.ink,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    height: 2,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _DottedLeaderPainter(
                        color: c.inkFaint.withValues(alpha: 0.45),
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
            padding: const EdgeInsets.only(left: 38),
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
                      color: c.inkSoft,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Calm per-set dots — this exercise's set bands, no chart.
                _SetDots(scores: setScores, yellow: c.yellow, dim: c.inkGhost),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetDots extends StatelessWidget {
  const _SetDots({required this.scores, required this.yellow, required this.dim});
  final List<int> scores;
  final Color yellow;
  final Color dim;

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < scores.length; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _bandColor(scores[i], yellow),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
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

// ═══════════════════════════════════════════════════════════════
// SECTION HEADER — eyebrow + hairline rule + trailing count.
// ═══════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.trailing});
  final String label;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: c.inkFaint,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: c.border)),
        const SizedBox(width: 12),
        Text(
          trailing,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: c.inkFaint,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CLOSE — share links + the app-standard yellow halo Done CTA.
// ═══════════════════════════════════════════════════════════════

class _Close extends StatelessWidget {
  const _Close({
    required this.shimmer,
    required this.reduceMotion,
    required this.onDone,
    required this.onShare,
    required this.onShareToZalo,
  });

  final AnimationController shimmer;
  final bool reduceMotion;
  final VoidCallback onDone;
  final VoidCallback onShare;
  final VoidCallback onShareToZalo;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                child: _ShareLink(label: 'Chỉnh sửa & chia sẻ', onTap: onShare),
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
        _DoneCta(shimmer: shimmer, reduceMotion: reduceMotion, onTap: onDone),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Hẹn gặp lại buổi sau.',
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
  const _DoneCta({
    required this.shimmer,
    required this.reduceMotion,
    required this.onTap,
  });
  final AnimationController shimmer;
  final bool reduceMotion;
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
                    if (!widget.reduceMotion)
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
