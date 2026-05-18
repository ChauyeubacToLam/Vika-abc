import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
import '../v5_models.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S15Journey extends StatelessWidget {
  const S15Journey({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = derivePlanPersonalization(data);
    final weeks = _weeks(p);
    return V5Screen(
      index: 15,
      onBack: onBack,
      children: [
        Positioned(
          top: 144,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const V5Eyebrow(label: 'Hành trình'),
              const SizedBox(height: 10),
              Text(
                '4 chặng đường phía trước',
                style: V5.text(
                  context,
                  size: 24,
                  weight: FontWeight.w800,
                  color: V5.ink,
                  letterSpacing: -.8,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Vuốt sang để xem từng tuần. Mỗi tuần đều khác — Vika điều chỉnh theo cơ thể bạn.',
                style: V5.text(
                  context,
                  size: 12,
                  weight: FontWeight.w500,
                  color: V5.inkSoft,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 262,
          left: 20,
          right: 20,
          child: Row(
            children: weeks.asMap().entries.map((entry) {
              final i = entry.key;
              final first = i == 0;
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == weeks.length - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: first
                        ? V5.yellow
                        : V5.yellow.withValues(alpha: 0.18 + (i + 1) / 4 * 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: first
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: Transform.translate(
                            offset: const Offset(5, 0),
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: V5.yellow,
                                shape: BoxShape.circle,
                                border: Border.all(color: V5.bg, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: V5.yellow.withValues(alpha: .6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        Positioned(
          top: 286,
          left: 0,
          right: 0,
          bottom: 108,
          child: PageView.builder(
            controller: PageController(viewportFraction: .75),
            padEnds: false,
            itemCount: weeks.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.fromLTRB(index == 0 ? 16 : 6, 8, 6, 8),
                child: V5FadeIn(
                  delay: Duration(milliseconds: index * 70),
                  slideY: 8,
                  child: _WeekCard(
                    week: weeks[index],
                    level: p.level,
                    first: index == 0,
                  ),
                ),
              );
            },
          ),
        ),
        V5PillCTA(label: 'Sẵn sàng bắt đầu', onTap: onNext),
      ],
    );
  }

  List<_Week> _weeks(PlanPersonalization p) {
    // TODO(LOGIC-REFINEMENT-#9): S14 Journey — week-by-week exercise assignment is a placeholder mix from 8-exercise libraries.
    // Currently using v1 placeholder from JSX prototype. Real logic deferred to Phase 2.
    // See Notion: Vika State > Onboarding Logic Refinement block for full context.
    const homeLib = [
      'Squat',
      'Wall Push-Up',
      'Glute Bridge',
      'Bird Dog',
      'Lunge',
      'Plank',
      'Dead Bug',
      'Calf Raise',
    ];
    const yogaLib = [
      'Warrior I',
      'Forward Fold',
      'Cat-Cow',
      'Child Pose',
      'Down Dog',
      'Triangle',
      'Bridge',
      'Tree Pose',
    ];
    final lib = p.isYoga ? yogaLib : homeLib;
    return [
      _Week(
        number: 1,
        theme: 'Khởi động',
        headline: 'Làm quen với chuyển động',
        feeling:
            'Cơ thể bắt đầu nhớ form chuẩn. Có thể vẫn lúng túng, nhưng đó là dấu hiệu bạn đang học.',
        sessionCount: p.freq,
        exercises: [lib[0], lib[1], lib[2]],
        tag: 'Form chuẩn',
      ),
      _Week(
        number: 2,
        theme: 'Củng cố',
        headline: 'Form quen, sức bền tăng',
        feeling:
            'Tập xong không còn mệt như tuần 1. Cơ thể đã thích nghi — bạn sẽ thấy rõ điều này.',
        sessionCount: p.freq,
        exercises: [lib[0], lib[3], lib[4]],
        tag: 'Tăng reps',
      ),
      _Week(
        number: 3,
        theme: 'Đẩy mạnh',
        headline: 'Vượt giới hạn cũ',
        feeling:
            'Có thể tập sâu hơn, lâu hơn. Cảm giác kiểm soát body tốt hơn nhiều so với tuần 1.',
        sessionCount: p.freq,
        exercises: [lib[3], lib[5], lib[6]],
        tag: 'Sâu hơn',
      ),
      _Week(
        number: 4,
        theme: 'Đỉnh cao',
        headline: 'Đo kết quả & ăn mừng',
        feeling:
            'So sánh với tuần 1 — tiến bộ rõ rệt. Đủ tự tin để tiếp tục lộ trình tiếp theo.',
        sessionCount: p.freq,
        exercises: [lib[0], lib[1], lib[7]],
        tag: 'Đo tiến bộ',
      ),
    ];
  }
}

class _Week {
  const _Week({
    required this.number,
    required this.theme,
    required this.headline,
    required this.feeling,
    required this.sessionCount,
    required this.exercises,
    required this.tag,
  });

  final int number;
  final String theme;
  final String headline;
  final String feeling;
  final int sessionCount;
  final List<String> exercises;
  final String tag;
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.week,
    required this.level,
    required this.first,
  });

  final _Week week;
  final String level;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final minutes = level == 'advanced'
        ? 50
        : level == 'intermediate'
            ? 35
            : 25;
    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: first ? V5.heroGradient : null,
        color: first ? null : V5.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: first ? V5.heroBorder : V5.border),
        boxShadow: [V5.cardShadow(0.08)],
      ),
      child: Stack(
        children: [
          if (first)
            Positioned(
              top: -80,
              right: -70,
              width: 220,
              height: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: V5.yellow.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: first ? V5.yellow : V5.yellowSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'TUẦN',
                          style: V5.text(
                            context,
                            size: 7,
                            weight: FontWeight.w700,
                            color: first ? V5.yellowInk : V5.yellowDeep,
                            letterSpacing: .4,
                            height: 1,
                          ),
                        ),
                        Text(
                          '${week.number}',
                          style: V5.text(
                            context,
                            size: 13,
                            weight: FontWeight.w800,
                            color: first ? V5.yellowInk : V5.yellowDeep,
                            letterSpacing: -.3,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      week.theme,
                      style: V5.text(
                        context,
                        size: 14,
                        weight: FontWeight.w800,
                        color: first ? V5.invInk : V5.ink,
                        letterSpacing: -.3,
                      ),
                    ),
                  ),
                  if (first)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: V5.yellow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'BẮT ĐẦU ĐÂY',
                        style: V5.text(
                          context,
                          size: 8,
                          weight: FontWeight.w800,
                          color: V5.yellowInk,
                          letterSpacing: .4,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                week.headline,
                style: V5.text(
                  context,
                  size: 14,
                  weight: FontWeight.w800,
                  color: first ? V5.invInk : V5.ink,
                  letterSpacing: -.3,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                week.feeling,
                style: V5.text(
                  context,
                  size: 11,
                  weight: FontWeight.w500,
                  color: first ? V5.invInkSoft : V5.inkSoft,
                  height: 1.5,
                ),
              ),
              Divider(
                height: 28,
                color: first ? Colors.white.withValues(alpha: .08) : V5.border,
              ),
              Row(
                children: [
                  Text(
                    'BÀI TẬP TUẦN NÀY',
                    style: V5.text(
                      context,
                      size: 9,
                      weight: FontWeight.w700,
                      color: first ? V5.invInkSoft : V5.inkSoft,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    week.tag,
                    style: V5.text(
                      context,
                      size: 9,
                      weight: FontWeight.w700,
                      color: first ? V5.yellow : V5.yellowDeep,
                      letterSpacing: .3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...week.exercises.map(
                (ex) => Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: first ? Colors.white.withValues(alpha: .05) : V5.bgSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: first
                        ? Border.all(color: Colors.white.withValues(alpha: .08))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: V5.yellow.withValues(alpha: .18),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: V5.yellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ex,
                        style: V5.text(
                          context,
                          size: 12,
                          weight: FontWeight.w700,
                          color: first ? V5.invInk : V5.ink,
                          letterSpacing: -.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Divider(color: first ? Colors.white.withValues(alpha: .08) : V5.border),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 13, color: first ? V5.yellow : V5.yellowDeep),
                  const SizedBox(width: 5),
                  Text(
                    '${week.sessionCount} buổi',
                    style: V5.text(
                      context,
                      size: 10,
                      weight: FontWeight.w700,
                      color: first ? V5.invInk : V5.ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '~${(week.sessionCount * minutes / 60).toStringAsFixed(1)}h',
                    style: V5.text(
                      context,
                      size: 9,
                      weight: FontWeight.w600,
                      color: first ? V5.invInkSoft : V5.inkFaint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
