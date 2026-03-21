import 'package:flutter/material.dart';
import '../onboarding_data.dart';
import '../vf_theme.dart';

class ProgramPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onComplete;
  const ProgramPage({super.key, required this.data, required this.onComplete});

  @override
  State<ProgramPage> createState() => _ProgramPageState();
}

class _ProgramPageState extends State<ProgramPage> {
  int _week = 0;
  int? _expanded = 0;

  // ── Colors for focus areas ──
  static const _focusFull = VF.brand;
  static const _focusCore = VF.orange;
  static const _focusLower = VF.green;
  static const _focusAssess = Color(0xFF6366F1);

  List<_WeekData> get _weeks => [
        _WeekData(
          label: 'Tuần 1',
          subtitle: 'Làm quen & xây nền tảng',
          days: [
            _DayData.workout(
              day: 'T2',
              focus: 'Toàn thân',
              focusColor: _focusFull,
              difficulty: 1,
              duration: '10 phút',
              icon: '🏋️',
              warmup: const _WarmupData('Khởi động cổ chân', '2 phút'),
              exercises: [
                const _ExData('Plank', '3 x 10s', '🧘', VF.orange, 'Core'),
                const _ExData('Squat', '8 reps', '🏋️', VF.brand, 'Đùi, Mông'),
                const _ExData(
                    'Jumping Jack', '15 reps', '⭐', VF.green, 'Cardio'),
              ],
              cooldown: 'Kéo giãn 2 phút',
            ),
            _DayData.rest('T3'),
            _DayData.workout(
              day: 'T4',
              focus: 'Core & Thân trên',
              focusColor: _focusCore,
              difficulty: 1,
              duration: '10 phút',
              icon: '💪',
              warmup: const _WarmupData('Xoay vai + cổ tay', '1 phút'),
              exercises: [
                const _ExData(
                    'Chống đẩy tường', '8 reps', '🧱', VF.green, 'Ngực, Vai'),
                const _ExData('Plank', '3 x 12s', '🧘', VF.orange, 'Core'),
                const _ExData(
                    'Jumping Jack', '15 reps', '⭐', VF.brand, 'Cardio'),
              ],
              cooldown: 'Kéo giãn 2 phút',
            ),
            _DayData.rest('T5'),
            _DayData.workout(
              day: 'T6',
              focus: 'Hạ thân & Cardio',
              focusColor: _focusLower,
              difficulty: 1,
              duration: '12 phút',
              icon: '🦵',
              warmup: const _WarmupData('Khởi động cổ chân', '2 phút'),
              exercises: [
                const _ExData('Squat', '10 reps', '🏋️', VF.brand, 'Đùi, Mông'),
                const _ExData('Plank', '3 x 10s', '🧘', VF.orange, 'Core'),
                const _ExData(
                    'Jumping Jack', '20 reps', '⭐', VF.green, 'Cardio'),
              ],
              cooldown: 'Kéo giãn 3 phút',
            ),
            _DayData.rest('T7'),
            _DayData.rest('CN'),
          ],
        ),
        _WeekData(
          label: 'Tuần 2',
          subtitle: 'Tăng cường & kiểm tra lại',
          days: [
            _DayData.workout(
              day: 'T2',
              focus: 'Toàn thân',
              focusColor: _focusFull,
              difficulty: 2,
              duration: '12 phút',
              icon: '🏋️',
              warmup: const _WarmupData('Khởi động cổ chân', '2 phút'),
              exercises: [
                const _ExData('Plank', '3 x 15s', '🧘', VF.orange, 'Core'),
                const _ExData('Squat', '10 reps', '🏋️', VF.brand, 'Đùi, Mông'),
                const _ExData(
                    'Chống đẩy tường', '6 reps', '🧱', VF.green, 'Ngực, Vai'),
                const _ExData(
                    'Jumping Jack', '20 reps', '⭐', _focusAssess, 'Cardio'),
              ],
              cooldown: 'Kéo giãn 2 phút',
            ),
            _DayData.rest('T3'),
            _DayData.workout(
              day: 'T4',
              focus: 'Core & Thân trên',
              focusColor: _focusCore,
              difficulty: 2,
              duration: '12 phút',
              icon: '💪',
              warmup: const _WarmupData('Xoay vai + cổ tay', '1 phút'),
              exercises: [
                const _ExData(
                    'Chống đẩy tường', '8 reps', '🧱', VF.green, 'Ngực, Vai'),
                const _ExData('Plank', '3 x 15s', '🧘', VF.orange, 'Core'),
                const _ExData('Squat', '10 reps', '🏋️', VF.brand, 'Đùi, Mông'),
              ],
              cooldown: 'Kéo giãn 2 phút',
            ),
            _DayData.rest('T5'),
            _DayData.workout(
              day: 'T6',
              focus: 'Đánh giá lại',
              focusColor: _focusAssess,
              difficulty: 2,
              duration: '15 phút',
              icon: '📊',
              warmup: const _WarmupData('Khởi động toàn thân', '2 phút'),
              exercises: [
                const _ExData(
                    'Kiểm tra Squat', '5 reps', '🏋️', VF.brand, 'Đánh giá'),
                const _ExData('Kiểm tra Chống đẩy tường', '5 reps', '🧱',
                    VF.green, 'Đánh giá'),
                const _ExData(
                    'Plank', 'Giữ tối đa', '🧘', VF.orange, 'Đánh giá'),
              ],
              cooldown: 'Kéo giãn 3 phút',
              note: 'So sánh với kết quả ban đầu!',
            ),
            _DayData.rest('T7'),
            _DayData.rest('CN'),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final w = _weeks[_week];
    final workouts = w.days.where((d) => d.isWorkout).toList();

    return Column(
      children: [
        // ── Header ──
        GradHeader(
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI ĐÃ TẠO CHO BẠN',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chương trình của bạn',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _headerChip(_levelLabel),
                    _headerChip('3 ngày/tuần'),
                    _headerChip('~10-12 phút'),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Content ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Personalization tags
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (widget.data.detectedIssues.contains('ankle_mobility'))
                      _tag('🦶', 'Khởi động cổ chân', VF.amber),
                    _tag('⏰', 'Nhắc lúc $_timeLabel', VF.brand),
                    _tag('📊', 'Đánh giá lại tuần 2', VF.green),
                  ],
                ),
                const SizedBox(height: 14),

                // Week tabs
                Row(
                  children: List.generate(_weeks.length, (i) {
                    final wk = _weeks[i];
                    final on = _week == i;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: i < _weeks.length - 1 ? 6 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _week = i;
                            _expanded = 0;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: on ? VF.brand : VF.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: on ? VF.brand : VF.border, width: 1.5),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  wk.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: on ? Colors.white : VF.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  wk.subtitle,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: on
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : VF.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),

                // Mini calendar strip
                Row(
                  children: w.days.map((d) {
                    return Expanded(
                      child: Container(
                        height: 36,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: d.isWorkout
                              ? d.focusColor!.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: d.isWorkout
                                ? d.focusColor!.withValues(alpha: 0.2)
                                : VF.border.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              d.day,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color:
                                    d.isWorkout ? d.focusColor : VF.textMuted,
                              ),
                            ),
                            if (d.isWorkout)
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color: d.focusColor,
                                  shape: BoxShape.circle,
                                ),
                              )
                            else
                              const Text('nghỉ',
                                  style: TextStyle(
                                      fontSize: 7, color: VF.textMuted)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Workout cards
                ...List.generate(workouts.length, (i) {
                  final d = workouts[i];
                  final isOpen = _expanded == i;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _expanded = isOpen ? null : i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: VF.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: VF.border),
                          boxShadow: VF.cardShadow,
                        ),
                        child: Column(
                          children: [
                            // Card header
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  // Icon
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          d.focusColor!.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(d.icon!,
                                        style: const TextStyle(fontSize: 18)),
                                  ),
                                  const SizedBox(width: 12),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              d.day,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: VF.text,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: d.focusColor!
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                d.focus!,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: d.focusColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                                '${d.exercises!.length} bài tập',
                                                style: const TextStyle(
                                                    fontSize: 10.5,
                                                    color: VF.textMuted)),
                                            const Text('  ·  ',
                                                style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: VF.textMuted)),
                                            Text(d.duration!,
                                                style: const TextStyle(
                                                    fontSize: 10.5,
                                                    color: VF.textMuted)),
                                            const Text('  ·  ',
                                                style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: VF.textMuted)),
                                            // Difficulty dots
                                            Row(
                                              children: List.generate(3, (di) {
                                                return Container(
                                                  width: 10,
                                                  height: 4,
                                                  margin: const EdgeInsets.only(
                                                      right: 2),
                                                  decoration: BoxDecoration(
                                                    color: di < d.difficulty!
                                                        ? d.focusColor
                                                        : VF.border,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            2),
                                                  ),
                                                );
                                              }),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Chevron
                                  AnimatedRotation(
                                    turns: isOpen ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: const Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 20,
                                      color: VF.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Expanded content
                            if (isOpen) ...[
                              Container(
                                  height: 1,
                                  color: VF.border,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 14)),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                child: Column(
                                  children: [
                                    // Warmup
                                    if (d.warmup != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 10),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color:
                                              VF.amber.withValues(alpha: 0.06),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Text('🦶',
                                                style: TextStyle(fontSize: 12)),
                                            const SizedBox(width: 8),
                                            Text(
                                              d.warmup!.name,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: VF.amber,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              d.warmup!.time,
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: VF.textMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Exercises
                                    ...d.exercises!.asMap().entries.map((e) {
                                      final ex = e.value;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        decoration: BoxDecoration(
                                          border: e.key > 0 || d.warmup != null
                                              ? Border(
                                                  top: BorderSide(
                                                      color: VF.border
                                                          .withValues(
                                                              alpha: 0.3)))
                                              : null,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: ex.color
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(ex.icon,
                                                  style: const TextStyle(
                                                      fontSize: 14)),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    ex.name,
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: VF.text,
                                                    ),
                                                  ),
                                                  Text(
                                                    ex.muscles,
                                                    style: const TextStyle(
                                                        fontSize: 10,
                                                        color: VF.textMuted),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              ex.detail,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: VF.textSec,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    // Cooldown
                                    if (d.cooldown != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color:
                                              VF.brand.withValues(alpha: 0.04),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Text('🧘',
                                                style: TextStyle(fontSize: 12)),
                                            const SizedBox(width: 8),
                                            Text(
                                              d.cooldown!,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: VF.brand,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Special note
                                    if (d.note != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _focusAssess.withValues(
                                              alpha: 0.05),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: _focusAssess.withValues(
                                                  alpha: 0.12)),
                                        ),
                                        child: Text(
                                          d.note!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _focusAssess,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Bottom note
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      'AI sẽ điều chỉnh dựa trên tiến bộ và phản hồi của bạn',
                      style: TextStyle(fontSize: 10.5, color: VF.textMuted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // CTA
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
          child: VFButton(
            label: 'Bắt đầu buổi tập đầu tiên',
            onTap: widget.onComplete,
          ),
        ),
      ],
    );
  }

  String get _levelLabel {
    switch (widget.data.confirmedLevel ?? "beginner") {
      case 'advanced':
        return 'Khá tốt';
      case 'intermediate':
        return 'Trung bình';
      default:
        return 'Người mới';
    }
  }

  String get _timeLabel {
    switch (widget.data.preferredTime) {
      case 'morning':
        return '7:00';
      case 'noon':
        return '12:00';
      case 'night':
        return '21:00';
      default:
        return '17:00';
    }
  }

  Widget _headerChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _tag(String icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Data models ──

class _WeekData {
  final String label, subtitle;
  final List<_DayData> days;
  const _WeekData(
      {required this.label, required this.subtitle, required this.days});
}

class _DayData {
  final String day;
  final bool isWorkout;
  final String? focus, icon, duration, cooldown, note;
  final Color? focusColor;
  final int? difficulty;
  final _WarmupData? warmup;
  final List<_ExData>? exercises;

  const _DayData._({
    required this.day,
    required this.isWorkout,
    this.focus,
    this.focusColor,
    this.difficulty,
    this.duration,
    this.icon,
    this.warmup,
    this.exercises,
    this.cooldown,
    this.note,
  });

  factory _DayData.rest(String day) => _DayData._(day: day, isWorkout: false);

  factory _DayData.workout({
    required String day,
    required String focus,
    required Color focusColor,
    required int difficulty,
    required String duration,
    required String icon,
    required List<_ExData> exercises,
    _WarmupData? warmup,
    String? cooldown,
    String? note,
  }) =>
      _DayData._(
        day: day,
        isWorkout: true,
        focus: focus,
        focusColor: focusColor,
        difficulty: difficulty,
        duration: duration,
        icon: icon,
        warmup: warmup,
        exercises: exercises,
        cooldown: cooldown,
        note: note,
      );
}

class _WarmupData {
  final String name, time;
  const _WarmupData(this.name, this.time);
}

class _ExData {
  final String name, detail, icon, muscles;
  final Color color;
  const _ExData(this.name, this.detail, this.icon, this.color, this.muscles);
}
