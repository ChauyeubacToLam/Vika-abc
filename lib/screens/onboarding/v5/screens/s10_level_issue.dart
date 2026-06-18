import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../services/recommendation/fitness_test_scoring.dart';
import '../../onboarding_data.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

/// S10 — Level. Featured recommendation: one prominent hero card for the
/// suggested level, plus two compact alternates the user can override to.
/// Replaces the old "three equal stacked options" layout.
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

  static const _levels = <_LevelSpec>[
    _LevelSpec(
      id: 'beginner',
      title: 'Người mới bắt đầu',
      stat: '15–25',
      sub: 'Đang xây nền tảng',
      desc:
          'Tập trung vào nền tảng và form chuẩn. Ít rep hơn, chú trọng kỹ thuật.',
      bullets: [
        'Bài tập nền tảng, lặp lại',
        'Tập đúng trước, tăng nhịp sau',
        'Tăng nhẹ mỗi tuần',
      ],
      intensity: 0.35,
    ),
    _LevelSpec(
      id: 'intermediate',
      title: 'Trung cấp',
      stat: '25–40',
      sub: 'Đã có nền tảng',
      desc: 'Cường độ vừa phải. Bài tập đa dạng và thử thách hơn.',
      bullets: [
        'Tổ hợp đa dạng, ít lặp đi lặp lại',
        'Thử thách tập  ở mức độ khó hơn',
        'Tập và phục hồi song song',
      ],
      intensity: 0.65,
    ),
    _LevelSpec(
      id: 'advanced',
      title: 'Nâng cao',
      stat: '40+',
      sub: 'Tập đều trên 1 năm',
      desc: 'Cường độ cao, tổ hợp bài phức tạp. Yêu cầu kỹ thuật chắc.',
      bullets: [
        'Chuỗi bài dài, cường độ cao',
        'Form yêu cầu độ chuẩn xác cao',
        'Tối ưu hiệu suất từng tuần',
      ],
      intensity: 0.95,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _recommendedId = _recommendedLevel();
    widget.data.level ??= _recommendedId;
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  String _recommendedLevel() {
    final FitnessTestScoringResult result;
    if (widget.data.fork == 'yoga') {
      result = FitnessTestScorer.score(
        FitnessTestScoringInput.fromYogaLoggers(
          warriorLogger: widget.data.hasWarriorAssessment
              ? widget.data.warriorLogger
              : null,
          forwardFoldLogger: widget.data.hasForwardFoldAssessment
              ? widget.data.forwardFoldLogger
              : null,
          trainingDuration: widget.data.duration,
        ),
      );
    } else {
      result = FitnessTestScorer.score(
        FitnessTestScoringInput.fromSquatLogger(
          logger:
              widget.data.hasSquatAssessment ? widget.data.squatLogger : null,
          wallPushUpLogger: widget.data.hasWallPushUpAssessment
              ? widget.data.wallPushUpLogger
              : null,
          trainingDuration: widget.data.duration,
        ),
      );
    }
    widget.data.levelAssessment = result;
    return result.suggestedLevel;
  }

  void _pick(String id) => setState(() => widget.data.level = id);

  int get _issueCount => widget.data.feedbackByExercise.values
      .expand((items) => items)
      .where((id) => id != 'none')
      .length;

  /// Whether any live assessment leg was captured. When false (the user skipped
  /// from S07), the suggestion comes purely from their stated training history,
  /// so the copy reflects that instead of naming a "bài đánh giá" they never did.
  bool get _assessmentDone => widget.data.fork == 'yoga'
      ? widget.data.hasWarriorAssessment || widget.data.hasForwardFoldAssessment
      : widget.data.hasSquatAssessment || widget.data.hasWallPushUpAssessment;

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    final rec = _levels.firstWhere((l) => l.id == _recommendedId);
    // Alternates: the two non-recommended levels, in their natural order.
    final alternates =
        _levels.where((l) => l.id != _recommendedId).toList(growable: false);
    final selected = widget.data.level ?? _recommendedId;

    return V5Page(
      index: 12,
      onBack: widget.onBack,
      scroll: true,
      cta: V5PillCTA(
        label: 'Tiếp tục',
        enabled: widget.data.level != null,
        onTap: widget.onNext,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V5FadeIn(
            slideY: 6,
            child: Text(
              'MỨC TẬP',
              style: V5.eyebrow(context, color: V5.inkSoft),
            ),
          ),
          SizedBox(height: r.pick(cozy: V5.space12, short: V5.space8)),
          V5FadeIn(
            delay: const Duration(milliseconds: 60),
            slideY: 10,
            child: RichText(
              text: TextSpan(
                style: r.isShort ? V5.titleLg(context) : V5.headline(context),
                children: [
                  const TextSpan(text: 'Vika gợi ý level:\n'),
                  TextSpan(
                    text: rec.title,
                    style: TextStyle(color: V5.yellowDeep),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
          SizedBox(height: r.pick(cozy: V5.space10, short: V5.space6)),
          V5FadeIn(
            delay: const Duration(milliseconds: 120),
            slideY: 8,
            child: Text(
              !_assessmentDone
                  ? 'Dựa trên kinh nghiệm bạn chia sẻ,  có thể kiểm tra lại bất cứ lúc nào để điều chỉnh.'
                  : _issueCount == 0
                      ? 'Lộ trình sẽ tăng dần mức độ dựa trên bài đánh giá.'
                      : 'Lộ trình sẽ ưu tiên $_issueCount điểm cần cải thiện từ kết quả đánh giá.',
              style: V5.body(context, color: V5.inkSoft),
              maxLines: 2,
            ),
          ),
          SizedBox(height: r.pick(cozy: V5.space24, short: V5.space16)),
          V5FadeIn(
            delay: const Duration(milliseconds: 200),
            slideY: 12,
            child: _FeaturedLevelCard(
              level: rec,
              selected: selected == rec.id,
              glow: _glowController,
              dense: r.isShort,
              onTap: () => _pick(rec.id),
            ),
          ),
          SizedBox(height: r.pick(cozy: V5.space20, short: V5.space14)),
          V5FadeIn(
            delay: const Duration(milliseconds: 280),
            slideY: 6,
            child: Text(
              'HOẶC CHỌN MỨC KHÁC',
              style: V5.eyebrow(context, color: V5.inkSoft),
            ),
          ),
          SizedBox(height: r.pick(cozy: V5.space12, short: V5.space8)),
          V5FadeIn(
            delay: const Duration(milliseconds: 320),
            slideY: 10,
            child: Row(
              children: [
                for (var i = 0; i < alternates.length; i++) ...[
                  if (i > 0) const SizedBox(width: V5.space12),
                  Expanded(
                    child: _AlternateLevelTile(
                      level: alternates[i],
                      selected: selected == alternates[i].id,
                      onTap: () => _pick(alternates[i].id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Level spec
// ─────────────────────────────────────────────────────────────

class _LevelSpec {
  const _LevelSpec({
    required this.id,
    required this.title,
    required this.stat,
    required this.sub,
    required this.desc,
    required this.bullets,
    required this.intensity,
  });

  final String id;
  final String title;
  final String stat;
  final String sub;
  final String desc;
  final List<String> bullets;
  final double intensity;
}

// ─────────────────────────────────────────────────────────────
// Featured recommendation hero — large, dark, premium
// ─────────────────────────────────────────────────────────────

class _FeaturedLevelCard extends StatelessWidget {
  const _FeaturedLevelCard({
    required this.level,
    required this.selected,
    required this.glow,
    required this.dense,
    required this.onTap,
  });

  final _LevelSpec level;
  final bool selected;
  final Animation<double> glow;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (context, _) {
        final ringT = (math.sin(glow.value * math.pi) * 0.5 + 0.5);
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: V5.curveSharp,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(V5.radiusXl),
              boxShadow: [
                ...V5.elevation3,
                if (selected)
                  BoxShadow(
                    color: V5.yellow.withValues(alpha: 0.10 + 0.10 * ringT),
                    blurRadius: 32 + 12 * ringT,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: V5HeroCard(
              borderRadius: V5.radiusXl,
              elevation: 1,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Positioned(
                    right: -90,
                    top: -90,
                    child: V5AmbientGlow(
                      size: const Size(260, 260),
                      opacity: 0.20,
                      color: V5.yellow,
                    ),
                  ),
                  const Positioned.fill(
                    child: V5Texture(opacity: 0.05, density: 1.2),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      dense ? 18 : 22,
                      dense ? 16 : 20,
                      dense ? 18 : 22,
                      dense ? 16 : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const V5Sparkle(size: 13),
                            const SizedBox(width: V5.space8),
                            Text(
                              'VIKA GỢI Ý',
                              style: V5
                                  .eyebrow(context, color: V5.yellow)
                                  .copyWith(letterSpacing: 1.6),
                            ),
                            const Spacer(),
                            if (selected)
                              const _SelectedBadge()
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius:
                                      BorderRadius.circular(V5.radiusFull),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.16),
                                  ),
                                ),
                                child: Text(
                                  'CHẠM ĐỂ CHỌN',
                                  style: V5.eyebrow(
                                    context,
                                    color: V5.invInkSoft,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: dense ? V5.space12 : V5.space16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    level.title.toUpperCase(),
                                    style: V5
                                        .displaySm(context, color: V5.invInk)
                                        .copyWith(letterSpacing: -1.1),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: V5.space6),
                                  Text(
                                    level.sub,
                                    style: V5.bodyLg(
                                      context,
                                      color: V5.invInkSoft,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: V5.space12),
                            _MinutesBlock(stat: level.stat),
                          ],
                        ),
                        SizedBox(height: dense ? V5.space14 : V5.space16),
                        _IntensityBar(value: level.intensity),
                        SizedBox(height: dense ? V5.space14 : V5.space16),
                        for (var i = 0; i < level.bullets.length; i++) ...[
                          if (i > 0) const SizedBox(height: V5.space6),
                          _BulletRow(text: level.bullets[i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: V5.yellow,
        borderRadius: BorderRadius.circular(V5.radiusFull),
        boxShadow: V5.yellowGlow(0.18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 14, color: V5.yellowInk),
          const SizedBox(width: 4),
          Text(
            'ĐÃ CHỌN',
            style: V5.eyebrow(context, color: V5.yellowInk),
          ),
        ],
      ),
    );
  }
}

class _MinutesBlock extends StatelessWidget {
  const _MinutesBlock({required this.stat});
  final String stat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          stat,
          style: V5.text(
            context,
            size: 30,
            weight: FontWeight.w800,
            letterSpacing: -1.4,
            height: 1,
            color: V5.invInk,
          ),
        ),
        const SizedBox(height: V5.space4),
        Text(
          'PHÚT/BUỔI',
          style: V5
              .eyebrow(context, color: V5.invInkSoft)
              .copyWith(letterSpacing: 1.4),
        ),
      ],
    );
  }
}

class _IntensityBar extends StatelessWidget {
  const _IntensityBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'CƯỜNG ĐỘ',
          style: V5.eyebrow(context, color: V5.invInkSoft),
        ),
        const SizedBox(width: V5.space10),
        Expanded(
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(V5.radiusFull),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: V5.curve,
                    builder: (_, t, __) => Opacity(
                      opacity: t,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [V5.yellowDeep, V5.yellow, V5.yellowSpark],
                          ),
                          borderRadius: BorderRadius.circular(V5.radiusFull),
                          boxShadow: V5.yellowGlow(0.18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(top: 7),
          decoration: const BoxDecoration(
            color: V5.yellow,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: V5.space10),
        Expanded(
          child: Text(
            text,
            style: V5.bodySm(context, color: V5.invInkSoft),
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Alternate level tile — compact, light surface, equal-width row
// ─────────────────────────────────────────────────────────────

class _AlternateLevelTile extends StatelessWidget {
  const _AlternateLevelTile({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final _LevelSpec level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: V5.curveSharp,
        padding: const EdgeInsets.fromLTRB(
          V5.space14,
          V5.space14,
          V5.space14,
          V5.space16,
        ),
        decoration: BoxDecoration(
          color: selected ? V5.ink : V5.surface,
          borderRadius: BorderRadius.circular(V5.radiusLg),
          border: Border.all(
            color: selected ? V5.ink : V5.border,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected ? V5.elevation2 : V5.elevation1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  level.stat,
                  style: V5.text(
                    context,
                    size: 22,
                    weight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1,
                    color: selected ? V5.invInk : V5.ink,
                  ),
                ),
                const SizedBox(width: V5.space6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'PHÚT',
                    style: V5.eyebrow(
                      context,
                      color: selected ? V5.invInkSoft : V5.inkSoft,
                    ),
                  ),
                ),
                const Spacer(),
                if (selected)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: V5.yellow,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: V5.yellowInk,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: V5.space10),
            Text(
              level.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V5.titleSm(
                context,
                color: selected ? V5.invInk : V5.ink,
              ),
            ),
            const SizedBox(height: V5.space2),
            Text(
              level.sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V5.bodyXs(
                context,
                color: selected ? V5.invInkSoft : V5.inkSoft,
              ),
            ),
            const SizedBox(height: V5.space10),
            _MiniIntensityDots(
              value: level.intensity,
              dark: selected,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniIntensityDots extends StatelessWidget {
  const _MiniIntensityDots({required this.value, required this.dark});

  final double value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final active = (value * 3).ceil();
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i == 2 ? 0 : 4),
              decoration: BoxDecoration(
                color: i < active
                    ? V5.yellow
                    : (dark ? V5.heroBorderHi : V5.ink.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(V5.radiusFull),
              ),
            ),
          ),
      ],
    );
  }
}
