// IntentCollection — curated bundle of exercises grouped by intent (e.g.
// "Khởi động sáng", "Tối yên"). Renders one large hero card + two smaller
// secondary cards in a 2-column mosaic.
//
// Mirrors `IntentCollection`, `CollectionHeroCard`, and `CollectionSmallCard`
// in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../data/library_mock.dart';
import '../../theme/vf_theme.dart';
import '../ivory/atoms.dart';
import '../plan/plan_typography.dart';
import '../../theme/app_colors.dart';
class IntentCollection extends StatelessWidget {
  const IntentCollection({super.key, required this.mock});

  final IntentCollectionMock mock;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  mock.idx,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.8,
                    height: 1,
                    color: c.inkGhost,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlanEyebrow(mock.eyebrow, size: 9, letterSpacing: 1.6),
                    const SizedBox(height: 4),
                    PlanH1(
                      mock.title,
                      size: 18,
                      letterSpacing: -0.6,
                      height: 1.05,
                    ),
                    const SizedBox(height: 6),
                    PlanP(mock.subtitle, size: 11, soft: true, height: 1.4),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 2-col mosaic.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _HeroCard(ex: mock.hero)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < mock.small.length; i++) ...[
                        Expanded(child: _SmallCard(ex: mock.small[i])),
                        if (i < mock.small.length - 1) const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Footer.
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Xem cả bộ →',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: c.inkSoft,
                    ),
                  ),
                ),
                Text(
                  '${mock.small.length + 1} / ${mock.small.length + 1}',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: c.inkFaint,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.ex});

  final CollectionExerciseMock ex;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgInverse,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: IgnorePointer(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.yellow.withValues(alpha: 0.10),
                      c.yellow.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.invInk.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: PoseGlyph(type: ex.glyph, size: 26, dark: true),
                  ),
                  const Spacer(),
                  if (ex.ai) const AIDot(),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                ex.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  height: 1.15,
                  color: c.invInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ex.meta,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: c.invInkFaint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  const _SmallCard({required this.ex});

  final CollectionExerciseMock ex;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ex.yoga ? c.powder : c.bgInverse,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: ColorFiltered(
              colorFilter: ex.yoga
                  ? const ColorFilter.matrix([
                      0.4, 0, 0, 0, 0,
                      0, 0.4, 0, 0, 0,
                      0, 0, 0.4, 0, 0,
                      0, 0, 0, 1, 0,
                    ])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: PoseGlyph(
                type: ex.glyph,
                size: 22,
                dark: !ex.yoga,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ex.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: c.ink,
                        ),
                      ),
                    ),
                    if (ex.ai) ...[
                      const SizedBox(width: 5),
                      const AIDot(small: true),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  ex.meta,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: c.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
