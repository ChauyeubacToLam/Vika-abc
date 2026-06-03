// RestScreen — between-sets pause. Premium Ivory v2.
//
// Data wiring is identical to the legacy jade-green version (same
// constructor params, same SetReportData, same difficulty mechanic,
// same fault grouping from ExerciseLogger). Only the visual grammar
// changed: cream / ink / yellow editorial palette, italic display
// typography, refined ring, no emojis.
//
// Layout:
//   ┌────────────────────────────────────────────┐
//   │ ✕              HIỆP 02 / 03 · Squat        │  ← editorial header
//   │                                             │
//   │             ╱ ─ ─ ─ ╲                      │
//   │            │   42    │   ← yellow arc      │
//   │            │  GIÂY   │     + italic 96pt   │
//   │             ╲ _ _ _ ╱                      │
//   │                                             │
//   │           8 / 10 reps chuẩn form            │  ← italic display
//   │        ●●●●●●●●○○                            │  ← rep dots
//   │                                             │
//   │      ✦ "Đẹp lắm — giữ form sạch như thế."   │  ← praise
//   │                                             │
//   │      ◆  GỢI Ý CHO SET SAU                   │
//   │      Dồn lực qua gót, giữ bàn chân          │  ← coach tip
//   │      bám sàn chắc hơn nhé.                  │
//   │                                             │
//   │      Cần cải thiện (2)  ▾                   │  ← faults
//   │                                             │
//   ├ ─────────────────────────────────────── ──┤
//   │       SET NÀY THẾ NÀO?                     │
//   │   [ Nhẹ ]  [ Vừa ]  [ Nặng ]               │  ← italic pills
//   │       Set sau tăng 2 reps                  │  ← adjustment
//   │                                             │
//   │   [ Bắt đầu set tiếp                  → ]  │  ← yellow halo CTA
//   └────────────────────────────────────────────┘

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/post_exercise_data.dart';
import '../../services/session_persistence.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../../utils/exercise_logger.dart';

class RestScreen extends StatefulWidget {
  const RestScreen({
    super.key,
    required this.setReport,
    required this.setIndex,
    required this.totalSets,
    required this.currentReps,
    required this.baseRestSeconds,
    required this.isLastSet,
    required this.onNext,
    this.onDifficultyAnswer,
    this.setLogger,
    this.previousSession,
  });

  final SetReportData setReport;
  final int setIndex;
  final int totalSets;
  final int currentReps;
  final int baseRestSeconds;
  final bool isLastSet;
  final VoidCallback onNext;
  final void Function(String difficulty)? onDifficultyAnswer;
  final ExerciseLogger? setLogger;
  final List<PreviousSessionSummary>? previousSession;

  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> with TickerProviderStateMixin {
  Timer? _timer;
  String? _selectedDifficulty;
  bool _showFaults = false;
  bool _didAdvance = false;
  late int _restDuration;
  late int _remaining;
  late final AnimationController _dotController;
  late final List<CurvedAnimation> _dotAnimations;

  List<_FaultObservation> get _faultObservations =>
      _groupFaultObservations(widget.setLogger);

  bool get _lockedDifficulty => _selectedDifficulty != null;

  double get _progress {
    if (_restDuration == 0) return 1;
    return (1 - (_remaining / _restDuration)).clamp(0.0, 1.0).toDouble();
  }

  String get _exerciseLabel {
    final loggerLabel = widget.setLogger?.setLogs['exercise_name'];
    if (loggerLabel is String && loggerLabel.trim().isNotEmpty) {
      return loggerLabel.trim();
    }
    final altLabel = widget.setLogger?.setLogs['exerciseName'];
    if (altLabel is String && altLabel.trim().isNotEmpty) {
      return altLabel.trim();
    }
    return 'Squat';
  }

  @override
  void initState() {
    super.initState();
    _restDuration = widget.isLastSet ? 10 : widget.baseRestSeconds;
    _remaining = _restDuration;
    _dotController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            math.max(680, 320 + (widget.setReport.repResults.length * 40)),
      ),
    )..forward();
    _dotAnimations = List.generate(
      widget.setReport.repResults.length,
      (i) {
        final start = (i * 0.04).clamp(0.0, 0.82).toDouble();
        final end = (start + 0.24).clamp(start + 0.01, 1.0).toDouble();
        return CurvedAnimation(
          parent: _dotController,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        );
      },
    );
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final anim in _dotAnimations) {
      anim.dispose();
    }
    _dotController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _advance();
        return;
      }
      setState(() => _remaining -= 1);
    });
  }

  void _advance() {
    if (_didAdvance) return;
    _didAdvance = true;
    _timer?.cancel();
    HapticFeedback.lightImpact();
    widget.onNext();
  }

  void _selectDifficulty(String difficulty) {
    if (_lockedDifficulty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDifficulty = difficulty;
      if (difficulty == 'heavy') {
        _restDuration += 15;
        _remaining += 15;
      }
    });
    widget.onDifficultyAnswer?.call(difficulty);
  }

  String? get _adjustmentText {
    if (_selectedDifficulty == null || widget.isLastSet) return null;
    return switch (_selectedDifficulty!) {
      'light' => 'Set sau tăng 2 reps',
      'medium' => 'Set sau giữ ${widget.currentReps} reps',
      'heavy' => '+15s nghỉ · Set sau giảm 1 rep',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final goodReps = widget.setReport.goodReps ??
        widget.setReport.repResults.where((isGood) => isGood).length;
    final totalReps = widget.setReport.totalReps ?? widget.currentReps;
    return Scaffold(
      backgroundColor: c.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              c.bgRaised,
              c.bg,
            ],
            stops: const [0.0, 0.55],
          ),
        ),
        child: Stack(
          children: [
            // Soft yellow halo behind the timer.
            Positioned(
              top: -120,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 380,
                    height: 380,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          c.yellow.withValues(alpha: 0.18),
                          c.yellow.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.04,
                  child: CustomPaint(painter: _PaperGrainPainter()),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            math.max(0, constraints.maxHeight - 32).toDouble(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _TopBar(
                            setIndex: widget.setIndex,
                            totalSets: widget.totalSets,
                            exerciseLabel: _exerciseLabel,
                            onClose: _advance,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              children: [
                                _TimerRing(
                                  progress: _progress,
                                  remaining: _remaining,
                                ),
                                const SizedBox(height: 22),
                                _ScoreLine(
                                  goodReps: goodReps,
                                  totalReps: totalReps,
                                ),
                                if (widget.setReport.repResults.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (var i = 0;
                                          i <
                                              widget
                                                  .setReport.repResults.length;
                                          i++)
                                        _RepResultDot(
                                          isGood:
                                              widget.setReport.repResults[i],
                                          animation: _dotAnimations[i],
                                        ),
                                    ],
                                  ),
                                ],
                                if ((widget.setReport.praiseSentence ?? '')
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  _PraiseLine(
                                    text: widget.setReport.praiseSentence!,
                                  ),
                                ],
                                if ((widget.setReport.coachTip ?? '')
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 340),
                                    child: _CoachTipCard(
                                      text: widget.setReport.coachTip!,
                                    ),
                                  ),
                                ],
                                if (_faultObservations.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  _FaultsToggle(
                                    open: _showFaults,
                                    count: _faultObservations.length,
                                    onTap: () => setState(
                                        () => _showFaults = !_showFaults),
                                  ),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                    child: _showFaults
                                        ? Padding(
                                            padding:
                                                const EdgeInsets.only(top: 10),
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 340,
                                              ),
                                              child: Column(
                                                children: [
                                                  for (final fault
                                                      in _faultObservations)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 8),
                                                      child: _FaultRow(
                                                        fault: fault,
                                                        totalReps: totalReps,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _BottomSection(
                            selectedDifficulty: _selectedDifficulty,
                            lockedDifficulty: _lockedDifficulty,
                            adjustmentText: _adjustmentText,
                            isLastSet: widget.isLastSet,
                            onSelectDifficulty: _selectDifficulty,
                            onAdvance: _advance,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TOP BAR — editorial header: close + italic "Hiệp X / Y · Name"
// ═══════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.setIndex,
    required this.totalSets,
    required this.exerciseLabel,
    required this.onClose,
  });

  final int setIndex;
  final int totalSets;
  final String exerciseLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      children: [
        _CloseButton(onTap: onClose),
        const Spacer(),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
          decoration: BoxDecoration(
            color: c.yellow.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: c.yellow.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HIỆP ${(setIndex + 1).toString().padLeft(2, '0')} / ${totalSets.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: c.inkSoft,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: c.inkFaint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                exerciseLabel,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.2,
                  color: c.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: c.bgRaised,
            shape: BoxShape.circle,
            border: Border.all(color: c.border),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.close_rounded,
            size: 17,
            color: c.inkSoft,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TIMER RING — single clean ring + halo + big italic numeral
// ═══════════════════════════════════════════════════════════════

class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.progress, required this.remaining});

  final double progress;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft glow ring behind the arc.
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  c.yellow.withValues(alpha: 0.10),
                  c.yellow.withValues(alpha: 0),
                ],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
          // The arc.
          Positioned.fill(
            child: CustomPaint(
              painter: _TimerArcPainter(
                progress: progress,
                trackColor: c.border,
                fillColor: c.yellow,
              ),
            ),
          ),
          // Inside: italic seconds + "GIÂY NGHỈ" eyebrow.
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$remaining',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 92,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -4.5,
                  height: 0.92,
                  color: c.ink,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 18,
                height: 1.5,
                color: c.yellow.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 8),
              Text(
                'GIÂY NGHỈ',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                  color: c.inkSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimerArcPainter extends CustomPainter {
  _TimerArcPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  final double progress; // 0..1
  final Color trackColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 10;
    const stroke = 8.0;

    // Track — full circle, hairline cream.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = trackColor,
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
          ..color = trackColor
          ..strokeWidth = 1,
      );
    }

    if (progress <= 0.001) return;

    // Yellow fill arc — sweep from top clockwise.
    final sweep = progress.clamp(0.0, 1.0) * 2 * math.pi;
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: [
          fillColor.withValues(alpha: 0.5),
          fillColor,
          fillColor,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
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
        ..color = fillColor.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(tip, stroke / 2 + 1, Paint()..color = fillColor);
  }

  @override
  bool shouldRepaint(covariant _TimerArcPainter old) =>
      old.progress != progress ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor;
}

// ═══════════════════════════════════════════════════════════════
// SCORE LINE — italic display "8 / 10 reps chuẩn form"
// ═══════════════════════════════════════════════════════════════

class _ScoreLine extends StatelessWidget {
  const _ScoreLine({required this.goodReps, required this.totalReps});
  final int goodReps;
  final int totalReps;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$goodReps',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 38,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: -1.8,
                height: 0.95,
                color: c.ink,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '/ $totalReps',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.4,
                color: c.inkSoft,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'REPS CHUẨN FORM',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: c.inkSoft,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// REP RESULT DOT — yellow check / hairline outline
// ═══════════════════════════════════════════════════════════════

class _RepResultDot extends StatelessWidget {
  const _RepResultDot({required this.isGood, required this.animation});

  final bool isGood;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    const size = 22.0;
    return ScaleTransition(
      scale: animation,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isGood ? c.yellow : Colors.transparent,
          border: Border.all(
            color: isGood ? c.yellow : c.borderHi,
            width: isGood ? 0 : 2,
          ),
          boxShadow: isGood
              ? [
                  BoxShadow(
                    color: c.yellow.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: isGood
            ? Icon(
                Icons.check_rounded,
                size: 12,
                color: c.yellowInk,
              )
            : null,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PRAISE — italic editorial quote with sparkle prefix
// ═══════════════════════════════════════════════════════════════

class _PraiseLine extends StatelessWidget {
  const _PraiseLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox.square(
              dimension: 12,
              child: CustomPaint(painter: _SparklePainter(color: c.yellow)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '"$text"',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.2,
                height: 1.5,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.58, h * 0.42)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.58, h * 0.58)
      ..lineTo(w * 0.5, h)
      ..lineTo(w * 0.42, h * 0.58)
      ..lineTo(0, h * 0.5)
      ..lineTo(w * 0.42, h * 0.42)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.color != color;
}

// ═══════════════════════════════════════════════════════════════
// COACH TIP — yellow ghost card with coach mark + italic text
// ═══════════════════════════════════════════════════════════════

class _CoachTipCard extends StatelessWidget {
  const _CoachTipCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.yellowGhost,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.yellow.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CoachMark(yellow: c.yellow, ink: c.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GỢI Ý CHO SET SAU',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: c.inkSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.1,
                    height: 1.5,
                    color: c.ink,
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

class _CoachMark extends StatelessWidget {
  const _CoachMark({required this.yellow, required this.ink});
  final Color yellow;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _CoachPainter(yellow: yellow, ink: ink)),
    );
  }
}

class _CoachPainter extends CustomPainter {
  const _CoachPainter({required this.yellow, required this.ink});
  final Color yellow;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 18;
    Offset p(double x, double y) => Offset(x * scale, y * scale);
    canvas.drawCircle(p(9, 9), 8.5 * scale, Paint()..color = yellow);
    canvas.drawCircle(
      p(9, 9),
      8.5 * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * scale
        ..color = ink,
    );
    final inkPaint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(p(9, 5.5), 1.1 * scale, Paint()..color = ink);
    canvas.drawLine(p(9, 6.6), p(9, 10), inkPaint);
    canvas.drawLine(p(6.5, 8), p(11.5, 8), inkPaint);
    canvas.drawLine(p(9, 10), p(7.5, 13), inkPaint);
    canvas.drawLine(p(9, 10), p(10.5, 13), inkPaint);
  }

  @override
  bool shouldRepaint(covariant _CoachPainter old) =>
      old.yellow != yellow || old.ink != ink;
}

// ═══════════════════════════════════════════════════════════════
// FAULTS — collapsible, ink-soft (no red)
// ═══════════════════════════════════════════════════════════════

class _FaultsToggle extends StatelessWidget {
  const _FaultsToggle({
    required this.open,
    required this.count,
    required this.onTap,
  });
  final bool open;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            open
                ? Icons.keyboard_arrow_down_rounded
                : Icons.keyboard_arrow_right_rounded,
            size: 16,
            color: c.inkFaint,
          ),
          const SizedBox(width: 4),
          Text(
            'Cần cải thiện ($count)',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.1,
              color: c.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaultRow extends StatelessWidget {
  const _FaultRow({required this.fault, required this.totalReps});
  final _FaultObservation fault;
  final int totalReps;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: c.inkSoft,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fault.title,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: c.inkSoft,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: c.border),
            ),
            child: Text(
              '${fault.reps.length} / $totalReps',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
                color: c.inkFaint,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BOTTOM SECTION — difficulty pills + adjustment + CTA
// ═══════════════════════════════════════════════════════════════

class _BottomSection extends StatelessWidget {
  const _BottomSection({
    required this.selectedDifficulty,
    required this.lockedDifficulty,
    required this.adjustmentText,
    required this.isLastSet,
    required this.onSelectDifficulty,
    required this.onAdvance,
  });

  final String? selectedDifficulty;
  final bool lockedDifficulty;
  final String? adjustmentText;
  final bool isLastSet;
  final ValueChanged<String> onSelectDifficulty;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    const options = [
      (id: 'light', label: 'Nhẹ'),
      (id: 'medium', label: 'Vừa'),
      (id: 'heavy', label: 'Nặng'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SET NÀY THẾ NÀO?',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: c.inkSoft,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _DifficultyOption(
                  label: options[i].label,
                  selected: selectedDifficulty == options[i].id,
                  locked: lockedDifficulty,
                  onTap: () => onSelectDifficulty(options[i].id),
                ),
              ),
            ],
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: adjustmentText == null
              ? const SizedBox(height: 14, key: ValueKey('empty-adjustment'))
              : Padding(
                  key: ValueKey(adjustmentText),
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 12,
                        color: c.yellow,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        adjustmentText!,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.1,
                          color: c.ink,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 14),
        _CtaButton(
          label: isLastSet ? 'Xem tổng kết' : 'Bắt đầu set tiếp',
          onTap: onAdvance,
        ),
      ],
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  const _DifficultyOption({
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final dimmed = locked && !selected;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: dimmed ? 0.32 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected ? c.ink : c.bgRaised,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? c.ink : c.border,
                width: 1.2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: c.ink.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.3,
                  color: selected ? c.yellow : c.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatefulWidget {
  const _CtaButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 0, 6, 0),
          height: 56,
          decoration: BoxDecoration(
            color: c.yellow,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: c.yellow.withValues(alpha: 0.36),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: c.yellow.withValues(alpha: 0.18),
                blurRadius: 60,
                offset: const Offset(0, 26),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: c.yellowInk,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: c.yellow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PAPER GRAIN — kept from the legacy screen, retoned to ink.
// ═══════════════════════════════════════════════════════════════

class _PaperGrainPainter extends CustomPainter {
  const _PaperGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1F1812)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 1500; i++) {
      final x = _noise(i * 0.17) * size.width;
      final y = _noise((i * 0.31) + 17) * size.height;
      final dotSize = 0.35 + (_noise((i * 0.13) + 43) * 0.9);
      canvas.drawRect(Rect.fromLTWH(x, y, dotSize, dotSize), paint);
    }
  }

  double _noise(double seed) {
    final value = math.sin(seed * 12.9898) * 43758.5453;
    return value - value.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════
// FAULT GROUPING — identical to the legacy version. Pure data
// transform from ExerciseLogger.repLogs.
// ═══════════════════════════════════════════════════════════════

class _FaultObservation {
  const _FaultObservation({
    required this.type,
    required this.title,
    required this.tip,
    required this.reps,
  });
  final String type;
  final String title;
  final String tip;
  final List<int> reps;
}

List<_FaultObservation> _groupFaultObservations(ExerciseLogger? logger) {
  if (logger == null) return const [];
  final groups = <String, List<int>>{};
  for (final rep in logger.repLogs) {
    final faultTypes = (rep.data['fault_types'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toSet();
    for (final type in faultTypes) {
      groups.putIfAbsent(type, () => <int>[]).add(rep.repNumber);
    }
  }
  final mapped = groups.entries.map((entry) {
    final copy = [...entry.value]..sort();
    final meta = _faultMeta(entry.key);
    return _FaultObservation(
      type: entry.key,
      title: meta.title,
      tip: meta.tip,
      reps: copy,
    );
  }).toList()
    ..sort((a, b) => b.reps.length.compareTo(a.reps.length));
  return mapped;
}

({String title, String tip}) _faultMeta(String type) {
  return switch (type) {
    'Back' => (
        title: 'Lưng nghiêng',
        tip: 'Giữ ngực mở và hông lùi nhẹ để thân trên ổn định nhé.',
      ),
    'Feet' => (
        title: 'Gót chân nhấc',
        tip: 'Dồn lực qua gót và giữ bàn chân bám sàn chắc hơn nhé.',
      ),
    'Depth' => (
        title: 'Độ sâu chưa đủ',
        tip: 'Hạ hông thêm một chút nếu vẫn còn kiểm soát tốt nhé.',
      ),
    'Tempo' => (
        title: 'Nhịp chưa đều',
        tip: 'Xuống chậm hơn và giữ đáy thêm một nhịp nhé.',
      ),
    'HipShoulderSync' => (
        title: 'Hông lên trước vai',
        tip: 'Đứng lên cùng lúc bằng hông và ngực để form chắc hơn nhé.',
      ),
    _ => (
        title: type.replaceAll('_', ' ').toLowerCase(),
        tip: 'Giữ nhịp đều và kiểm soát chuyển động thêm một chút nhé.',
      ),
  };
}
