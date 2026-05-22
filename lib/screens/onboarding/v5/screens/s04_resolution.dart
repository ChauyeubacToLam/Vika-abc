import 'package:flutter/material.dart';

import '../v5_primitives.dart';
import '../v5_theme.dart';

class S04Resolution extends StatelessWidget {
  const S04Resolution({
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
      index: 4,
      onBack: onBack,
      cta: V5PillCTA(label: 'Tôi sẵn sàng', onTap: onNext),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V5ScreenHeader(
            eyebrow: 'Giờ thì khác rồi',
            eyebrowSparkle: true,
            title: 'Feedback hiện lên\nngay trong buổi tập.',
            size: r.isShort ? V5HeaderSize.medium : V5HeaderSize.large,
          ),
          SizedBox(height: r.pick(cozy: V5.space16, short: V5.space10)),
          const Expanded(
            child: V5FadeIn(
              delay: Duration(milliseconds: 140),
              slideY: 12,
              child: _SessionScreenshotFrame(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionScreenshotFrame extends StatelessWidget {
  const _SessionScreenshotFrame();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = constraints.maxHeight < 290;
        final legendHeight = dense ? 30.0 : 38.0;
        final gap = dense ? 6.0 : 8.0;
        final imageHeight = constraints.maxHeight - legendHeight - gap;
        final naturalWidth = imageHeight * 9 / 16;
        final frameWidth = naturalWidth > constraints.maxWidth
            ? constraints.maxWidth
            : naturalWidth;

        return Column(
          children: [
            SizedBox(
              height: imageHeight,
              child: Center(
                child: SizedBox(
                  width: frameWidth,
                  height: imageHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(V5.radiusLg),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/onboarding/resolution.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const _PhotoPlaceholder(),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: V5.heroVignette(alpha: 0.14),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(V5.radiusLg),
                            border: Border.all(color: V5.heroBorderHi),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: gap),
            SizedBox(
              height: legendHeight,
              child: _FeedbackLegend(dense: dense),
            ),
          ],
        );
      },
    );
  }
}

class _FeedbackLegend extends StatelessWidget {
  const _FeedbackLegend({required this.dense});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendChip(
              icon: Icons.flash_on_rounded,
              label: 'Sửa form',
              dense: dense,
            ),
            SizedBox(width: dense ? 5 : 7),
            _LegendChip(
              icon: Icons.straighten_rounded,
              label: 'Góc khớp',
              dense: dense,
            ),
            SizedBox(width: dense ? 5 : 7),
            _LegendChip(
              icon: Icons.auto_graph_rounded,
              label: 'Tiến bộ',
              dense: dense,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.icon,
    required this.label,
    required this.dense,
  });

  final IconData icon;
  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: V5.ink.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(V5.radiusFull),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: V5.yellow, size: dense ? 11 : 13),
          SizedBox(width: dense ? 4 : 6),
          Text(
            label,
            maxLines: 1,
            style: V5
                .eyebrow(context, color: V5.invInk)
                .copyWith(letterSpacing: 0, height: 1),
          ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: V5.heroGradient),
      child: Stack(
        children: [
          const Center(
            child: V5AmbientGlow(
              size: Size(300, 360),
              opacity: 0.20,
              color: V5.yellow,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: V5.yellow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: V5.yellowInk,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PlaceholderLine(widthFactor: 0.62),
                          SizedBox(height: 7),
                          _PlaceholderLine(widthFactor: 0.42, soft: true),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(V5.radiusMd),
                      border: Border.all(color: V5.heroBorderHi),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: V5.invInkSoft,
                        size: 42,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'SESSION SCREENSHOT',
                  style: V5.eyebrow(context, color: V5.invInkSoft),
                ),
                const SizedBox(height: 4),
                Text(
                  'Thay bằng screenshot buổi tập thật, không cần chỉnh layout.',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: V5.caption(context, color: V5.invInkFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderLine extends StatelessWidget {
  const _PlaceholderLine({required this.widthFactor, this.soft = false});

  final double widthFactor;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: soft ? 5 : 7,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: soft ? 0.10 : 0.18),
          borderRadius: BorderRadius.circular(V5.radiusFull),
        ),
      ),
    );
  }
}
