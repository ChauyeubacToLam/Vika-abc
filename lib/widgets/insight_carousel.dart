import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/vf_theme.dart';
import 'badge_pill.dart';

class InsightCarousel extends StatefulWidget {
  const InsightCarousel({
    super.key,
    required this.items,
  });

  final List<HomeInsightData> items;

  @override
  State<InsightCarousel> createState() => _InsightCarouselState();
}

class _InsightCarouselState extends State<InsightCarousel> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final height = (MediaQuery.sizeOf(context).width * 0.5).clamp(184.0, 228.0);

    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: _controller,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: widget.items.length,
        onPageChanged: (value) => setState(() => _page = value),
        itemBuilder: (context, index) {
          final insight = widget.items[index];

          return Container(
            decoration: BoxDecoration(
              color: VFTheme.surface,
              borderRadius: BorderRadius.circular(VFTheme.cardRadius(context)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3 * VFTheme.scale(context),
                    color: insight.color,
                  ),
                ),
                Positioned(
                  top: 14 * VFTheme.scale(context),
                  right: 16 * VFTheme.scale(context),
                  child: Row(
                    children: [
                      Text(
                        '${_page + 1}/${widget.items.length}',
                        style: TextStyle(
                          fontSize: VFTheme.font(context, 11),
                          fontWeight: FontWeight.w700,
                          color: VFTheme.textMuted,
                        ),
                      ),
                      SizedBox(width: 4 * VFTheme.scale(context)),
                      ...List.generate(widget.items.length, (dotIndex) {
                        final active = dotIndex == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: active
                              ? 14 * VFTheme.scale(context)
                              : 5 * VFTheme.scale(context),
                          height: 5 * VFTheme.scale(context),
                          margin:
                              EdgeInsets.only(left: 4 * VFTheme.scale(context)),
                          decoration: BoxDecoration(
                            color: active
                                ? widget.items[_page].color
                                : VFTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(
                              4 * VFTheme.scale(context),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    18 * VFTheme.scale(context),
                    16 * VFTheme.scale(context),
                    18 * VFTheme.scale(context),
                    14 * VFTheme.scale(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'AI INSIGHT',
                            style: TextStyle(
                              fontSize: VFTheme.font(context, 10),
                              fontWeight: FontWeight.w700,
                              color: insight.color,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(width: 6 * VFTheme.scale(context)),
                          BadgePill(
                            label: insight.tag,
                            color: insight.color,
                            background: insight.background,
                            fontSize: 9,
                          ),
                        ],
                      ),
                      SizedBox(height: 8 * VFTheme.scale(context)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            insight.value,
                            style: TextStyle(
                              fontSize: VFTheme.font(context, 34),
                              fontWeight: FontWeight.w800,
                              color: VFTheme.text,
                              letterSpacing: -1.4,
                              height: 1,
                            ),
                          ),
                          SizedBox(width: 8 * VFTheme.scale(context)),
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: 4 * VFTheme.scale(context),
                            ),
                            child: Text(
                              insight.metric,
                              style: TextStyle(
                                fontSize: VFTheme.font(context, 13),
                                fontWeight: FontWeight.w500,
                                color: VFTheme.textSec,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6 * VFTheme.scale(context)),
                      Text(
                        insight.description,
                        style: VFTheme.muted(context, size: 12),
                      ),
                      const Spacer(),
                      Container(
                        height: 36 * VFTheme.scale(context),
                        decoration: BoxDecoration(
                          color: insight.background,
                          borderRadius:
                              BorderRadius.circular(8 * VFTheme.scale(context)),
                        ),
                        child: CustomPaint(
                          painter: _SparkPainter(
                            data: insight.spark,
                            color: insight.color,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.data,
    required this.color,
  });

  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) {
      return;
    }

    final maxValue = data.reduce(math.max);
    final minValue = data.reduce(math.min);
    final range = maxValue - minValue == 0 ? 1 : maxValue - minValue;

    final points = <Offset>[];
    for (var index = 0; index < data.length; index++) {
      final dx = (index / (data.length - 1)) * size.width;
      final dy = size.height -
          3 -
          ((data[index] - minValue) / range) * (size.height - 6);
      points.add(Offset(dx, dy));
    }

    final fillPath = Path()..moveTo(0, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
