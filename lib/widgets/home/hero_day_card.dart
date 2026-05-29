// HeroDayCard — the dominant moment of the Home screen. Warm-dark card
// with an italic two-line title, four-stat grid, optional FigureSkeleton
// pose-tracking artifact (only when isToday=true), and a CTA pill.
//
// Used inside a horizontal scroller — current day's card is wide-expressive,
// next day's peeks in from the right at reduced contrast (cream raised).
//
// Mirrors `HeroDayCard` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../plan/plan_painters.dart';
import '../plan/plan_typography.dart';
import '../../theme/app_colors.dart';

class HeroDayStat {
  const HeroDayStat(
      {required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
}

class HeroDayCard extends StatelessWidget {
  const HeroDayCard({
    super.key,
    required this.eyebrow,
    required this.titleLine1,
    required this.titleLine2,
    required this.stats,
    required this.cta,
    this.onCta,
    this.isToday = false,
  });

  final String eyebrow; // 'HÔM NAY · BUỔI 03'
  final String titleLine1; // 'Toàn'
  final String titleLine2; // 'thân nhẹ'
  final List<HeroDayStat> stats;
  final String cta; // 'Bắt đầu Buổi 3'
  final VoidCallback? onCta;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // Compose a screen-reader summary of the whole card.
    // e.g. "Hôm nay · Buổi 03. Toàn thân nhẹ. 15 phút, Beginner.
    //       Nhấn để bắt đầu."
    final semanticsLabel = [
      eyebrow.toLowerCase(),
      '$titleLine1 $titleLine2.',
      ...stats.map((s) => '${s.value} ${s.label}'),
      cta,
    ].join(' · ');
    return Semantics(
      button: onCta != null,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 326,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: isToday
                  ? LinearGradient(
                      begin: const Alignment(-0.6, -1),
                      end: const Alignment(0.6, 1),
                      colors: [c.bgInverse, c.bgInverseHi],
                    )
                  : null,
              color: isToday ? null : c.bgRaised,
              borderRadius: BorderRadius.circular(28),
              border: isToday ? null : Border.all(color: c.border),
            ),
            child: Stack(
              children: [
                // FigureSkeleton overlay — only on today's card.
                if (isToday)
                  Positioned(
                    right: -10,
                    bottom: 96,
                    child: Opacity(
                      opacity: 0.85,
                      child: SizedBox(
                        width: 130,
                        height: 200,
                        child: const CustomPaint(
                          painter: FigureSkeletonPainter(),
                        ),
                      ),
                    ),
                  ),
                // Card body.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlanEyebrow(
                      eyebrow,
                      size: 9,
                      letterSpacing: 1.8,
                      color: isToday ? c.yellow : c.inkSoft,
                    ),
                    const SizedBox(height: 14),
                    PlanH1(
                      titleLine1,
                      size: 46,
                      letterSpacing: -3,
                      height: 0.92,
                      dark: isToday,
                    ),
                    PlanH1(
                      titleLine2,
                      size: 46,
                      letterSpacing: -3,
                      height: 0.92,
                      italic: false,
                      dark: isToday,
                    ),
                    const SizedBox(height: 22),
                    _StatGrid(stats: stats, dark: isToday),
                    const SizedBox(height: 24),
                    _CtaButton(
                      label: cta,
                      dark: isToday,
                      onTap: onCta ?? () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats, required this.dark});

  final List<HeroDayStat> stats;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        children: [
          for (var row = 0; row < (stats.length / 2).ceil(); row++)
            Padding(
              padding: EdgeInsets.only(
                  bottom: row == (stats.length / 2).ceil() - 1 ? 0 : 12),
              child: Row(
                children: [
                  Expanded(child: _StatTile(stat: stats[row * 2], dark: dark)),
                  const SizedBox(width: 12),
                  if (row * 2 + 1 < stats.length)
                    Expanded(
                        child: _StatTile(stat: stats[row * 2 + 1], dark: dark))
                  else
                    const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, required this.dark});

  final HeroDayStat stat;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final iconBg = dark ? c.invInk.withValues(alpha: 0.08) : c.bg;
    final iconBorder = dark ? c.borderDark : c.border;
    final iconColor = dark ? c.yellow : c.ink;
    final valueColor = dark ? c.invInk : c.ink;
    final labelColor = dark ? c.invInkFaint : c.inkFaint;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconBorder),
          ),
          alignment: Alignment.center,
          child: Icon(stat.icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stat.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  height: 1.1,
                  color: valueColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stat.label,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton(
      {required this.label, required this.dark, required this.onTap});

  final String label;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final bg = dark ? c.bg : c.ink;
    final fg = dark ? c.ink : c.invInk;
    final knobBg = dark ? c.ink : c.yellow;
    final knobFg = dark ? c.yellow : c.ink;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: fg,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration:
                    BoxDecoration(color: knobBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child:
                    Icon(Icons.arrow_forward_rounded, size: 16, color: knobFg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
