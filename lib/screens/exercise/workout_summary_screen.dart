// WorkoutSummaryScreen — magazine-cover finale.
//
// Visual hierarchy is reorganized to feel like a print poster: huge form
// score on the hero, a sparkline DNA strip, exercise medallions, then
// editorial section blocks with visualization, not text walls.
//
// Sections (top to bottom):
//   1. Hero Sharable Card         — magazine-cover layout (kept per spec)
//   2. One-Thing Trophy Card      — large stat + icon, share-anchor moment
//   3. Form Arc Chart             — mountain line across exercises
//   4. Coach AI Three-Pillar      — Mạnh / Để ý / Buổi sau, icon cards
//   5. Top Issue Card             — kept mechanic, polished surface
//   6. Last Exercise Rating       — reused DifficultyRatingBlock
//   7. Session Stats Grid         — per-ex form bars + set sparklines
//   8. Session RPE                — 4-tile perceived-intensity
//   9. Done CTA                   — yellow shimmer
//
// All values use Premium Ivory tokens via VikaColors. Yellow reserved
// for stat / dot / underline / CTA.
//
// NOTE(wiring): see report — session form score, top-issue ranker,
// one-thing picker, coach narrative, RPE persistence all hardcoded.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../interpreter/interpreter_base.dart';
import '../../models/workout_session_report.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../../widgets/exercise/difficulty_rating_block.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  const WorkoutSummaryScreen({
    super.key,
    required this.reports,
    required this.totalDuration,
    required this.totalCalories,
    required this.streakDays,
    required this.onDone,
    this.onShare,
    this.onShareToZalo,
    this.onLastExerciseDifficulty,
    this.onSessionRpe,
  });

  final List<ExerciseSessionReport> reports;
  final Duration totalDuration;
  final int totalCalories;
  final int streakDays;
  final VoidCallback onDone;
  final VoidCallback? onShare;
  final VoidCallback? onShareToZalo;
  final ValueChanged<String>? onLastExerciseDifficulty;
  final ValueChanged<String>? onSessionRpe;

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _shimmer;
  late final AnimationController _heroPulse;

  String? _lastDifficulty;
  String? _sessionRpe;

  late final Animation<double> _b0;
  late final Animation<double> _b1;
  late final Animation<double> _b2;
  late final Animation<double> _b3;
  late final Animation<double> _b4;
  late final Animation<double> _b5;
  late final Animation<double> _b6;
  late final Animation<double> _b7;
  late final Animation<double> _b8;

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

    _b0 = _beat(0.00, 0.18);
    _b1 = _beat(0.06, 0.32);
    _b2 = _beat(0.18, 0.42);
    _b3 = _beat(0.26, 0.50);
    _b4 = _beat(0.34, 0.58);
    _b5 = _beat(0.42, 0.66);
    _b6 = _beat(0.50, 0.74);
    _b7 = _beat(0.58, 0.82);
    _b8 = _beat(0.66, 1.0);

    _lastDifficulty = widget.reports.isNotEmpty
        ? widget.reports.last.userDifficulty
        : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entry.forward();
    });
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
  int get _sessionFormScore {
    // NOTE(wiring): weighted-by-reps × difficulty formula needed.
    if (widget.reports.isEmpty) return 0;
    final total = widget.reports.fold<int>(0, (s, r) => s + r.formScore);
    return (total / widget.reports.length).round();
  }

  int get _sessionTotalReps =>
      widget.reports.fold(0, (s, r) => s + r.totalReps);
  int get _sessionGoodReps =>
      widget.reports.fold(0, (s, r) => s + r.goodReps);

  /// NOTE(wiring): real cross-exercise priority ranking with pain linkage.
  DetectedEvidence? get _topIssue {
    for (final r in widget.reports) {
      final q = r.report.issueQuestion;
      if (q != null) return q;
    }
    return null;
  }

  bool get _isLastDifficultyAnswered => _lastDifficulty != null;
  bool get _isSessionRpeAnswered => _sessionRpe != null;
  bool get _isDoneEnabled =>
      _isLastDifficultyAnswered && _isSessionRpeAnswered;

  void _handleLastDifficulty(String d) {
    if (_lastDifficulty != null) return;
    setState(() => _lastDifficulty = d);
    if (widget.reports.isNotEmpty) {
      widget.reports.last.userDifficulty = d;
    }
    widget.onLastExerciseDifficulty?.call(d);
  }

  void _handleSessionRpe(String d) {
    if (_sessionRpe != null) return;
    setState(() => _sessionRpe = d);
    widget.onSessionRpe?.call(d);
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final hasLastExercise = widget.reports.isNotEmpty;
    final lastExerciseName = hasLastExercise
        ? widget.reports.last.exerciseName
        : 'Bài cuối';

    // Clamp accessibility text scaling. Without this, a user with
    // "Larger Text" maxed out in iOS / Android system settings would
    // blow up the 48pt italic header, the 100pt trophy numeral and
    // the per-card form numbers to the point of overflow. We still
    // allow some scaling up (1.15) for low-vision users.
    final mq = MediaQuery.of(context);
    final clampedScaler = mq.textScaler.clamp(
      minScaleFactor: 0.92,
      maxScaleFactor: 1.15,
    );
    final maxWidth = mq.size.width > 640.0 ? 640.0 : mq.size.width;

    return MediaQuery(
      data: mq.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              // Cap the column width on tablets so the layout doesn't
              // stretch the magazine hero into an awkward wide aspect.
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  40 + mq.viewPadding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              _BeatReveal(animation: _b0, child: const _PageHeader()),
              const SizedBox(height: 20),
              _BeatReveal(
                animation: _b1,
                child: _MagazineHero(
                  formScore: _sessionFormScore,
                  totalReps: _sessionTotalReps,
                  goodReps: _sessionGoodReps,
                  reports: widget.reports,
                  totalDuration: widget.totalDuration,
                  calories: widget.totalCalories,
                  streakDays: widget.streakDays,
                  heroPulse: _heroPulse,
                  onShare: widget.onShare ?? () => _stub('Chia sẻ'),
                  onShareToZalo:
                      widget.onShareToZalo ?? () => _stub('Zalo'),
                ),
              ),
              const SizedBox(height: 28),
              _BeatReveal(
                animation: _b2,
                child: _TrophyMomentCard(reports: widget.reports),
              ),
              const SizedBox(height: 28),
              _BeatReveal(
                animation: _b3,
                child: _FormArcSection(reports: widget.reports),
              ),
              const SizedBox(height: 28),
              _BeatReveal(
                animation: _b4,
                child: _ThreePillarCoach(
                  reports: widget.reports,
                  sessionFormScore: _sessionFormScore,
                ),
              ),
              if (_topIssue != null) ...[
                const SizedBox(height: 18),
                _BeatReveal(
                  animation: _b4,
                  child: _IssueCard(issue: _topIssue!),
                ),
              ],
              const SizedBox(height: 28),
              if (hasLastExercise)
                _BeatReveal(
                  animation: _b5,
                  child: DifficultyRatingBlock(
                    exerciseName: lastExerciseName,
                    eyebrow: 'BÀI CUỐI · ${lastExerciseName.toUpperCase()}',
                    selected: _lastDifficulty,
                    locked: _lastDifficulty != null,
                    onSelect: _handleLastDifficulty,
                  ),
                ),
              const SizedBox(height: 28),
              _BeatReveal(
                animation: _b6,
                child: _SectionEyebrow(
                  label: 'CHI TIẾT TỪNG BÀI',
                  meta: '${widget.reports.length} BÀI',
                ),
              ),
              const SizedBox(height: 14),
              _BeatReveal(
                animation: _b6,
                child: _VisualStatsGrid(reports: widget.reports),
              ),
              const SizedBox(height: 28),
              _BeatReveal(
                animation: _b7,
                child: _SessionRpeBlock(
                  selected: _sessionRpe,
                  onSelect: _handleSessionRpe,
                ),
              ),
              const SizedBox(height: 28),
              _BeatReveal(
                animation: _b8,
                child: _DoneCta(
                  enabled: _isDoneEnabled,
                  shimmer: _shimmer,
                  onTap: widget.onDone,
                ),
              ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _stub(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label sẽ được bật ở bản sau.')),
    );
  }
}

// ─── Beat reveal ───
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

// ─── Page header ───
class _PageHeader extends StatelessWidget {
  const _PageHeader();

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
                boxShadow: [BoxShadow(color: c.yellow, blurRadius: 5)],
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
                color: c.inkSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Xong rồi.',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 48,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            height: 1.0,
            letterSpacing: -2.4,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
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
            const SizedBox(width: 10),
            Text(
              'Cuộn xem AI đã nhìn thấy gì.',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.1,
                color: c.inkSoft,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MAGAZINE HERO — print-poster layout. Big italic score on the
// right, eyebrow + headline + sparkline DNA on the left. Tabular
// stats and dual share CTAs at the bottom.
// ═══════════════════════════════════════════════════════════════

class _MagazineHero extends StatelessWidget {
  const _MagazineHero({
    required this.formScore,
    required this.totalReps,
    required this.goodReps,
    required this.reports,
    required this.totalDuration,
    required this.calories,
    required this.streakDays,
    required this.heroPulse,
    required this.onShare,
    required this.onShareToZalo,
  });

  final int formScore;
  final int totalReps;
  final int goodReps;
  final List<ExerciseSessionReport> reports;
  final Duration totalDuration;
  final int calories;
  final int streakDays;
  final AnimationController heroPulse;
  final VoidCallback onShare;
  final VoidCallback onShareToZalo;

  String get _headline => formScore >= 90
      ? 'Form đỉnh.'
      : formScore >= 78
          ? 'Form chắc.'
          : formScore >= 65
              ? 'Đang vào nhịp.'
              : formScore >= 50
                  ? 'Buổi giữ form.'
                  : 'Buổi đặt nền.';

  String get _subtitle =>
      'Vika đã theo dõi mọi rep — đây là phim cuối buổi.';

  String _formatClock(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.32),
            blurRadius: 56,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: heroPulse,
        builder: (context, _) {
          return Stack(
            children: [
              // Base warm-dark gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-0.8, -1),
                      end: const Alignment(0.8, 1),
                      colors: [c.bgInverse, c.bgInverseHi],
                    ),
                  ),
                ),
              ),
              // Pulsing yellow ambient glow top-right
              Positioned(
                top: -120,
                right: -100,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.65 + (heroPulse.value * 0.25),
                    child: SizedBox(
                      width: 420,
                      height: 420,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              c.yellow.withValues(alpha: 0.22),
                              c.yellow.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Amber bottom-left bloom
              Positioned(
                bottom: -180,
                left: -130,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 420,
                    height: 360,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [Color(0x44CD7C45), Color(0x00CD7C45)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Grain
              Positioned.fill(
                child: CustomPaint(painter: const _HeroGrainPainter()),
              ),
              // Big italic score on the right — bleeds slightly off-edge
              Positioned(
                top: 38,
                right: -18,
                child: IgnorePointer(
                  child: Text(
                    '$formScore',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 220,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -14,
                      height: 0.85,
                      color: c.invInk.withValues(alpha: 0.06),
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                ),
              ),
              // Foreground content
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.yellow.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: c.yellow.withValues(alpha: 0.42),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: c.yellow,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: c.yellow, blurRadius: 5),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'VIKA · BUỔI TẬP',
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.6,
                                  color: c.yellow,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatHeroDate(DateTime.now()).toUpperCase(),
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
                    const SizedBox(height: 48),
                    // Headline + subtitle
                    Text(
                      _headline,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        height: 0.96,
                        letterSpacing: -2.4,
                        color: c.invInk,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 2,
                          margin: const EdgeInsets.only(top: 8),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                              letterSpacing: -0.2,
                              color: c.invInkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Session DNA sparkline strip
                    _SessionDnaStrip(reports: reports),
                    const SizedBox(height: 22),
                    // Tabular stats grid
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _HeroStat(
                              label: 'BÀI',
                              value: '${reports.length}',
                            ),
                          ),
                          _HeroDivider(),
                          Expanded(
                            child: _HeroStat(
                              label: 'REPS',
                              value: '$goodReps/$totalReps',
                            ),
                          ),
                          _HeroDivider(),
                          Expanded(
                            child: _HeroStat(
                              label: 'GIỜ',
                              value: _formatClock(totalDuration),
                            ),
                          ),
                          _HeroDivider(),
                          Expanded(
                            child: _HeroStat(
                              label: 'KCAL',
                              value: '~$calories',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroAction(
                            onTap: onShare,
                            icon: Icons.edit_outlined,
                            label: 'Chỉnh ảnh & chia sẻ',
                            primary: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _HeroAction(
                          onTap: onShareToZalo,
                          label: 'Zalo',
                          primary: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroGrainPainter extends CustomPainter {
  const _HeroGrainPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(1402);
    final p = Paint();
    for (var i = 0; i < 200; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      p.color = Colors.white.withValues(alpha: 0.015 + rng.nextDouble() * 0.02);
      canvas.drawCircle(Offset(x, y), 0.7, p);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroGrainPainter old) => false;
}

class _SessionDnaStrip extends StatelessWidget {
  const _SessionDnaStrip({required this.reports});
  final List<ExerciseSessionReport> reports;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final scores = reports.map((r) => r.formScore).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SESSION DNA',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: c.invInkFaint,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${scores.length} ĐIỂM',
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
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: CustomPaint(
            size: Size.infinite,
            painter: _DnaPainter(
              scores: scores,
              color: c.yellow,
              dim: c.invInkFaint,
            ),
          ),
        ),
      ],
    );
  }
}

class _DnaPainter extends CustomPainter {
  const _DnaPainter({
    required this.scores,
    required this.color,
    required this.dim,
  });
  final List<int> scores;
  final Color color;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;
    final baseline = size.height - 4;
    final cap = 6.0;
    final usable = size.height - cap - 8;
    final n = scores.length;
    final step = size.width / math.max(n, 2);

    // Faint horizontal axis
    final axis = Paint()
      ..color = dim.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, baseline), Offset(size.width, baseline), axis);

    // Bars + dots
    for (var i = 0; i < n; i++) {
      final s = scores[i].clamp(0, 100).toDouble();
      final h = (s / 100) * usable;
      final cx = step * (i + 0.5);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 6, baseline - h, 12, h),
        const Radius.circular(3),
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.35),
          ],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);

      // Dot at top
      final dot = Paint()..color = color.withValues(alpha: 0.95);
      canvas.drawCircle(Offset(cx, baseline - h - 2), 3.2, dot);
      final dotGlow = Paint()..color = color.withValues(alpha: 0.35);
      canvas.drawCircle(Offset(cx, baseline - h - 2), 7, dotGlow);
    }
  }

  @override
  bool shouldRepaint(covariant _DnaPainter old) =>
      old.scores != scores || old.color != color || old.dim != dim;
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
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
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
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

class _HeroDivider extends StatelessWidget {
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

class _HeroAction extends StatefulWidget {
  const _HeroAction({
    required this.onTap,
    required this.label,
    required this.primary,
    this.icon,
  });
  final VoidCallback onTap;
  final String label;
  final bool primary;
  final IconData? icon;

  @override
  State<_HeroAction> createState() => _HeroActionState();
}

class _HeroActionState extends State<_HeroAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final bg = widget.primary
        ? c.yellow
        : Colors.white.withValues(alpha: 0.06);
    final fg = widget.primary ? c.yellowInk : c.invInk;
    final border =
        widget.primary ? c.yellow : Colors.white.withValues(alpha: 0.12);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
            boxShadow: widget.primary
                ? [
                    BoxShadow(
                      color: c.yellow.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.2,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatHeroDate(DateTime dt) {
  const months = [
    'Th 1', 'Th 2', 'Th 3', 'Th 4', 'Th 5', 'Th 6',
    'Th 7', 'Th 8', 'Th 9', 'Th 10', 'Th 11', 'Th 12',
  ];
  return '${dt.day} ${months[dt.month - 1]}';
}

// ═══════════════════════════════════════════════════════════════
// TROPHY MOMENT — single-stat celebration card.
// Big number, big icon, big italic.
// ═══════════════════════════════════════════════════════════════

class _TrophyMomentCard extends StatelessWidget {
  const _TrophyMomentCard({required this.reports});
  final List<ExerciseSessionReport> reports;

  /// NOTE(wiring): real "highlight picker" examining reports + history.
  ({String label, String value, IconData icon, String tag})
      _pickHighlight() {
    if (reports.isEmpty) {
      return (
        label: 'Có mặt là thắng rồi',
        value: '01',
        icon: Icons.bolt_rounded,
        tag: 'CHECK-IN',
      );
    }
    final best = reports.reduce((a, b) => a.formScore >= b.formScore ? a : b);
    final totalGood =
        reports.fold<int>(0, (s, r) => s + r.goodReps);
    if (best.formScore >= 88) {
      return (
        label: '${best.exerciseName} sạch như nước',
        value: '${best.formScore}',
        icon: Icons.workspace_premium_rounded,
        tag: 'FORM ĐỈNH',
      );
    }
    if (totalGood >= 30) {
      return (
        label: 'rep đúng form trong buổi này',
        value: '$totalGood',
        icon: Icons.local_fire_department_rounded,
        tag: 'KHỐI LƯỢNG',
      );
    }
    return (
      label: 'bài đã hoàn thành — kiên trì',
      value: '${reports.length}',
      icon: Icons.flag_rounded,
      tag: 'KIÊN TRÌ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final highlight = _pickHighlight();
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.yellow.withValues(alpha: 0.13),
            c.yellow.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: c.yellow.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.yellow.withValues(alpha: 0.5),
                      blurRadius: 14,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(highlight.icon, size: 14, color: c.yellowInk),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.yellow.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: c.yellow.withValues(alpha: 0.4)),
                ),
                child: Text(
                  highlight.tag,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: c.ink,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'KHOẢNH KHẮC',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.7,
                  color: c.inkFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // FittedBox + max-width cap so a long stat value (e.g.
              // 3-digit good-rep count "100" + visual width) never
              // pushes the right-hand label off-screen on small phones.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    highlight.value,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 100,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -5,
                      height: 0.88,
                      color: c.ink,
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    highlight.label,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                      letterSpacing: -0.3,
                      color: c.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FORM ARC — mountain chart connecting form score across exercises.
// Visual session story — instantly readable from far away.
// ═══════════════════════════════════════════════════════════════

class _FormArcSection extends StatelessWidget {
  const _FormArcSection({required this.reports});
  final List<ExerciseSessionReport> reports;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: c.yellow, blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'HÀNH TRÌNH FORM',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: c.inkFaint,
                ),
              ),
              const Spacer(),
              Text(
                '${reports.length} BÀI',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: c.inkFaint,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Form score đi như thế nào suốt buổi tập.',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              height: 1.4,
              letterSpacing: -0.1,
              color: c.inkSoft,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 168,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _FormArcPainter(
                    reports: reports,
                    progress: progress,
                    color: c.yellow,
                    ink: c.ink,
                    inkSoft: c.inkSoft,
                    inkFaint: c.inkFaint,
                    border: c.border,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FormArcPainter extends CustomPainter {
  const _FormArcPainter({
    required this.reports,
    required this.progress,
    required this.color,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.border,
  });
  final List<ExerciseSessionReport> reports;
  final double progress;
  final Color color;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    if (reports.isEmpty) return;
    final scores = reports.map((r) => r.formScore).toList();
    final padX = 28.0;
    final topY = 26.0;
    final bottomY = size.height - 32.0;
    final usableH = bottomY - topY;

    // Dashed grid lines at 25/50/75/100
    final grid = Paint()
      ..color = border
      ..strokeWidth = 1;
    for (final v in [25, 50, 75, 100]) {
      final y = bottomY - (v / 100) * usableH;
      const dash = 4.0;
      const gap = 5.0;
      double x = padX;
      while (x < size.width - padX) {
        final next = math.min(x + dash, size.width - padX);
        canvas.drawLine(Offset(x, y), Offset(next, y), grid);
        x = next + gap;
      }
      // Axis label
      _label(
        canvas,
        '$v',
        Offset(8, y),
        TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: inkFaint,
          fontFeatures: VikaIvoryMain.tabularFigures,
        ),
        anchor: _LabelAnchor.midLeft,
      );
    }

    final stepX = scores.length <= 1
        ? 0.0
        : (size.width - padX * 2) / (scores.length - 1);
    final points = <Offset>[];
    for (var i = 0; i < scores.length; i++) {
      final x = scores.length == 1
          ? size.width / 2
          : padX + stepX * i;
      final y = bottomY - (scores[i] / 100) * usableH;
      points.add(Offset(x, y));
    }

    // Smooth path
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final cx = prev.dx + (cur.dx - prev.dx) * 0.5;
      path.cubicTo(cx, prev.dy, cx, cur.dy, cur.dx, cur.dy);
    }

    // Fill
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, bottomY)
      ..lineTo(points.first.dx, bottomY)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.28 * progress),
          color.withValues(alpha: 0.05 * progress),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTRB(0, topY, size.width, bottomY));
    canvas.drawPath(fillPath, fillPaint);

    // Animated stroke (extracted by progress)
    final stroke = _extract(path, progress);
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(stroke, strokePaint);

    // Best point gets a halo + label
    final bestIdx = scores.indexOf(scores.reduce(math.max));

    // Points + labels
    final pointReveal = math.max(scores.length.toDouble(), 1.0);
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final score = scores[i];
      final pStart = i / pointReveal;
      final pProg = ((progress - pStart) * 4).clamp(0.0, 1.0);
      if (pProg <= 0) continue;
      final isBest = i == bestIdx;

      if (isBest) {
        final halo = Paint()
          ..color = color.withValues(alpha: 0.18 * pProg);
        canvas.drawCircle(p, 16, halo);
      }
      final ring = Paint()
        ..color = color.withValues(alpha: pProg)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isBest ? 3 : 2;
      canvas.drawCircle(p, isBest ? 9 : 6.5, ring);
      final core = Paint()..color = Colors.white.withValues(alpha: pProg);
      canvas.drawCircle(p, isBest ? 5 : 3.5, core);

      // Score label above
      _label(
        canvas,
        '$score',
        Offset(p.dx, p.dy - (isBest ? 22 : 18)),
        TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: isBest ? 15 : 12.5,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          letterSpacing: -0.4,
          color: ink.withValues(alpha: pProg),
          fontFeatures: VikaIvoryMain.tabularFigures,
        ),
        anchor: _LabelAnchor.midCenter,
      );

      // Exercise name below (truncated)
      final name = reports[i].exerciseName;
      final short = name.length > 8 ? '${name.substring(0, 8)}…' : name;
      _label(
        canvas,
        short.toUpperCase(),
        Offset(p.dx, bottomY + 14),
        TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: inkSoft.withValues(alpha: pProg),
        ),
        anchor: _LabelAnchor.midCenter,
      );
    }
  }

  Path _extract(Path source, double t) {
    final metrics = source.computeMetrics().toList();
    if (metrics.isEmpty) return source;
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    final target = total * t.clamp(0.0, 1.0);
    final out = Path();
    double walked = 0;
    for (final m in metrics) {
      final next = walked + m.length;
      if (target >= next) {
        out.addPath(m.extractPath(0, m.length), Offset.zero);
      } else {
        final r = (target - walked).clamp(0.0, m.length);
        out.addPath(m.extractPath(0, r), Offset.zero);
        break;
      }
      walked = next;
    }
    return out;
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    _LabelAnchor anchor = _LabelAnchor.midCenter,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    Offset origin;
    switch (anchor) {
      case _LabelAnchor.midCenter:
        origin = Offset(at.dx - painter.width / 2, at.dy - painter.height / 2);
        break;
      case _LabelAnchor.midLeft:
        origin = Offset(at.dx, at.dy - painter.height / 2);
        break;
    }
    painter.paint(canvas, origin);
  }

  @override
  bool shouldRepaint(covariant _FormArcPainter old) =>
      old.reports != reports || old.progress != progress;
}

enum _LabelAnchor { midCenter, midLeft }

// ═══════════════════════════════════════════════════════════════
// THREE-PILLAR COACH — 3 icon cards instead of text wall.
// Mạnh / Để ý / Buổi sau.
// ═══════════════════════════════════════════════════════════════

class _ThreePillarCoach extends StatelessWidget {
  const _ThreePillarCoach({
    required this.reports,
    required this.sessionFormScore,
  });
  final List<ExerciseSessionReport> reports;
  final int sessionFormScore;

  /// NOTE(wiring): real cross-exercise narrative aggregator.
  ({String strength, String watch, String next, String quote}) _pillars() {
    final strongest = reports.isEmpty
        ? '—'
        : reports
            .reduce((a, b) => a.formScore >= b.formScore ? a : b)
            .exerciseName;
    final weakest = reports.isEmpty
        ? '—'
        : reports
            .reduce((a, b) => a.formScore <= b.formScore ? a : b)
            .exerciseName;
    final quote = sessionFormScore >= 80
        ? 'Buổi này AI nhìn thấy nhịp đẹp từ đầu đến cuối — bạn đã giữ form ổn định ở những set khó nhất.'
        : sessionFormScore >= 65
            ? 'Buổi này có điểm sáng rõ và vài chỗ AI muốn bạn để ý buổi sau — đừng vội nâng tải.'
            : 'Đây là buổi đặt nền. Lặp lại đều, form sẽ chắc dần — Vika sẽ giảm nhẹ ngưỡng nếu cần.';
    return (
      strength: 'Form $strongest trong sáng',
      watch: '$weakest cần nhịp chậm hơn',
      next: 'Giữ rep mục tiêu, nhịp xuống ổn định',
      quote: quote,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final p = _pillars();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    'Phiên đánh giá cuối buổi',
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
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(color: c.yellow, width: 3),
              ),
            ),
            child: Text(
              p.quote,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                height: 1.55,
                letterSpacing: -0.1,
                color: c.ink,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // IntrinsicHeight gives the Row a bounded height so stretch can
          // equalize the pillars without forcing an infinite constraint.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CoachPillar(
                    icon: Icons.bolt_rounded,
                    label: 'ĐIỂM MẠNH',
                    body: p.strength,
                    accent: c.yellow,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CoachPillar(
                    icon: Icons.center_focus_strong_rounded,
                    label: 'ĐỂ Ý',
                    body: p.watch,
                    accent: c.attention,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CoachPillar(
                    icon: Icons.east_rounded,
                    label: 'BUỔI SAU',
                    body: p.next,
                    accent: c.ink,
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

class _CoachPillar extends StatelessWidget {
  const _CoachPillar({
    required this.icon,
    required this.label,
    required this.body,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accent.withValues(alpha: 0.4),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 13, color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: c.inkFaint,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              height: 1.4,
              letterSpacing: -0.2,
              color: c.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Issue card (top issue across all exercises) ───
class _IssueCard extends StatefulWidget {
  const _IssueCard({required this.issue});
  final DetectedEvidence issue;
  @override
  State<_IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<_IssueCard> {
  String? _answer;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final attention = c.attention;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            attention.withValues(alpha: 0.06),
            attention.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: attention.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.center_focus_strong_rounded,
                  size: 14, color: attention),
              const SizedBox(width: 8),
              Text(
                'AI PHÁT HIỆN',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: attention,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.issue.question,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              height: 1.45,
              letterSpacing: -0.3,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _IssueAnswer(
                  label: 'Có',
                  selected: _answer == 'yes',
                  primary: true,
                  onTap: () => setState(() => _answer = 'yes'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IssueAnswer(
                  label: 'Không',
                  selected: _answer == 'no',
                  primary: false,
                  onTap: () => setState(() => _answer = 'no'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IssueAnswer extends StatelessWidget {
  const _IssueAnswer({
    required this.label,
    required this.selected,
    required this.primary,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool primary;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final selectedBg = primary ? c.ink : c.ink;
    final selectedFg = primary ? c.yellow : c.yellow;
    final bg = selected ? selectedBg : c.bgRaised;
    final fg = selected ? selectedFg : c.ink;
    final borderColor =
        selected ? (primary ? c.ink : c.ink) : c.border;
    // Material + InkWell so hit testing is delegated to the framework's
    // standard button stack. The previous GestureDetector-inside-
    // AnimatedContainer setup occasionally failed to receive the second
    // tap when only the bg color changed between frames.
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: c.ink.withValues(alpha: 0.1),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.2,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Section eyebrow ───
class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({required this.label, this.meta});
  final String label;
  final String? meta;
  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      children: [
        Container(
          width: 5,
          height: 22,
          decoration: BoxDecoration(
            color: c.yellow,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: c.ink,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Container(height: 1, color: c.border)),
        if (meta != null) ...[
          const SizedBox(width: 14),
          Text(
            meta!,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: c.inkFaint,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// VISUAL STATS GRID — per-exercise rows with horizontal form bars
// and a mini per-set sparkline. Card 1 also displays the exercise
// number medallion.
// ═══════════════════════════════════════════════════════════════

class _VisualStatsGrid extends StatelessWidget {
  const _VisualStatsGrid({required this.reports});
  final List<ExerciseSessionReport> reports;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < reports.length; i++) ...[
          _VisualStatCard(report: reports[i], index: i),
          if (i < reports.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _VisualStatCard extends StatelessWidget {
  const _VisualStatCard({required this.report, required this.index});
  final ExerciseSessionReport report;
  final int index;

  String _formatClock(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _difficultyLabel(String? d) {
    return switch (d) {
      'light' => 'Nhẹ',
      'medium' => 'Vừa',
      'heavy' => 'Nặng',
      _ => 'Chưa đánh giá',
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final score = report.formScore;
    final scoreColor = score >= 78
        ? c.yellow
        : score >= 60
            ? c.ink
            : c.attention;
    final setScores =
        report.report.sets.map((s) => s.score).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: medallion + name + score
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.border, width: 1.2),
                ),
                alignment: Alignment.center,
                child: Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.5,
                    color: c.ink,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
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
                    const SizedBox(height: 2),
                    Text(
                      '${report.report.sets.length} hiệp · ${report.goodReps}/${report.totalReps} reps · ${_formatClock(report.duration)}',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: c.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FORM',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: c.inkFaint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$score',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      height: 1,
                      letterSpacing: -1.6,
                      color: scoreColor,
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Form score bar
          _FormBar(score: score, accent: scoreColor),
          const SizedBox(height: 14),
          // Set sparkline + difficulty
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _SetSparkPainter(
                      scores: setScores,
                      accent: scoreColor,
                      dim: c.inkFaint,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 11,
                      color: c.inkSoft,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _difficultyLabel(report.userDifficulty),
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.2,
                        color: c.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormBar extends StatelessWidget {
  const _FormBar({required this.score, required this.accent});
  final int score;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Stack(
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: c.border, width: 1),
          ),
        ),
        FractionallySizedBox(
          widthFactor: (score.clamp(0, 100) / 100),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) {
              return Container(
                height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.55 * t),
                      accent.withValues(alpha: 1.0 * t),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35 * t),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Tick marks at 25/50/75
        Positioned.fill(
          child: LayoutBuilder(builder: (context, constraints) {
            return Stack(
              children: [
                for (final v in const [0.25, 0.5, 0.75])
                  Positioned(
                    left: constraints.maxWidth * v - 0.5,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1,
                      color: c.ink.withValues(alpha: 0.06),
                    ),
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }
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
    final padX = 6.0;
    final topY = 6.0;
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
    // Line
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    final line = Paint()
      ..color = accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, line);
    // Dots + labels
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      canvas.drawCircle(
        p,
        3,
        Paint()..color = accent.withValues(alpha: 0.95),
      );
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
      lp.paint(canvas, Offset(p.dx - lp.width / 2, bottomY + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SetSparkPainter old) =>
      old.scores != scores ||
      old.accent != accent ||
      old.dim != dim;
}

// ─── Session RPE block ───
class _SessionRpeBlock extends StatelessWidget {
  const _SessionRpeBlock({
    required this.selected,
    required this.onSelect,
  });
  final String? selected;
  final ValueChanged<String> onSelect;

  static const _opts = [
    (id: 'easy', label: 'Dễ', meter: 1),
    (id: 'sustainable', label: 'Vừa sức', meter: 2),
    (id: 'hard', label: 'Nặng', meter: 3),
    (id: 'brutal', label: 'Cháy', meter: 4),
  ];

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: c.yellow, blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'CẢM GIÁC CẢ BUỔI',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: c.inkFaint,
                ),
              ),
              const Spacer(),
              if (selected != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.yellowGhost,
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: c.yellow.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 11, color: c.ink),
                      const SizedBox(width: 4),
                      Text(
                        'ĐÃ GHI NHẬN',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: c.ink,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tổng thể buổi tập này thế nào?',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              height: 1.3,
              letterSpacing: -0.5,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < _opts.length; i++) ...[
                Expanded(
                  child: _RpeTile(
                    label: _opts[i].label,
                    meter: _opts[i].meter,
                    selected: selected == _opts[i].id,
                    locked: selected != null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(_opts[i].id);
                    },
                  ),
                ),
                if (i < _opts.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RpeTile extends StatelessWidget {
  const _RpeTile({
    required this.label,
    required this.meter,
    required this.selected,
    required this.locked,
    required this.onTap,
  });
  final String label;
  final int meter;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final disabled = locked && !selected;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: disabled ? 0.35 : 1.0,
        duration: const Duration(milliseconds: 220),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          decoration: BoxDecoration(
            color: selected ? c.yellow : c.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? c.yellow : c.border,
              width: 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: c.yellow.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 4; i++) ...[
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= meter
                            ? (selected ? c.yellowInk : c.ink)
                            : (selected
                                ? c.yellowInk.withValues(alpha: 0.25)
                                : c.inkFaint.withValues(alpha: 0.4)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i < 4) const SizedBox(width: 2),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.3,
                  color: selected ? c.yellowInk : c.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Done CTA ───
class _DoneCta extends StatefulWidget {
  const _DoneCta({
    required this.enabled,
    required this.shimmer,
    required this.onTap,
  });
  final bool enabled;
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
    final disabled = !widget.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedOpacity(
          opacity: disabled ? 0.4 : 1.0,
          duration: const Duration(milliseconds: 220),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: disabled
                ? null
                : () {
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
                      boxShadow: disabled
                          ? null
                          : [
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
                          if (!disabled)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin:
                                        Alignment(-1.6 + (v * 3.2), -1),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Hoàn thành buổi tập',
                                  style: TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                    letterSpacing: -0.3,
                                    color: c.yellowInk,
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
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            disabled
                ? 'Trả lời 2 câu phía trên để hoàn tất'
                : 'Hẹn buổi sau 👋',
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
