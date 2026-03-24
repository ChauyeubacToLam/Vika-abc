import 'package:flutter/material.dart';

import '../onboarding_data.dart';
import '../vf_theme.dart';

class ProgramPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onComplete;
  final VoidCallback onBack;

  const ProgramPage({
    super.key,
    required this.data,
    required this.onComplete,
    required this.onBack,
  });

  @override
  State<ProgramPage> createState() => _ProgramPageState();
}

class _ProgramPageState extends State<ProgramPage> {
  int _week = 0;
  int? _expanded = 0;

  List<_WeekData> get _weeks => [
        _WeekData(
          label: 'Tuần 1',
          subtitle: 'Làm quen và xây nền',
          workouts: [
            _Workout(
              day: 'T2',
              focus: 'Toàn thân',
              duration: _level == 'advanced' ? '15 phút' : '10 phút',
              exercises: [
                'Squat • 8 reps',
                'Plank • 3 x 10s',
                'Jumping Jack • 15 reps',
              ],
            ),
            _Workout(
              day: 'T4',
              focus: 'Core và thân trên',
              duration: _level == 'advanced' ? '15 phút' : '10 phút',
              exercises: [
                'Wall push-up • 8 reps',
                'Plank • 3 x 12s',
                'Jumping Jack • 15 reps',
              ],
            ),
            _Workout(
              day: 'T6',
              focus: 'Hạ thân',
              duration: _level == 'advanced' ? '16 phút' : '12 phút',
              exercises: [
                'Squat • 10 reps',
                'Plank • 3 x 10s',
                'March in place • 40s',
              ],
            ),
          ],
        ),
        _WeekData(
          label: 'Tuần 2',
          subtitle: 'Tăng dần khối lượng',
          workouts: [
            _Workout(
              day: 'T2',
              focus: 'Toàn thân',
              duration: _level == 'advanced' ? '18 phút' : '12 phút',
              exercises: [
                'Squat • 10 reps',
                'Plank • 3 x 15s',
                'Wall push-up • 6 reps',
              ],
            ),
            _Workout(
              day: 'T4',
              focus: 'Core và kiểm soát',
              duration: _level == 'advanced' ? '18 phút' : '12 phút',
              exercises: [
                'Wall push-up • 8 reps',
                'Plank • 3 x 15s',
                'Tempo squat • 8 reps',
              ],
            ),
            _Workout(
              day: 'T6',
              focus: 'Đánh giá lại',
              duration: _level == 'advanced' ? '20 phút' : '15 phút',
              exercises: [
                'Squat check • 5 reps',
                'Wall push-up check • 5 reps',
                'Plank • max hold',
              ],
            ),
          ],
        ),
      ];

  String get _level => widget.data.confirmedLevel ?? 'beginner';

  @override
  Widget build(BuildContext context) {
    final week = _weeks[_week];
    final frequencyLabel = '${widget.data.workoutDays.length} ngày/tuần';

    return Column(
      children: [
        VFProgressBar(current: 7, total: 7, onBack: widget.onBack),
        Expanded(
          child: VFFitViewport(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chương trình đầu tiên của bạn',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: VF.text,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Payoff cuối cùng vẫn giữ premium minimal direction: light theme, text-first cards, một accent jade xuyên suốt.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: VF.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                VFPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Built from your onboarding',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: VF.text,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          VFPill(label: _levelLabel),
                          VFPill(label: frequencyLabel),
                          VFPill(label: _timeLabel),
                          if (widget.data.detectedIssues.contains('ankle_mobility'))
                            const VFPill(
                              label: 'Ưu tiên cổ chân',
                              color: VF.amber,
                              background: VF.amberSoft,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: List.generate(_weeks.length, (index) {
                    final item = _weeks[index];
                    final on = _week == index;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index < _weeks.length - 1 ? 8 : 0,
                        ),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _week = index;
                            _expanded = 0;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: on ? VF.accentSoft : VF.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: on
                                    ? VF.accent.withValues(alpha: 0.28)
                                    : VF.border,
                                width: 1.4,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: on ? VF.accent : VF.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.subtitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10.8,
                                    color: VF.textMuted,
                                    height: 1.35,
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
                ...List.generate(week.workouts.length, (index) {
                  final workout = week.workouts[index];
                  final open = _expanded == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _expanded = open ? null : index;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: open ? VF.accentSoft : VF.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: open
                                ? VF.accent.withValues(alpha: 0.28)
                                : VF.border,
                            width: 1.4,
                          ),
                          boxShadow: open ? VF.cardShadow : null,
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            workout.day,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: VF.text,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          VFPill(
                                            label: workout.focus,
                                            color: open ? VF.accent : VF.textSec,
                                            background:
                                                open ? VF.surface : VF.bg,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        workout.duration,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: VF.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                VFCheckIcon(
                                  size: 12,
                                  filled: open,
                                ),
                              ],
                            ),
                            if (open) ...[
                              const SizedBox(height: 14),
                              const Divider(color: VF.border, height: 1),
                              const SizedBox(height: 14),
                              ...workout.exercises.map(
                                (exercise) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 1),
                                        child: VFCheckIcon(size: 11),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          exercise,
                                          style: const TextStyle(
                                            fontSize: 12.8,
                                            color: VF.textSec,
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: VFButton(
            label: 'Bắt đầu hành trình',
            onTap: widget.onComplete,
          ),
        ),
      ],
    );
  }

  String get _levelLabel {
    switch (_level) {
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
        return 'Ưu tiên buổi sáng';
      case 'noon':
        return 'Ưu tiên buổi trưa';
      case 'night':
        return 'Ưu tiên buổi tối';
      default:
        return 'Ưu tiên chiều tối';
    }
  }
}

class _WeekData {
  final String label;
  final String subtitle;
  final List<_Workout> workouts;

  const _WeekData({
    required this.label,
    required this.subtitle,
    required this.workouts,
  });
}

class _Workout {
  final String day;
  final String focus;
  final String duration;
  final List<String> exercises;

  const _Workout({
    required this.day,
    required this.focus,
    required this.duration,
    required this.exercises,
  });
}
