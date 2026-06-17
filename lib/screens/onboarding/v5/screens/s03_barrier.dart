import 'package:flutter/material.dart';

import '../v5_primitives.dart';
import '../v5_theme.dart';

class S03Barrier extends StatelessWidget {
  const S03Barrier({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    return V5Page(
      index: 3,
      onBack: onBack,
      cta: V5PillCTA(label: 'Còn cách nào khác?', onTap: onNext),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // State the cost as a fact, no opinion language.
          V5ScreenHeader(
            eyebrow: 'PT 1-1 tại Việt Nam',
            title: 'Một buổi:\n400.000 – 2.000.000 ₫',
            subtitle: r.isShort
                ? null
                : 'Theo khảo sát giá tại các chuỗi gym lớn ở TP.HCM & Hà Nội, 2024.',
          ),
          SizedBox(height: r.pick(cozy: V5.space20, short: V5.space14)),
          Expanded(
            child: V5FadeIn(
              delay: const Duration(milliseconds: 220),
              slideY: 14,
              child: const _CostComparisonHero(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CostComparisonHero extends StatelessWidget {
  const _CostComparisonHero();

  @override
  Widget build(BuildContext context) {
    return V5HeroCard(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CHI PHÍ MỘT NĂM',
                  style: V5.eyebrow(context, color: V5.invInkSoft),
                ),
                Text(
                  '3 BUỔI/TUẦN',
                  style: V5.eyebrow(context, color: V5.yellow),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(V5.radiusFull),
                border: Border.all(color: V5.heroBorderHi),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      size: 14, color: V5.yellow),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '3 buổi/tuần × 52 tuần, tính theo giá phổ biến ở các chuỗi gym.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V5.caption(context, color: V5.invInkSoft),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Bar chart — PT vs Vika.
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1100),
                curve: V5.curve,
                builder: (context, t, _) => _CostBars(progress: t),
              ),
            ),

            const SizedBox(height: 18),

            // One clean summary so the chart stays punchy without repeating.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(V5.radiusSm),
                border: Border.all(color: V5.heroBorderHi),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calculate_outlined,
                      size: 14, color: V5.yellow),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: V5.bodySm(context, color: V5.invInkSoft),
                        children: const [
                          TextSpan(text: 'Tiết kiệm đến '),
                          TextSpan(
                            text: '59 triệu',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: V5.yellow,
                            ),
                          ),
                          TextSpan(
                            text: ' cho cùng một giải pháp.',
                          ),
                        ],
                      ),
                      maxLines: 2,
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

class _CostBars extends StatelessWidget {
  const _CostBars({required this.progress});

  /// 0..1 reveal progress for the bars.
  final double progress;

  @override
  Widget build(BuildContext context) {
    // VND amounts shown as easy-to-read labels.
    final ptCost = (60.0 * progress).clamp(0.0, 60.0);
    final vikaCost = (1.0 * progress).clamp(0.0, 1.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _Bar(
            label: 'PT 1-1',
            sub: 'phòng gym',
            value: '${ptCost.toStringAsFixed(0)}tr',
            valueColor: V5.invInkSoft,
            heightFraction: progress,
            barColor: V5.invInk.withValues(alpha: 0.12),
            barBorder: V5.invInk.withValues(alpha: 0.22),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _Bar(
            label: 'Vika AI',
            sub: 'tại nhà',
            value: '~${(vikaCost * 1).toStringAsFixed(1)}tr',
            valueColor: V5.yellow,
            heightFraction: progress * (1 / 60),
            barColor: V5.yellow,
            barBorder: V5.yellow,
            highlight: true,
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.sub,
    required this.value,
    required this.valueColor,
    required this.heightFraction,
    required this.barColor,
    required this.barBorder,
    this.highlight = false,
  });

  final String label;
  final String sub;
  final String value;
  final Color valueColor;
  final double heightFraction;
  final Color barColor;
  final Color barBorder;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row — name + sub.
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: V5.titleSm(context, color: V5.invInk),
        ),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: V5.caption(context, color: V5.invInkFaint),
        ),
        const SizedBox(height: 10),
        // Value label — fixed height, OUTSIDE the bar's Stack so it can
        // never be cut off when the bar reaches full height. This was the
        // bug on the Gym (60tr) bar at full progress.
        SizedBox(
          height: 26,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V5.text(
                context,
                size: 20,
                weight: FontWeight.w800,
                color: valueColor,
                letterSpacing: -0.8,
                height: 1.0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Bar area — Expanded. Bar grows from bottom; its max height
        // is exactly the Expanded space, so it can never overflow.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight;
              final h = maxHeight <= 4
                  ? maxHeight
                  : (maxHeight * heightFraction).clamp(4.0, maxHeight);
              return Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            V5.invInk.withValues(alpha: 0.04),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(V5.radiusXs),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: h,
                    child: Container(
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(V5.radiusXs),
                        border: Border.all(color: barBorder, width: 1),
                        boxShadow: highlight
                            ? V5.yellowGlow(0.32)
                            : const <BoxShadow>[],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
