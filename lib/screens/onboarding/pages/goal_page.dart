import 'package:flutter/material.dart';

import '../onboarding_data.dart';
import '../vf_theme.dart';

class GoalPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const GoalPage({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends State<GoalPage> {
  static const _goals = [
    (
      id: 'lose_weight',
      title: 'Giảm cân',
      desc: 'Đốt mỡ hiệu quả tại nhà với guidance rõ ràng và đều nhịp.',
    ),
    (
      id: 'tone',
      title: 'Săn chắc',
      desc: 'Tăng sức mạnh nền và làm cơ thể gọn, chắc hơn từng tuần.',
    ),
    (
      id: 'health',
      title: 'Khỏe mạnh',
      desc: 'Duy trì vận động bền vững, form an toàn, lịch tập dễ theo.',
    ),
  ];

  static const _freqs = [
    (id: 'never', label: 'Chưa tập'),
    (id: '1_2', label: '1-2 buổi'),
    (id: '3_4', label: '3-4 buổi'),
    (id: '5_plus', label: '5+ buổi'),
  ];

  bool get _canContinue =>
      widget.data.goal != null && widget.data.experience != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        VFProgressBar(current: 1, total: 7, onBack: widget.onBack),
        Expanded(
          child: VFFitViewport(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mục tiêu chính của bạn?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: VF.text,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Trang này gộp mục tiêu và tần suất tập để AI có baseline trước khi vào squat assessment.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: VF.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ..._goals.map(_buildGoalCard),
                const SizedBox(height: 18),
                VFPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bạn đang tập bao nhiêu mỗi tuần?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: VF.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Dữ liệu này sẽ cộng với assessment để dự đoán trình độ ban đầu.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: VF.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(2, (rowIndex) {
                        final start = rowIndex * 2;
                        final rowItems = _freqs.skip(start).take(2).toList();

                        return Padding(
                          padding:
                              EdgeInsets.only(bottom: rowIndex == 1 ? 0 : 10),
                          child: Row(
                            children: List.generate(rowItems.length, (index) {
                              final item = rowItems[index];
                              final isLast = index == rowItems.length - 1;
                              return Expanded(
                                child: Padding(
                                  padding:
                                      EdgeInsets.only(right: isLast ? 0 : 10),
                                  child: _FrequencyOptionCard(
                                    label: item.label,
                                    selected: widget.data.experience == item.id,
                                    onTap: () => setState(() {
                                      widget.data.experience = item.id;
                                    }),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: VFButton(
            label: 'Tiếp tục',
            onTap: _canContinue ? widget.onNext : null,
            enabled: _canContinue,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalCard(({String id, String title, String desc}) goal) {
    final on = widget.data.goal == goal.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() {
          widget.data.goal = goal.id;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: on ? VF.accentSoft : VF.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: on ? VF.accent.withValues(alpha: 0.28) : VF.border,
              width: 1.5,
            ),
            boxShadow: on ? VF.cardShadow : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: on ? VF.accent : VF.text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      goal.desc,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: on ? VF.textSec : VF.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              VFCheckIcon(
                size: 14,
                color: VF.accent,
                filled: on,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrequencyOptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FrequencyOptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? VF.accentSoft : VF.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected ? VF.accent.withValues(alpha: 0.28) : VF.border,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              const VFCheckIcon(size: 12),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? VF.accent : VF.textSec,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
