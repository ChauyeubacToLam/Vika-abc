// ExerciseInsightGrid — the BÀI TẬP NỔI BẬT section, reimagined as a 2-up
// gallery of compact, visualization-first cards. Each card trades the old
// full-width paragraph for a single glance:
//
//   ghost rank numeral · exercise name · one metric eyebrow ·
//   an animated bar chart that always CLIMBS toward "better" ·
//   one hero stat in a yellow medallion.
//
// The bar chart is the centerpiece — values are oriented by [lowerIsBetter]
// so a falling fault and a rising hold both read as a climb, with the final
// "today" bar lit in reserved yellow. Premium Ivory tokens only.

import 'package:flutter/material.dart';

import '../../data/progress_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart' show VikaIvoryMain;

class ExerciseInsightGrid extends StatefulWidget {
  const ExerciseInsightGrid({
    super.key,
    required this.insights,
    this.collapsedCount = 4,
  });

  final List<ExerciseInsightMock> insights;

  /// How many cards (a whole number of rows) show before "Xem tất cả".
  final int collapsedCount;

  @override
  State<ExerciseInsightGrid> createState() => _ExerciseInsightGridState();
}

class _ExerciseInsightGridState extends State<ExerciseInsightGrid> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final all = widget.insights;
    if (all.isEmpty) return const SizedBox.shrink();

    final visible =
        _expanded ? all : all.take(widget.collapsedCount).toList();
    final hidden = all.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _InsightCard(mock: visible[i])),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < visible.length
                        ? _InsightCard(mock: visible[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        if (!_expanded && hidden > 0)
          _GridCta(
            label: 'Xem tất cả ${all.length} bài',
            sub: 'Sắp xếp theo mức tiến bộ',
            icon: Icons.arrow_downward_rounded,
            onTap: () => setState(() => _expanded = true),
          )
        else if (_expanded && all.length > widget.collapsedCount)
          _GridCta(
            label: 'Thu gọn',
            icon: Icons.arrow_upward_rounded,
            onTap: () => setState(() => _expanded = false),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CARD — ghost numeral + name + metric + bar chart + hero stat
// ═══════════════════════════════════════════════════════════════

class _InsightCard extends StatefulWidget {
  const _InsightCard({required this.mock});

  final ExerciseInsightMock mock;

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  )..forward();

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final mock = widget.mock;
    final rank = int.tryParse(mock.idx) ?? 0;
    final isTop = rank == 1;
    final stat = (mock.stat != null && mock.stat!.isNotEmpty)
        ? mock.stat!
        : mock.improvement;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isTop ? c.borderHi : c.border),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: c.ink.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Oversized editorial ghost numeral — luxury, not information.
          Positioned(
            top: -26,
            right: -2,
            child: Text(
              mock.idx,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 92,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: -4,
                height: 1,
                color: isTop
                    ? c.yellow.withValues(alpha: 0.12)
                    : c.ink.withValues(alpha: 0.045),
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metric eyebrow — the only descriptive text on the card.
                Text(
                  mock.metric.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: c.inkFaint,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  mock.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.7,
                    height: 1,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  width: 24,
                  height: 3,
                  decoration: BoxDecoration(
                    color: c.yellow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                _BarChart(
                  values: mock.chart,
                  lowerIsBetter: mock.lowerIsBetter,
                  entry: _entry,
                  c: c,
                ),
                const SizedBox(height: 16),
                // Hero stat — yellow medallion (the "you improved" signal)
                // + magnitude. No sentence, no direction prose.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: c.yellow.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.trending_up_rounded,
                        size: 16,
                        color: c.yellowInk,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stat,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.9,
                          height: 1,
                          color: c.ink,
                          fontFeatures: VikaIvoryMain.tabularFigures,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BAR CHART — values oriented so progress always climbs; the final
// "today" bar lit in yellow. Bars rise on a staggered entrance.
// ═══════════════════════════════════════════════════════════════

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.values,
    required this.lowerIsBetter,
    required this.entry,
    required this.c,
  });

  final List<int> values;
  final bool lowerIsBetter;
  final Animation<double> entry;
  final VikaColors c;

  static const double _height = 58;
  static const double _minBar = 7;

  @override
  Widget build(BuildContext context) {
    final n = values.length;
    if (n == 0) return const SizedBox(height: _height);

    var lo = values.first.toDouble();
    var hi = values.first.toDouble();
    for (final v in values) {
      if (v < lo) lo = v.toDouble();
      if (v > hi) hi = v.toDouble();
    }
    final range = (hi - lo).abs();

    // Goodness 0..1: how far each session sits toward the "better" end.
    double goodness(int i) {
      if (range == 0) return 1; // flat series → all full (rare in ranking)
      final v = values[i].toDouble();
      return lowerIsBetter ? (hi - v) / range : (v - lo) / range;
    }

    return SizedBox(
      height: _height,
      child: AnimatedBuilder(
        animation: entry,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < n; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(child: _bar(i, n, goodness(i))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Container(
                height: 1,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(int i, int n, double g) {
    // Staggered grow-up: each bar opens slightly after the one to its left.
    final start = (i / n) * 0.5;
    final raw = ((entry.value - start) / 0.5).clamp(0.0, 1.0);
    final t = Curves.easeOutCubic.transform(raw);

    final full = _minBar + g.clamp(0.0, 1.0) * (_height - 9 - _minBar);
    final isToday = i == n - 1;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: full * t,
        decoration: BoxDecoration(
          color: isToday
              ? c.yellow
              : c.ink.withValues(alpha: 0.10 + g * 0.16),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: c.yellow.withValues(alpha: 0.45),
                    blurRadius: 9,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EXPAND / COLLAPSE CTA
// ═══════════════════════════════════════════════════════════════

class _GridCta extends StatelessWidget {
  const _GridCta({
    required this.label,
    required this.icon,
    required this.onTap,
    this.sub,
  });

  final String label;
  final String? sub;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.borderHi),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: c.ink,
                      ),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub!,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                          color: c.inkFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
                child: Icon(icon, size: 13, color: c.bg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
