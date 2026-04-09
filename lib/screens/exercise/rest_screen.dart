import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/post_exercise_data.dart';
import '../../theme/vf_theme.dart';
import '../../utils/exercise_logger.dart';
import 'widgets/form_score_arc.dart';

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
  });

  final SetReportData setReport;
  final int setIndex;
  final int totalSets;
  final int currentReps;
  final bool isLastSet;
  final VoidCallback onNext;
  final Function(String difficulty)? onDifficultyAnswer;
  final ExerciseLogger? setLogger;

  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> {
  Timer? _timer;
  String? _selectedDifficulty;
  bool _showAllFaults = false;
  bool _didAdvance = false;
  late int _restDuration;
  late int _remaining;

  List<_FaultObservation> get _faultObservations =>
      _groupFaultObservations(widget.setLogger);

  List<_FaultObservation> get _visibleFaultObservations =>
      _showAllFaults || _faultObservations.length <= 1
          ? _faultObservations
          : _faultObservations.take(1).toList();

  bool get _hasCollapsedFaults => _faultObservations.length > 1;

  bool get _lockedDifficulty => _selectedDifficulty != null;

  @override
  void initState() {
    super.initState();
    _restDuration = widget.isLastSet ? 10 : 45;
    _remaining = _restDuration;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
      'light' => 'Set sau: ${widget.currentReps + 2} reps',
      'medium' => 'Giữ ${widget.currentReps} reps',
      'heavy' =>
        'Set sau: ${(widget.currentReps - 1).clamp(1, 999)} reps · Nghỉ thêm 15s',
      _ => null,
    };
  }

  Color get _timerColor =>
      widget.isLastSet ? const Color(0xFFC4841D) : const Color(0xFF18594A);

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final needsWork =
        (widget.setReport.totalReps - widget.setReport.goodReps).clamp(0, 999);
    final visibleFaults = _visibleFaultObservations;

    return Container(
      color: const Color(0xFFF0EDE6),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(18 * s, 18 * s, 18 * s, 8 * s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isLastSet ? 'SET CUỐI HOÀN TẤT' : 'NGHỈ GIỮA HIỆP',
                      style: VFTheme.textStyle(
                        context,
                        size: 11,
                        weight: FontWeight.w800,
                        color: const Color(0xFF9C9B94),
                        letterSpacing: 1.3,
                      ),
                    ),
                    SizedBox(height: 12 * s),
                    _SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.setReport.score}%',
                                    style: VFTheme.textStyle(
                                      context,
                                      size: 28,
                                      weight: FontWeight.w900,
                                      color: const Color(0xFF18594A),
                                      letterSpacing: -0.9,
                                    ),
                                  ),
                                  Text(
                                    'form score',
                                    style: VFTheme.textStyle(
                                      context,
                                      size: 11,
                                      weight: FontWeight.w700,
                                      color: const Color(0xFF5A5A52),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10 * s,
                                  vertical: 7 * s,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F0ED),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Hiệp ${widget.setIndex + 1}/${widget.totalSets}',
                                  style: VFTheme.textStyle(
                                    context,
                                    size: 10,
                                    weight: FontWeight.w800,
                                    color: const Color(0xFF18594A),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 18 * s),
                          _AnimatedProgressBar(
                              progress: widget.setReport.score / 100),
                          SizedBox(height: 10 * s),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${widget.setReport.goodReps} đúng',
                                  style: VFTheme.textStyle(
                                    context,
                                    size: 12,
                                    weight: FontWeight.w800,
                                    color: const Color(0xFF18594A),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '$needsWork cần cải thiện',
                                  textAlign: TextAlign.right,
                                  style: VFTheme.textStyle(
                                    context,
                                    size: 12,
                                    weight: FontWeight.w800,
                                    color: const Color(0xFFD4553A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_faultObservations.isNotEmpty) ...[
                            SizedBox(height: 16 * s),
                            Container(
                              height: 1,
                              color: const Color(0xFFE5E2DB),
                            ),
                            SizedBox(height: 14 * s),
                            Column(
                              children:
                                  visibleFaults.asMap().entries.map((entry) {
                                final index = entry.key;
                                final fault = entry.value;
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == visibleFaults.length - 1
                                        ? 0
                                        : 10 * s,
                                  ),
                                  child: _FaultCard(fault: fault),
                                );
                              }).toList(),
                            ),
                            if (_hasCollapsedFaults) ...[
                              SizedBox(height: 12 * s),
                              Align(
                                alignment: Alignment.center,
                                child: _FaultExpandButton(
                                  expanded: _showAllFaults,
                                  onTap: () => setState(
                                      () => _showAllFaults = !_showAllFaults),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 14 * s),
                    _SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isLastSet
                                ? 'SET CUỐI THẾ NÀO?'
                                : 'SET NÀY THẾ NÀO?',
                            style: VFTheme.textStyle(
                              context,
                              size: 10,
                              weight: FontWeight.w800,
                              color: const Color(0xFF9C9B94),
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 14 * s),
                          Row(
                            children: [
                              Expanded(
                                child: _DifficultyButton(
                                  label: 'Nhẹ 💨',
                                  tone: const Color(0xFF18594A),
                                  selected: _selectedDifficulty == 'light',
                                  locked: _lockedDifficulty,
                                  onTap: () => _selectDifficulty('light'),
                                ),
                              ),
                              SizedBox(width: 8 * s),
                              Expanded(
                                child: _DifficultyButton(
                                  label: 'Vừa 👌',
                                  tone: const Color(0xFFC4841D),
                                  selected: _selectedDifficulty == 'medium',
                                  locked: _lockedDifficulty,
                                  onTap: () => _selectDifficulty('medium'),
                                ),
                              ),
                              SizedBox(width: 8 * s),
                              Expanded(
                                child: _DifficultyButton(
                                  label: 'Nặng 🔥',
                                  tone: const Color(0xFFD4553A),
                                  selected: _selectedDifficulty == 'heavy',
                                  locked: _lockedDifficulty,
                                  onTap: () => _selectDifficulty('heavy'),
                                ),
                              ),
                            ],
                          ),
                          if (_adjustmentText != null) ...[
                            SizedBox(height: 12 * s),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12 * s,
                                vertical: 11 * s,
                              ),
                              decoration: BoxDecoration(
                                color: _difficultyTone(_selectedDifficulty!)
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12 * s),
                                border: Border.all(
                                  color: _difficultyTone(_selectedDifficulty!)
                                      .withValues(alpha: 0.18),
                                ),
                              ),
                              child: Text(
                                _adjustmentText!,
                                style: VFTheme.textStyle(
                                  context,
                                  size: 12,
                                  weight: FontWeight.w800,
                                  color: _difficultyTone(_selectedDifficulty!),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 14 * s),
                    _SurfaceCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42 * s,
                            height: 42 * s,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F0ED),
                              borderRadius: BorderRadius.circular(12 * s),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              widget.setReport.insightIcon,
                              style: TextStyle(fontSize: 18 * s),
                            ),
                          ),
                          SizedBox(width: 12 * s),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.setReport.insightText,
                                  style: VFTheme.textStyle(
                                    context,
                                    size: 14,
                                    weight: FontWeight.w800,
                                    color: const Color(0xFF1A1A1A),
                                    height: 1.35,
                                  ),
                                ),
                                if ((widget.setReport.insightTip ?? '')
                                    .isNotEmpty) ...[
                                  SizedBox(height: 6 * s),
                                  Text(
                                    widget.setReport.insightTip!,
                                    style: VFTheme.textStyle(
                                      context,
                                      size: 12,
                                      weight: FontWeight.w600,
                                      color: const Color(0xFF5A5A52),
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24 * s, 12 * s, 24 * s, 20 * s),
              child: Column(
                children: [
                  FormScoreArc(
                    progress: _restDuration == 0
                        ? 1
                        : 1 - (_remaining / _restDuration),
                    size: 118 * s,
                    color: _timerColor,
                    trackColor: _timerColor.withValues(alpha: 0.12),
                    strokeWidth: 7 * s,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_remaining',
                          style: VFTheme.textStyle(
                            context,
                            size: 28,
                            weight: FontWeight.w900,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        SizedBox(height: 2 * s),
                        Text(
                          widget.isLastSet ? 'TỔNG KẾT' : 'GIÂY NGHỈ',
                          style: VFTheme.textStyle(
                            context,
                            size: 10,
                            weight: FontWeight.w800,
                            color: const Color(0xFF9C9B94),
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isLastSet) ...[
                    SizedBox(height: 10 * s),
                    Text(
                      'Đang tổng kết buổi tập...',
                      style: VFTheme.textStyle(
                        context,
                        size: 12,
                        weight: FontWeight.w700,
                        color: const Color(0xFF5A5A52),
                      ),
                    ),
                  ],
                  SizedBox(height: 12 * s),
                  TextButton(
                    onPressed: _advance,
                    style: TextButton.styleFrom(
                      foregroundColor: _timerColor,
                    ),
                    child: Text(
                      widget.isLastSet ? 'Xem tổng kết →' : 'Bỏ qua →',
                      style: VFTheme.textStyle(
                        context,
                        size: 13,
                        weight: FontWeight.w800,
                        color: _timerColor,
                      ),
                    ),
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

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: const Color(0xFFE5E2DB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.04),
            blurRadius: 18 * s,
            offset: Offset(0, 10 * s),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AnimatedProgressBar extends StatelessWidget {
  const _AnimatedProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 12 * s,
        child: Stack(
          children: [
            Container(color: const Color(0xFFE8F0ED)),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return FractionallySizedBox(
                  widthFactor: value,
                  alignment: Alignment.centerLeft,
                  child: child,
                );
              },
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF18594A),
                      Color(0xFF2C8B73),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  const _DifficultyButton({
    required this.label,
    required this.tone,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final Color tone;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final opacity = selected ? 1.0 : (locked ? 0.36 : 1.0);

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(12 * s),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 13 * s),
          decoration: BoxDecoration(
            color: selected ? tone : tone.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12 * s),
            border: Border.all(
              color: selected ? tone : tone.withValues(alpha: 0.18),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: VFTheme.textStyle(
              context,
              size: 12,
              weight: FontWeight.w800,
              color: selected ? Colors.white : tone,
            ),
          ),
        ),
      ),
    );
  }
}

class _FaultExpandButton extends StatelessWidget {
  const _FaultExpandButton({
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42 * s,
          height: 42 * s,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE5E2DB)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A1A1A).withValues(alpha: 0.06),
                blurRadius: 14 * s,
                offset: Offset(0, 8 * s),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              expanded
                  ? Icons.keyboard_double_arrow_up_rounded
                  : Icons.keyboard_double_arrow_down_rounded,
              size: 18 * s,
              color: const Color(0xFF18594A),
            ),
          ),
        ),
      ),
    );
  }
}

class _FaultCard extends StatelessWidget {
  const _FaultCard({required this.fault});

  final _FaultObservation fault;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F5),
        borderRadius: BorderRadius.circular(12 * s),
        border: Border.all(color: const Color(0xFFF1DDD8)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4 * s,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(12 * s),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFD4553A),
                    Color(0x00D4553A),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14 * s, 12 * s, 12 * s, 12 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fault.title,
                        style: VFTheme.textStyle(
                          context,
                          size: 12,
                          weight: FontWeight.w800,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8 * s,
                        vertical: 5 * s,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4553A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${fault.reps.length} rep',
                        style: VFTheme.textStyle(
                          context,
                          size: 10,
                          weight: FontWeight.w800,
                          color: const Color(0xFFD4553A),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6 * s),
                Text(
                  'rep ${fault.reps.join(', ')} · ${fault.tip}',
                  style: VFTheme.textStyle(
                    context,
                    size: 9,
                    weight: FontWeight.w700,
                    color: const Color(0xFF9C9B94),
                    height: 1.45,
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

Color _difficultyTone(String difficulty) {
  return switch (difficulty) {
    'light' => const Color(0xFF18594A),
    'heavy' => const Color(0xFFD4553A),
    _ => const Color(0xFFC4841D),
  };
}
