import 'package:flutter/material.dart';

import '../onboarding_data.dart';
import '../vf_theme.dart';

class LevelIssuePage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const LevelIssuePage({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<LevelIssuePage> createState() => _LevelIssuePageState();
}

class _LevelIssuePageState extends State<LevelIssuePage> {
  late final String _predictedLevel;
  late String _selectedLevel;

  static const _levels = [
    (
      id: 'beginner',
      title: 'Người mới',
      desc: 'Tập trung vào nền tảng, form sạch, tiến bộ ổn định.',
      preview: '3 buổi/tuần • 10-12 phút • bodyweight cơ bản',
    ),
    (
      id: 'intermediate',
      title: 'Trung bình',
      desc: 'Có nền tảng vận động và sẵn sàng tăng tải dần.',
      preview: '3-4 buổi/tuần • 12-15 phút • volume cao hơn',
    ),
    (
      id: 'advanced',
      title: 'Khá tốt',
      desc: 'Có thể chịu khối lượng tập lớn hơn và tiến độ nhanh hơn.',
      preview: '4-5 buổi/tuần • 15+ phút • intensity cao hơn',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _predictedLevel = _computeLevel();
    _selectedLevel = _predictedLevel;
    widget.data.confirmedLevel = _predictedLevel;
  }

  String _computeLevel() {
    final good = (widget.data.squatLogger.setLogs['good_rep_count'] as int?) ?? 0;
    final total = widget.data.squatLogger.repLogs.length;
    final formRatio = total == 0 ? 0.0 : good / total;
    final weightedScore = formRatio + (widget.data.frequencyScore * 0.12);

    if (weightedScore >= 0.88) return 'advanced';
    if (weightedScore >= 0.52) return 'intermediate';
    return 'beginner';
  }

  @override
  Widget build(BuildContext context) {
    final issueQuestion = widget.data.squatInterpreter.getQuestion();
    final hasIssue = issueQuestion.isNotEmpty;

    return Column(
      children: [
        VFProgressBar(current: 4, total: 7, onBack: widget.onBack),
        Expanded(
          child: VFFitViewport(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI đề xuất điểm bắt đầu',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: VF.text,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Prediction này dùng cả squat result lẫn tần suất tập bạn đã chọn ở trang đầu.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: VF.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                ..._levels.map(_buildLevelCard),
                if (hasIssue) ...[
                  const SizedBox(height: 14),
                  _IssueCard(
                    question: issueQuestion,
                    answer: widget.data.issueAnswer,
                    onChanged: (value) => setState(() {
                      widget.data.issueAnswer = value;
                    }),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: VFButton(label: 'Tiếp tục', onTap: widget.onNext),
        ),
      ],
    );
  }

  Widget _buildLevelCard(
    ({String id, String title, String desc, String preview}) level,
  ) {
    final on = _selectedLevel == level.id;
    final predicted = _predictedLevel == level.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedLevel = level.id;
          widget.data.confirmedLevel = level.id;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: on ? VF.accentSoft : VF.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: on ? VF.accent.withValues(alpha: 0.28) : VF.border,
              width: 1.5,
            ),
            boxShadow: on ? VF.cardShadow : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                              level.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: on ? VF.accent : VF.text,
                              ),
                            ),
                            if (predicted) ...[
                              const SizedBox(width: 8),
                              const VFPill(label: 'AI gợi ý'),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          level.desc,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: VF.textMuted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  VFCheckIcon(size: 14, filled: on),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: on ? VF.surface : VF.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: VF.border),
                ),
                child: Text(
                  level.preview,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: VF.textSec,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final String question;
  final String? answer;
  final ValueChanged<String> onChanged;

  const _IssueCard({
    required this.question,
    required this.answer,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VF.amberSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VF.amber.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI noticed one thing',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: VF.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            question,
            style: const TextStyle(
              fontSize: 12.8,
              color: VF.textSec,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _IssueButton(
                  label: 'Có, đúng vậy',
                  selected: answer == 'yes',
                  onTap: () => onChanged('yes'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IssueButton(
                  label: 'Không, tôi ổn',
                  selected: answer == 'no',
                  onTap: () => onChanged('no'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IssueButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _IssueButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? VF.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? VF.accent.withValues(alpha: 0.28) : VF.border,
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
                  fontSize: 12.2,
                  fontWeight: FontWeight.w700,
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
