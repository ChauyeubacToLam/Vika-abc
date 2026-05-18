import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S07AssessmentIntro extends StatelessWidget {
  const S07AssessmentIntro({
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
    final isYoga = data.fork == 'yoga';
    final exercises = isYoga
        ? [
            ('Warrior I', 'Tư thế chiến binh', 'Giữ trong 30 giây', 'lunge'),
            ('Standing Forward Fold', 'Cúi gập người', 'Giãn cơ hông & gân kheo', 'reach'),
          ]
        : [
            ('Squat', 'Ngồi xổm', '5 reps', 'squat'),
            ('Wall Push-Up', 'Đẩy tường', '5 reps', 'reach'),
          ];
    return V5Screen(
      index: 7,
      onBack: onBack,
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
                    child: V5Eyebrow(label: 'Bước tiếp theo', dark: true),
                  ),
                  Positioned(
                    top: 0,
                    right: -30,
                    bottom: 0,
                    width: 220,
                    child: V5HeroFigure(pose: exercises.first.$4),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 20,
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ĐÁNH GIÁ BAN ĐẦU',
                          style: V5.text(
                            context,
                            size: 11,
                            weight: FontWeight.w600,
                            color: V5.invInkSoft,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '2 bài tập\nđơn giản',
                          style: V5.text(
                            context,
                            size: 24,
                            weight: FontWeight.w800,
                            color: V5.invInk,
                            letterSpacing: -0.8,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Vika sẽ phân tích chuyển động của bạn',
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
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 2),
                        child: Text(
                          'BẠN SẼ LÀM',
                          style: V5.text(
                            context,
                            size: 10,
                            weight: FontWeight.w700,
                            color: V5.inkSoft,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      ...exercises.asMap().entries.map((entry) {
                        final i = entry.key;
                        final ex = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: V5FadeIn(
                            delay: Duration(milliseconds: i * 70),
                            slideY: 8,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: V5.surface,
                                border: Border.all(color: V5.border),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [V5.cardShadow(0.08)],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: V5.yellowSoft,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${i + 1}',
                                      style: V5.text(
                                        context,
                                        size: 18,
                                        weight: FontWeight.w800,
                                        color: V5.yellowDeep,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ex.$1,
                                          style: V5.text(
                                            context,
                                            size: 15,
                                            weight: FontWeight.w800,
                                            color: V5.ink,
                                            letterSpacing: -0.3,
                                            height: 1.2,
                                          ),
                                        ),
                                        Text(
                                          '${ex.$2} · ${ex.$3}',
                                          style: V5.text(
                                            context,
                                            size: 11,
                                            weight: FontWeight.w500,
                                            color: V5.inkSoft,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: Opacity(
                                      opacity: 0.6,
                                      child: V5HeroFigure(pose: ex.$4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: V5.yellow.withValues(alpha: 0.07),
                          border: Border.all(color: V5.yellow.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: V5.yellowDeep, size: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Camera trước sẽ ghi lại để phân tích — chỉ mất 2 phút.',
                                style: V5.text(
                                  context,
                                  size: 11,
                                  weight: FontWeight.w500,
                                  color: V5.inkSoft,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
        V5PillCTA(label: 'Bắt đầu đánh giá', onTap: onNext),
      ],
    );
  }
}
