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
        ? const [
            (
              name: 'Warrior I',
              vi: 'Tư thế chiến binh',
              hold: '20–30 giây',
              icon: Icons.self_improvement_rounded,
              focus: 'thăng bằng, hông, thân người',
            ),
            (
              name: 'Forward Fold',
              vi: 'Cúi gập chậm',
              hold: '1 lần chậm',
              icon: Icons.airline_seat_legroom_extra_rounded,
              focus: 'gân kheo, lưng, hông',
            ),
          ]
        : const [
            (
              name: 'Squat',
              vi: 'Ngồi xuống / đứng lên',
              hold: '5 lần chậm',
              icon: Icons.fitness_center_rounded,
              focus: 'gối, hông, lưng',
            ),
            (
              name: 'Wall Push-Up',
              vi: 'Đẩy tường',
              hold: '5 lần chậm',
              icon: Icons.accessibility_new_rounded,
              focus: 'vai, khuỷu tay, thân người',
            ),
          ];
    final r = V5Responsive.of(context);
    final tight = r.size.height < 700;
    return V5Page(
      index: 9,
      onBack: onBack,
      cta: V5PillCTA(label: 'Bắt đầu đánh giá', onTap: onNext),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V5ScreenHeader(
            eyebrow: 'Đánh giá ban đầu',
            title: 'Làm 2 động tác.\nNhận level & plan.',
            size: tight ? V5HeaderSize.medium : V5HeaderSize.large,
          ),
          SizedBox(height: r.pick(cozy: V5.space16, short: V5.space10)),
          // Hero now flex-takes available space instead of fighting a
          // fixed height + an output panel below. The page was too dense.
          Expanded(
            flex: 5,
            child: V5FadeIn(
              delay: const Duration(milliseconds: 140),
              child: _AssessmentHero(isYoga: isYoga),
            ),
          ),
          SizedBox(height: r.pick(cozy: V5.space16, short: V5.space10)),
          Text(
            'BẠN SẼ LÀM',
            style: V5.eyebrow(context, color: V5.inkSoft),
          ),
          SizedBox(height: r.pick(cozy: V5.space8, short: V5.space6)),
          ...exercises.asMap().entries.map((entry) {
            final i = entry.key;
            final ex = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: i == exercises.length - 1
                    ? 0
                    : r.pick(cozy: V5.space8, short: V5.space6),
              ),
              child: V5FadeIn(
                delay: Duration(milliseconds: 260 + i * 100),
                slideY: 8,
                child: _StepRow(
                  index: i + 1,
                  name: ex.name,
                  vi: ex.vi,
                  hold: ex.hold,
                  focus: ex.focus,
                  icon: ex.icon,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Assessment hero — movement-first rationale
// ─────────────────────────────────────────────────────────────

class _AssessmentHero extends StatelessWidget {
  const _AssessmentHero({required this.isYoga});

  final bool isYoga;

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    final compact = r.isShort;
    final tight = r.size.height < 700;
    return V5HeroCard(
      borderRadius: V5.radiusLg,
      elevation: 2,
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -50,
            child: V5AmbientGlow(
              size: const Size(240, 240),
              opacity: 0.20,
              color: V5.yellow,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              tight
                  ? 12
                  : compact
                      ? 14
                      : 18,
              18,
              tight ? 12 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const V5PulseDot(color: V5.yellow),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'REAL MOVEMENT CHECK',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V5.eyebrow(context, color: V5.invInkSoft),
                      ),
                    ),
                    _AssessmentBadge(label: isYoga ? 'YOGA' : 'HOME'),
                  ],
                ),
                const Spacer(),
                Text(
                  isYoga
                      ? 'Thực hiện 2 tư thế sau.'
                      : 'Thực hiện 2 động tác sau.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (tight
                          ? V5.title(context, color: V5.invInk)
                          : compact
                              ? V5.titleLg(context, color: V5.invInk)
                              : V5.headline(context, color: V5.invInk))
                      .copyWith(height: 1.05),
                ),
                SizedBox(height: tight ? V5.space4 : V5.space8),
                Text(
                  'Vika xem form để gợi ý level, điểm cần cải thiện và plan.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: V5.bodySm(context, color: V5.invInkSoft),
                ),
                if (!tight) ...[
                  const Spacer(),
                  Row(
                    children: const [
                      Expanded(child: _FlowStep(label: 'Đo form')),
                      SizedBox(width: V5.space8),
                      Expanded(child: _FlowStep(label: 'Gợi ý level')),
                      SizedBox(width: V5.space8),
                      Expanded(child: _FlowStep(label: 'Lập plan')),
                    ],
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

class _AssessmentBadge extends StatelessWidget {
  const _AssessmentBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: V5.yellow,
        borderRadius: BorderRadius.circular(V5.radiusFull),
      ),
      child: Text(
        label,
        style: V5
            .eyebrow(context, color: V5.yellowInk)
            .copyWith(letterSpacing: 1.0),
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(V5.radiusSm),
        border: Border.all(color: V5.heroBorderHi),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: V5
            .eyebrow(context, color: V5.invInkSoft)
            .copyWith(letterSpacing: 0.6),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Step row — numbered exercise preview
// ─────────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.name,
    required this.vi,
    required this.hold,
    required this.focus,
    required this.icon,
  });

  final int index;
  final String name;
  final String vi;
  final String hold;
  final String focus;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tight = V5Responsive.of(context).size.height < 700;
    return V5Card(
      padding: EdgeInsets.symmetric(
        horizontal: V5.space14,
        vertical: tight ? V5.space8 : V5.space10,
      ),
      borderRadius: V5.radiusMd,
      child: Row(
        children: [
          Container(
            width: tight ? 38 : 44,
            height: tight ? 38 : 44,
            decoration: BoxDecoration(
              color: V5.ink,
              borderRadius: BorderRadius.circular(V5.radiusSm),
            ),
            alignment: Alignment.center,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: V5.text(
                context,
                size: tight ? 14 : 16,
                weight: FontWeight.w800,
                color: V5.yellow,
                letterSpacing: -0.5,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V5.titleSm(context),
                      ),
                    ),
                    const SizedBox(width: V5.space8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: V5.yellowSoft,
                        borderRadius: BorderRadius.circular(V5.radiusXs),
                      ),
                      child: Text(
                        hold,
                        style: V5
                            .eyebrow(context, color: V5.yellowDeep)
                            .copyWith(letterSpacing: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: V5.space2),
                Text(
                  '$vi · đo $focus',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tight
                      ? V5.bodyXs(context, color: V5.inkSoft)
                      : V5.bodySm(context, color: V5.inkSoft),
                ),
              ],
            ),
          ),
          Icon(icon, color: V5.inkSoft, size: tight ? 17 : 20),
        ],
      ),
    );
  }
}
