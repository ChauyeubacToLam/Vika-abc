import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
import '../v5_models.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S14Outcomes extends StatelessWidget {
  const S14Outcomes({
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
    final bodyOutcome = _bodyOutcome(p);
    final habitOutcome = (
      title: 'Tập ${p.freq} buổi/tuần thành phản xạ',
      body:
          'Không còn cảm giác phải ép mình. Sau 4 tuần, mở app & tập sẽ tự nhiên như đánh răng buổi sáng.',
    );
    final confidenceOutcome = _confidenceOutcome(p.level);
    return V5Screen(
      index: 14,
      onBack: onBack,
      children: [
        Positioned(
          top: 144,
          left: 16,
          right: 16,
          height: 200, // 188 → 200; old value overflowed by 1px with Inter
          child: V5FadeIn(
            child: V5HeroCard(
              borderRadius: 24,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const V5Eyebrow(
                      label: 'Đích đến · Cá nhân hoá',
                      dark: true,
                      sparkle: true,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sau 4 tuần,\nbạn sẽ...',
                      style: V5.text(
                        context,
                        size: 24,
                        weight: FontWeight.w800,
                        color: V5.invInk,
                        letterSpacing: -.7,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Đây là 3 điều cụ thể bạn sẽ cảm nhận được — dựa trên đánh giá thật của cơ thể bạn.',
                      style: V5.text(
                        context,
                        size: 11,
                        weight: FontWeight.w500,
                        color: V5.invInkSoft,
                        height: 1.4,
                      ),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _chip(context, p.levelLabel),
                        _chip(context, '${p.freq} buổi/tuần'),
                        _chip(context, p.goalLabel),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 360, // 348 → 360 to clear the new 200px hero
          left: 16,
          right: 16,
          bottom: 108,
          child: Column(
            children: [
              ProgramOutcomeCard(
                delay: 0,
                icon: Icons.accessibility_new_rounded,
                title: bodyOutcome.title,
                body: bodyOutcome.body,
              ),
              const SizedBox(height: 8),
              ProgramOutcomeCard(
                delay: 80,
                icon: Icons.schedule_rounded,
                title: habitOutcome.title,
                body: habitOutcome.body,
              ),
              const SizedBox(height: 8),
              ProgramOutcomeCard(
                delay: 160,
                icon: Icons.star_border_rounded,
                title: confidenceOutcome.title,
                body: confidenceOutcome.body,
              ),
            ],
          ),
        ),
        V5PillCTA(label: 'Xem hành trình 4 tuần', onTap: onNext),
      ],
    );
  }

  Widget _chip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(color: V5.yellow, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: V5.text(
              context,
              size: 9,
              weight: FontWeight.w700,
              color: V5.invInk,
            ),
          ),
        ],
      ),
    );
  }

  ({String title, String body}) _bodyOutcome(PlanPersonalization p) {
    if (p.hasBackPain) {
      return (
        title: 'Lưng đỡ đau, vận động linh hoạt',
        body:
            'Bạn sẽ thấy cúi xuống, ngồi lâu, đứng dậy đỡ căng hơn. Đau lưng giảm rõ rệt từ tuần 2.',
      );
    }
    if (p.goal == 'flexibility' || p.goal == 'flexible' || p.isYoga) {
      return (
        title: 'Cơ thể linh hoạt, đỡ cứng',
        body:
            'Sáng dậy đỡ cứng người. Cúi gập, vặn người, với tay dễ dàng hơn — như cơ thể trẻ lại 5 năm.',
      );
    }
    if (p.goal == 'weight_loss' || p.goal == 'body') {
      return (
        title: 'Cảm giác nhẹ nhàng & gọn gàng hơn',
        body:
            'Quần áo vừa hơn ở vùng eo. Leo cầu thang đỡ thở dốc. Cơ thể chắc chắn hơn từng tuần.',
      );
    }
    if (p.goal == 'muscle' || p.goal == 'strength') {
      return (
        title: 'Cơ bắp săn chắc & khoẻ hơn',
        body:
            'Bê đồ, mang vác hằng ngày thấy nhẹ tay hơn. Cơ thể có sức bền cho cả ngày dài.',
      );
    }
    return (
      title: 'Cơ thể khoẻ & vận động dễ hơn',
      body:
          'Đứng dậy không kêu đau, leo cầu thang không thở dốc. Cử động hằng ngày trơn tru hơn nhiều.',
    );
  }

  ({String title, String body}) _confidenceOutcome(String level) {
    if (level == 'advanced') {
      return (
        title: 'Bứt phá khỏi plateau cũ',
        body:
            'Bạn sẽ thấy mình tập sâu hơn, lâu hơn, kiểm soát body tốt hơn — vượt mức quen thuộc cũ.',
      );
    }
    if (level == 'intermediate') {
      return (
        title: 'Tự tin & năng lượng đầy ngày',
        body:
            'Form chuẩn hơn, tập có chiến lược. Buổi sáng dậy nhiều năng lượng, ngủ sâu hơn buổi tối.',
      );
    }
    return (
      title: 'Tự tin với chuyển động',
      body:
          'Hết sợ sai form, hết ngại tập trước gương. Bạn sẽ thấy mình thuộc về thế giới của người tập đều.',
    );
  }
}

class ProgramOutcomeCard extends StatelessWidget {
  const ProgramOutcomeCard({
    super.key,
    required this.delay,
    required this.icon,
    required this.title,
    required this.body,
  });

  final int delay;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return V5FadeIn(
      delay: Duration(milliseconds: delay),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: V5.yellowSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: V5.yellowDeep, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: V5.text(
                      context,
                      size: 13,
                      weight: FontWeight.w800,
                      color: V5.ink,
                      letterSpacing: -.2,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: V5.text(
                      context,
                      size: 11,
                      weight: FontWeight.w500,
                      color: V5.inkSoft,
                      height: 1.45,
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
