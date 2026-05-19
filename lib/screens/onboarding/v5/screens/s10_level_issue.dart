import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../services/recommendation/fitness_test_scoring.dart';
import '../../onboarding_data.dart';
import '../v5_models.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S10LevelIssue extends StatefulWidget {
  const S10LevelIssue({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<S10LevelIssue> createState() => _S10LevelIssueState();
}

class _S10LevelIssueState extends State<S10LevelIssue>
    with SingleTickerProviderStateMixin {
  late final String _recommendedId;
  late final AnimationController _glowController;

  static const _levels = [
    (
      id: 'beginner',
      title: 'Người mới',
      stat: '15-25 phút',
      sub: 'Đang xây nền tảng',
      desc:
          'Tập trung vào nền tảng & form chuẩn. Ít reps, nhiều thời gian học.',
      pose: 'reach',
    ),
    (
      id: 'intermediate',
      title: 'Trung cấp',
      stat: '25-40 phút',
      sub: 'Đã có kinh nghiệm',
      desc: 'Cường độ vừa phải. Bài tập đa dạng & thử thách hơn.',
      pose: 'lunge',
    ),
    (
      id: 'advanced',
      title: 'Nâng cao',
      stat: '40+ phút',
      sub: 'Tập đều 1+ năm',
      desc: 'Cường độ cao + tổ hợp bài. Yêu cầu thực hiện chuẩn.',
      pose: 'tree',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _recommendedId = _recommendedLevel();
    widget.data.level ??= _recommendedId;
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  String _recommendedLevel() {
    if (widget.data.fork == 'yoga') {
      final results = yogaResultsMock;
      final allValues = results.expand((r) => r.chartData).toList();
      final totalCandidates = results.fold<int>(
        0,
        (sum, r) => sum + r.candidates.where((c) => c.id != 'none').length,
      );
      final confirmedIssues = widget.data.feedbackByExercise.values.fold<int>(
        0,
        (sum, items) => sum + items.where((id) => id != 'none').length,
      );
      return FitnessTestScorer.score(
        FitnessTestScoringInput(
          fork: widget.data.fork,
          trainingDuration: widget.data.duration,
          yogaAssessment: YogaMobilityAssessment(
            chartValues: allValues,
            chartTarget: results.first.chartTarget,
            totalIssueCandidates: totalCandidates,
            confirmedIssueCount: confirmedIssues,
          ),
        ),
      ).suggestedLevel;
    }

    return FitnessTestScorer.score(
      FitnessTestScoringInput.fromSquatLogger(
        logger: widget.data.hasSquatAssessment ? widget.data.squatLogger : null,
        trainingDuration: widget.data.duration,
      ),
    ).suggestedLevel;
  }

  String _reasoning() {
    final issueCount = widget.data.feedbackByExercise.values
        .expand((items) => items)
        .where((id) => id != 'none')
        .length;
    if (_recommendedId == 'beginner') {
      if (issueCount > 0) {
        return 'Có $issueCount điểm cần luyện — Vika sẽ giúp xây nền tảng vững';
      }
      if (widget.data.duration == null || widget.data.duration == '<3m') {
        return 'Còn mới với tập luyện — bắt đầu chậm để form chuẩn';
      }
      return 'Form ổn nhưng nên luyện từ nền tảng để tránh chấn thương';
    }
    if (_recommendedId == 'intermediate') {
      return 'Form tốt + có kinh nghiệm — sẵn sàng cho cường độ vừa';
    }
    return 'Form xuất sắc + nền tảng vững — sẵn sàng cường độ cao';
  }

  void _pick(String id) {
    setState(() => widget.data.level = id);
    if (id != _recommendedId) _glowController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final rec = _levels.firstWhere((l) => l.id == _recommendedId);
    final ordered = _recommendedId == 'beginner'
        ? ['beginner', 'intermediate', 'advanced']
        : _recommendedId == 'intermediate'
            ? ['intermediate', 'beginner', 'advanced']
            : ['advanced', 'intermediate', 'beginner'];
    return V5Screen(
      index: 10,
      onBack: widget.onBack,
      children: [
        Positioned(
          top: 144,
          left: 16,
          right: 16,
          height: 184,
          child: V5FadeIn(
            child: V5HeroCard(
              child: Stack(
                children: [
                  const Positioned(
                    top: 18,
                    left: 18,
                    child: V5Eyebrow(
                      label: 'Vika gợi ý',
                      dark: true,
                      sparkle: true,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: -30,
                    bottom: 0,
                    width: 220,
                    child: V5HeroFigure(pose: rec.pose),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 20,
                    width: 210,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VIKA NGHĨ',
                          style: V5.text(
                            context,
                            size: 11,
                            weight: FontWeight.w600,
                            color: V5.invInkSoft,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          rec.title,
                          style: V5.text(
                            context,
                            size: 30,
                            weight: FontWeight.w800,
                            color: V5.invInk,
                            letterSpacing: -1,
                            height: 0.95,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _reasoning(),
                          style: V5.text(
                            context,
                            size: 11,
                            weight: FontWeight.w500,
                            color: V5.invInkSoft,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 344,
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Text(
                  'CHỌN MỨC TẬP CỦA BẠN',
                  style: V5.text(
                    context,
                    size: 10,
                    weight: FontWeight.w700,
                    color: V5.inkSoft,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 112),
                  children: ordered.asMap().entries.map((entry) {
                    final i = entry.key;
                    final level =
                        _levels.firstWhere((l) => l.id == entry.value);
                    final selected = widget.data.level == level.id;
                    final recommended = level.id == _recommendedId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: V5FadeIn(
                        delay: Duration(milliseconds: i * 60),
                        slideY: 8,
                        child: _LevelCard(
                          level: level,
                          selected: selected,
                          recommended: recommended,
                          pulse: recommended && !selected,
                          glow: _glowController,
                          onTap: () => _pick(level.id),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        V5PillCTA(
          label: 'Tiếp tục',
          enabled: widget.data.level != null,
          onTap: widget.onNext,
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.selected,
    required this.recommended,
    required this.pulse,
    required this.glow,
    required this.onTap,
  });

  final ({
    String id,
    String title,
    String stat,
    String sub,
    String desc,
    String pose,
  }) level;
  final bool selected;
  final bool recommended;
  final bool pulse;
  final Animation<double> glow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (context, _) {
        final ring = pulse ? math.sin(glow.value * math.pi) : 0.0;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? V5.ink : V5.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? V5.ink
                    : recommended
                        ? V5.yellow.withValues(alpha: 0.55)
                        : V5.border,
              ),
              boxShadow: [
                selected ? V5.cardShadow(0.18) : V5.cardShadow(0.08),
                if (ring > 0)
                  BoxShadow(
                    color: V5.yellow.withValues(alpha: 0.35 * ring),
                    spreadRadius: 8 * ring,
                    blurRadius: 1,
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: selected
                        ? V5.yellow.withValues(alpha: 0.18)
                        : V5.yellowSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        level.stat.split(' ').first,
                        style: V5.text(
                          context,
                          size: 13,
                          weight: FontWeight.w800,
                          color: V5.yellowDeep,
                          letterSpacing: -0.4,
                          height: 1,
                        ),
                      ),
                      Text(
                        'PHÚT',
                        style: V5.text(
                          context,
                          size: 8,
                          weight: FontWeight.w700,
                          color: V5.yellowDeep,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            level.title,
                            style: V5.text(
                              context,
                              size: 15,
                              weight: FontWeight.w800,
                              color: selected ? V5.invInk : V5.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (recommended && !selected)
                            _tag('Gợi ý', false, context),
                          if (selected) _tag('Đã chọn', true, context),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        level.sub,
                        style: V5.text(
                          context,
                          size: 11,
                          weight: FontWeight.w500,
                          color: selected ? V5.invInkSoft : V5.inkSoft,
                          height: 1.3,
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(height: 6),
                        Divider(
                            color: Colors.white.withValues(alpha: 0.10),
                            height: 1),
                        const SizedBox(height: 6),
                        Text(
                          level.desc,
                          style: V5.text(
                            context,
                            size: 11,
                            weight: FontWeight.w500,
                            color: V5.invInkSoft,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tag(String label, bool selected, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? V5.yellow : V5.yellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: selected
            ? null
            : Border.all(color: V5.yellow.withValues(alpha: 0.40)),
      ),
      child: Text(
        label.toUpperCase(),
        style: V5.text(
          context,
          size: 8,
          weight: FontWeight.w800,
          color: selected ? V5.yellowInk : V5.yellowDeep,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
