import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/post_exercise_data.dart';
import '../../theme/vf_theme.dart';
import '../../utils/exercise_logger.dart';
import 'widgets/form_score_arc.dart';
import '../../services/session_persistence.dart';

class RestScreen extends StatefulWidget {
  const RestScreen({
    super.key,
    required this.setReport,
    required this.setIndex,
    required this.totalSets,
    required this.currentReps,
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
  final bool isLastSet;
  final VoidCallback onNext;
  final Function(String difficulty)? onDifficultyAnswer;
  final ExerciseLogger? setLogger;
  final List<PreviousSessionSummary>? previousSession;
  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> with TickerProviderStateMixin {
  static const Color _parchment = Color(0xFFF0EDE6);

  Timer? _timer;
  String? _selectedDifficulty;
  bool _showFaults = false;
  bool _didAdvance = false;
  late int _restDuration;
  late int _remaining;
  late final AnimationController _dotController;
  late final AnimationController _shimmerController;

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
    _restDuration = widget.isLastSet ? 10 : 45;
    _remaining = _restDuration;
    _dotController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            math.max(680, 320 + (widget.setReport.repResults.length * 40)),
      ),
    )..forward();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dotController.dispose();
    _shimmerController.dispose();
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
    widget.onNext();
  }

  void _selectDifficulty(String difficulty) {
    if (_lockedDifficulty) return;

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
    if (_selectedDifficulty == null || widget.isLastSet) {
      return null;
    }

    return switch (_selectedDifficulty!) {
      'light' => 'Set sau tăng 2 reps',
      'medium' => 'Set sau giữ ${widget.currentReps} reps',
      'heavy' => '+15s nghỉ · Set sau giảm 1 rep',
      _ => null,
    };
  }

  Animation<double> _dotAnimation(int index) {
    final start = (index * 0.04).clamp(0.0, 0.82).toDouble();
    final end = (start + 0.24).clamp(start + 0.01, 1.0).toDouble();
    return CurvedAnimation(
      parent: _dotController,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final verticalPadding = 28 * s;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF4F1EB),
            Color(0xFFEBE7DF),
            _parchment,
          ],
          stops: [0.0, 0.4, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.025,
                child: CustomPaint(
                  painter: const _PaperGrainPainter(),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    28 * s,
                    18 * s,
                    28 * s,
                    24 * s,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math
                          .max(
                            0,
                            constraints.maxHeight -
                                (verticalPadding + (14 * s)),
                          )
                          .toDouble(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _TopBar(
                          setIndex: widget.setIndex,
                          totalSets: widget.totalSets,
                          exerciseLabel: _exerciseLabel,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 18 * s),
                          child: Column(
                            children: [
                              _TimerRing(
                                scale: s,
                                progress: _progress,
                                remaining: _remaining,
                              ),
                              SizedBox(height: 20 * s),
                              _ScoreSummary(
                                goodReps: widget.setReport.goodReps,
                                totalReps: widget.setReport.totalReps,
                              ),
                              if (widget.setReport.repResults.isNotEmpty) ...[
                                SizedBox(height: 16 * s),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 6 * s,
                                  runSpacing: 6 * s,
                                  children: [
                                    for (int i = 0;
                                        i < widget.setReport.repResults.length;
                                        i++)
                                      _RepResultDot(
                                        scale: s,
                                        isGood: widget.setReport.repResults[i],
                                        animation: _dotAnimation(i),
                                      ),
                                  ],
                                ),
                              ],
                              if ((widget.setReport.praiseSentence ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                                SizedBox(height: 16 * s),
                                ConstrainedBox(
                                  constraints:
                                      BoxConstraints(maxWidth: 300 * s),
                                  child: Text(
                                    widget.setReport.praiseSentence!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.fraunces(
                                      textStyle: VFTheme.textStyle(
                                        context,
                                        size: 14,
                                        weight: FontWeight.w600,
                                        color: const Color(0xFF18594A),
                                        height: 1.45,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if ((widget.setReport.coachTip ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                                SizedBox(height: 16 * s),
                                ConstrainedBox(
                                  constraints:
                                      BoxConstraints(maxWidth: 320 * s),
                                  child: _CoachTipCard(
                                    text: widget.setReport.coachTip!,
                                  ),
                                ),
                              ],
                              if (_faultObservations.isNotEmpty) ...[
                                SizedBox(height: 12 * s),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _showFaults = !_showFaults);
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    foregroundColor: const Color(0xFFB5B3AC),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    '${_showFaults ? '▾' : '▸'} Cần cải thiện (${_faultObservations.length})',
                                    style: VFTheme.textStyle(
                                      context,
                                      size: 11,
                                      weight: FontWeight.w600,
                                      color: const Color(0xFFB5B3AC),
                                    ),
                                  ),
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  child: _showFaults
                                      ? Padding(
                                          padding: EdgeInsets.only(top: 8 * s),
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: 320 * s,
                                            ),
                                            child: Column(
                                              children: _faultObservations
                                                  .map(
                                                    (fault) => Padding(
                                                      padding: EdgeInsets.only(
                                                        bottom: 6 * s,
                                                      ),
                                                      child: _FaultRow(
                                                        fault: fault,
                                                        totalReps: widget
                                                            .setReport
                                                            .totalReps,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, child) {
                            return _BottomSection(
                              selectedDifficulty: _selectedDifficulty,
                              lockedDifficulty: _lockedDifficulty,
                              adjustmentText: _adjustmentText,
                              isLastSet: widget.isLastSet,
                              shimmerValue: _shimmerController.value,
                              onSelectDifficulty: _selectDifficulty,
                              onAdvance: _advance,
                            );
                          },
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
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.setIndex,
    required this.totalSets,
    required this.exerciseLabel,
  });

  final int setIndex;
  final int totalSets;
  final String exerciseLabel;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Row(
      children: [
        Text(
          'HIỆP ${setIndex + 1}/$totalSets',
          style: VFTheme.textStyle(
            context,
            size: 10,
            weight: FontWeight.w700,
            color: const Color(0xFFB5B3AC),
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12 * s,
            vertical: 4 * s,
          ),
          decoration: BoxDecoration(
            color: const Color(0x0D18594A),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x1418594A)),
          ),
          child: Text(
            exerciseLabel,
            style: VFTheme.textStyle(
              context,
              size: 11,
              weight: FontWeight.w700,
              color: const Color(0xFF18594A),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({
    required this.scale,
    required this.progress,
    required this.remaining,
  });

  final double scale;
  final double progress;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final size = 210 * scale;
    final arcSize = 186 * scale;
    final strokeWidth = 7 * scale;
    final radius = (arcSize - strokeWidth) / 2;
    final guideRadius = radius + (12 * scale);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 294 * scale,
            height: 294 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0x122E856E),
                  const Color(0x002E856E),
                ],
                stops: const [0.0, 0.72],
              ),
            ),
          ),
          CustomPaint(
            size: Size.square(size),
            painter: _DottedGuideRingPainter(
              radius: guideRadius,
              color: const Color(0x0A18594A),
              dashLength: 3 * scale,
              gapLength: 8 * scale,
            ),
          ),
          CustomPaint(
            size: Size.square(size),
            painter: _GlowArcPainter(
              progress: progress,
              radius: radius,
              color: const Color(0xFF2E856E),
              strokeWidth: 10 * scale,
            ),
          ),
          FormScoreArc(
            progress: progress,
            size: arcSize,
            color: const Color(0xFF2E856E),
            trackColor: const Color(0x0F18594A),
            strokeWidth: strokeWidth,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$remaining',
                style: VFTheme.textStyle(
                  context,
                  size: 52,
                  weight: FontWeight.w900,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: -2.5,
                ),
              ),
              SizedBox(height: 6 * scale),
              Text(
                'GIÂY NGHỈ',
                style: VFTheme.textStyle(
                  context,
                  size: 9,
                  weight: FontWeight.w700,
                  color: const Color(0xFFB5B3AC),
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreSummary extends StatelessWidget {
  const _ScoreSummary({
    required this.goodReps,
    required this.totalReps,
  });

  final int goodReps;
  final int totalReps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$goodReps',
                style: VFTheme.textStyle(
                  context,
                  size: 42,
                  weight: FontWeight.w900,
                  color: const Color(0xFF18594A),
                  letterSpacing: -1.5,
                ),
              ),
              TextSpan(
                text: '/$totalReps',
                style: VFTheme.textStyle(
                  context,
                  size: 18,
                  weight: FontWeight.w600,
                  color: const Color(0xFFB5B3AC),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 2 * VFTheme.scale(context)),
        Text(
          'reps chuẩn form',
          style: VFTheme.textStyle(
            context,
            size: 14,
            weight: FontWeight.w600,
            color: const Color(0xFF5A5A52),
          ),
        ),
      ],
    );
  }
}

class _RepResultDot extends StatelessWidget {
  const _RepResultDot({
    required this.scale,
    required this.isGood,
    required this.animation,
  });

  final double scale;
  final bool isGood;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final size = 22 * scale;

    return ScaleTransition(
      scale: animation,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isGood
              ? const LinearGradient(
                  colors: [
                    Color(0xFF2E856E),
                    Color(0xFF34D399),
                  ],
                )
              : null,
          color: isGood ? null : Colors.transparent,
          border: isGood
              ? null
              : Border.all(
                  color: const Color(0xFFD5D0C8),
                  width: 2 * scale,
                ),
          boxShadow: isGood
              ? [
                  BoxShadow(
                    color: const Color(0xFF2E856E).withValues(alpha: 0.18),
                    blurRadius: 8 * scale,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: isGood
            ? Icon(
                Icons.check_rounded,
                size: 12 * scale,
                color: Colors.white,
              )
            : null,
      ),
    );
  }
}

class _CoachTipCard extends StatelessWidget {
  const _CoachTipCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0x0AC4841D),
            Color(0x14C4841D),
          ],
        ),
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: const Color(0x1FC4841D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28 * s,
            height: 28 * s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8 * s),
              gradient: const LinearGradient(
                colors: [
                  Color(0x24C4841D),
                  Color(0x14C4841D),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '💡',
              style: TextStyle(fontSize: 13 * s),
            ),
          ),
          SizedBox(width: 10 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set sau thử',
                  style: VFTheme.textStyle(
                    context,
                    size: 11,
                    weight: FontWeight.w700,
                    color: const Color(0xFFC4841D),
                  ),
                ),
                SizedBox(height: 2 * s),
                Text(
                  text,
                  style: VFTheme.textStyle(
                    context,
                    size: 12,
                    weight: FontWeight.w500,
                    color: const Color(0xFF5A5A52),
                    height: 1.5,
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

class _FaultRow extends StatelessWidget {
  const _FaultRow({
    required this.fault,
    required this.totalReps,
  });

  final _FaultObservation fault;
  final int totalReps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Color(0xFFD4553A),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            fault.title,
            style: VFTheme.textStyle(
              context,
              size: 11,
              weight: FontWeight.w500,
              color: const Color(0xFF9A8E82),
            ),
          ),
        ),
        Text(
          '${fault.reps.length}/$totalReps',
          style: VFTheme.textStyle(
            context,
            size: 10,
            weight: FontWeight.w700,
            color: const Color(0xFFD4553A),
          ),
        ),
      ],
    );
  }
}

class _BottomSection extends StatelessWidget {
  const _BottomSection({
    required this.selectedDifficulty,
    required this.lockedDifficulty,
    required this.adjustmentText,
    required this.isLastSet,
    required this.shimmerValue,
    required this.onSelectDifficulty,
    required this.onAdvance,
  });

  final String? selectedDifficulty;
  final bool lockedDifficulty;
  final String? adjustmentText;
  final bool isLastSet;
  final double shimmerValue;
  final ValueChanged<String> onSelectDifficulty;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    const options = [
      (id: 'light', label: 'Nhẹ', emoji: '😌'),
      (id: 'medium', label: 'Vừa', emoji: '💪'),
      (id: 'heavy', label: 'Nặng', emoji: '🥵'),
    ];

    return Column(
      children: [
        Text(
          'Set này thế nào?',
          textAlign: TextAlign.center,
          style: VFTheme.textStyle(
            context,
            size: 11,
            weight: FontWeight.w600,
            color: const Color(0xFFB5B3AC),
          ),
        ),
        SizedBox(height: 10 * s),
        Row(
          children: [
            for (int i = 0; i < options.length; i++) ...[
              if (i > 0) SizedBox(width: 8 * s),
              Expanded(
                child: _DifficultyOption(
                  emoji: options[i].emoji,
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
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: adjustmentText == null
              ? SizedBox(
                  height: 12 * s, key: const ValueKey('empty-adjustment'))
              : Padding(
                  key: ValueKey(adjustmentText),
                  padding: EdgeInsets.only(top: 10 * s, bottom: 2 * s),
                  child: Text(
                    adjustmentText!,
                    textAlign: TextAlign.center,
                    style: VFTheme.textStyle(
                      context,
                      size: 11,
                      weight: FontWeight.w600,
                      color: const Color(0xFF2E856E),
                    ),
                  ),
                ),
        ),
        SizedBox(height: 10 * s),
        _CtaButton(
          label: isLastSet ? 'Xem tổng kết' : 'Bắt đầu set tiếp →',
          shimmerValue: shimmerValue,
          onTap: onAdvance,
        ),
      ],
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  const _DifficultyOption({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final dimmed = locked && !selected;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: dimmed ? 0.3 : 1,
      child: Transform.scale(
        scale: selected ? 1.04 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: locked ? null : onTap,
            borderRadius: BorderRadius.circular(16 * s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(vertical: 12 * s),
              decoration: BoxDecoration(
                color: selected ? null : Colors.white,
                gradient: selected
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF18594A),
                          Color(0xFF2E856E),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(16 * s),
                border: Border.all(
                  color:
                      selected ? Colors.transparent : const Color(0xFFE5E2DB),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF18594A).withValues(alpha: 0.2),
                          blurRadius: 16 * s,
                          offset: Offset(0, 4 * s),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color:
                              const Color(0xFF1A1A1A).withValues(alpha: 0.03),
                          blurRadius: 3 * s,
                          offset: Offset(0, 1 * s),
                        ),
                      ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: TextStyle(fontSize: 20 * s),
                  ),
                  SizedBox(height: 3 * s),
                  Text(
                    label,
                    style: VFTheme.textStyle(
                      context,
                      size: 12,
                      weight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF5A5A52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label,
    required this.shimmerValue,
    required this.onTap,
  });

  final String label;
  final double shimmerValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final radius = BorderRadius.circular(16 * s);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF18594A).withValues(alpha: 0.25),
            blurRadius: 24 * s,
            offset: Offset(0, 6 * s),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF18594A),
                  Color(0xFF2E856E),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sweepWidth = constraints.maxWidth * 0.34;
                  final sweepLeft = -sweepWidth +
                      (constraints.maxWidth + (sweepWidth * 2)) * shimmerValue;

                  return Stack(
                    children: [
                      Positioned(
                        left: sweepLeft,
                        top: -18 * s,
                        bottom: -18 * s,
                        width: sweepWidth,
                        child: Transform.rotate(
                          angle: 0.28,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.14),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 15 * s),
                        child: Center(
                          child: Text(
                            label,
                            style: VFTheme.textStyle(
                              context,
                              size: 14,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DottedGuideRingPainter extends CustomPainter {
  const _DottedGuideRingPainter({
    required this.radius,
    required this.color,
    required this.dashLength,
    required this.gapLength,
  });

  final double radius;
  final Color color;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final dashAngle = dashLength / radius;
    final gapAngle = gapLength / radius;
    double angle = -math.pi / 2;

    while (angle < (math.pi * 1.5)) {
      canvas.drawArc(rect, angle, dashAngle, false, paint);
      angle += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedGuideRingPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.color != color ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}

class _GlowArcPainter extends CustomPainter {
  const _GlowArcPainter({
    required this.progress,
    required this.radius,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final double radius;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        6,
      );

    canvas.drawArc(
      rect,
      -math.pi / 2,
      (math.pi * 2) * progress.clamp(0.0, 1.0),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlowArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.radius != radius ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _PaperGrainPainter extends CustomPainter {
  const _PaperGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 1500; i++) {
      final x = _noise(i * 0.17) * size.width;
      final y = _noise((i * 0.31) + 17) * size.height;
      final dotSize = 0.35 + (_noise((i * 0.13) + 43) * 0.9);
      canvas.drawRect(
        Rect.fromLTWH(x, y, dotSize, dotSize),
        paint,
      );
    }
  }

  double _noise(double seed) {
    final value = math.sin(seed * 12.9898) * 43758.5453;
    return value - value.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
