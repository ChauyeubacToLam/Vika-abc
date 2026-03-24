import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/vf_theme.dart';
import '../widgets/badge_pill.dart';
import '../widgets/glow_ring.dart';
import '../widgets/section_head.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    required this.bottomPadding,
  });

  final double bottomPadding;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _exerciseIndex = 0;
  bool _showAllInsights = false;

  @override
  Widget build(BuildContext context) {
    final padding = VFTheme.screenPadding(context);
    final scale = VFTheme.scale(context);
    final visibleInsights = _showAllInsights
        ? coachInsights
        : coachInsights.where((insight) => insight.isFree).toList();
    final lockedCount =
        coachInsights.where((insight) => !insight.isFree).length;
    final comparison = formComparisons[_exerciseIndex];

    return SingleChildScrollView(
      key: const PageStorageKey<String>('progress-scroll'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        padding.left,
        14 * scale,
        padding.right,
        widget.bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tiến bộ', style: VFTheme.headerLarge(context)),
          SizedBox(height: 14 * scale),
          Container(
            padding: EdgeInsets.all(16 * scale),
            decoration: BoxDecoration(
              color: VFTheme.surface,
              borderRadius: BorderRadius.circular(VFTheme.cardRadius(context)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 28 * scale,
                      height: 28 * scale,
                      decoration: BoxDecoration(
                        color: VFTheme.accentBg,
                        borderRadius: BorderRadius.circular(8 * scale),
                      ),
                      child: Icon(
                        Icons.radar_rounded,
                        size: 16 * scale,
                        color: VFTheme.accent,
                      ),
                    ),
                    SizedBox(width: 8 * scale),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HLV AI của bạn',
                            style: TextStyle(
                              fontSize: VFTheme.font(context, 14),
                              fontWeight: FontWeight.w700,
                              color: VFTheme.text,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            '${coachInsights.length} nhận xét · Cập nhật hàng tuần',
                            style: VFTheme.muted(context, size: 10),
                          ),
                        ],
                      ),
                    ),
                    const BadgePill(label: 'Tuần 2'),
                  ],
                ),
                SizedBox(height: 12 * scale),
                for (var index = 0; index < visibleInsights.length; index++)
                  _InsightRow(
                    insight: visibleInsights[index],
                    isLast: index == visibleInsights.length - 1,
                  ),
                if (!_showAllInsights) ...[
                  SizedBox(height: 10 * scale),
                  GestureDetector(
                    onTap: () => setState(() => _showAllInsights = true),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * scale,
                        vertical: 10 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: VFTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(10 * scale),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14 * scale,
                            color: VFTheme.textMuted,
                          ),
                          SizedBox(width: 10 * scale),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '+$lockedCount nhận xét nữa',
                                  style: TextStyle(
                                    fontSize: VFTheme.font(context, 12),
                                    fontWeight: FontWeight.w700,
                                    color: VFTheme.textSec,
                                  ),
                                ),
                                Text(
                                  'Form fatigue, chi tiết bài tập, gợi ý cá nhân',
                                  style: VFTheme.muted(context, size: 10),
                                ),
                              ],
                            ),
                          ),
                          const BadgePill(label: 'PRO'),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 10 * scale),
          LayoutBuilder(
            builder: (context, constraints) {
              final ringSize =
                  (constraints.maxWidth * 0.17).clamp(58.0, 64.0).toDouble();
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10 * scale,
                  vertical: 16 * scale,
                ),
                decoration: BoxDecoration(
                  color: VFTheme.surface,
                  borderRadius:
                      BorderRadius.circular(VFTheme.cardRadius(context)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: glowMetrics.map((metric) {
                    return GlowRing(
                      valueLabel: metric.valueLabel,
                      progress: metric.progress,
                      label: metric.label,
                      color: metric.color,
                      size: ringSize,
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const SectionHead(title: 'So sánh form'),
          Container(
            padding: EdgeInsets.all(16 * scale),
            decoration: BoxDecoration(
              color: VFTheme.darkSurface,
              borderRadius: BorderRadius.circular(VFTheme.cardRadius(context)),
            ),
            child: Column(
              children: [
                Wrap(
                  spacing: 6 * scale,
                  runSpacing: 6 * scale,
                  children: List.generate(formComparisons.length, (index) {
                    final item = formComparisons[index];
                    final active = index == _exerciseIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _exerciseIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12 * scale,
                          vertical: 5 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? item.color
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6 * scale),
                        ),
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: VFTheme.font(context, 12),
                            fontWeight: FontWeight.w700,
                            color: active
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 12 * scale),
                Row(
                  children: [
                    Expanded(
                      child: _FormCard(
                        label: 'Tuần 1',
                        labelColor: Colors.white.withValues(alpha: 0.35),
                        color: VFTheme.coral,
                        data: comparison.before,
                        opacity: 0.65,
                      ),
                    ),
                    SizedBox(width: 8 * scale),
                    Expanded(
                      child: _FormCard(
                        label: 'Hôm nay',
                        labelColor: comparison.color,
                        color: comparison.color,
                        data: comparison.after,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10 * scale),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: comparison.name,
                        style: TextStyle(
                          fontSize: VFTheme.font(context, 13),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: ' / ',
                        style: TextStyle(
                          fontSize: VFTheme.font(context, 13),
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      TextSpan(
                        text: '${comparison.delta} ${comparison.label}',
                        style: TextStyle(
                          fontSize: VFTheme.font(context, 13),
                          fontWeight: FontWeight.w800,
                          color: comparison.color,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10 * scale),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10 * scale),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8 * scale),
                  ),
                  child: Wrap(
                    spacing: 6 * scale,
                    runSpacing: 6 * scale,
                    children: [
                      _FormHighlightPill(
                        label: 'Tiến bộ',
                        value: comparison.delta,
                        color: comparison.color,
                      ),
                      _FormHighlightPill(
                        label: 'Mục tiêu',
                        value: comparison.label,
                        color: const Color(0xFFFFD166),
                      ),
                      _FormHighlightPill(
                        label: 'Trọng tâm',
                        value: comparison.name,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHead(title: 'Lịch sử tập luyện'),
          LayoutBuilder(
            builder: (context, constraints) {
              final barHeight =
                  (constraints.maxWidth * 0.22).clamp(76.0, 88.0).toDouble();
              return Container(
                padding: EdgeInsets.all(16 * scale),
                decoration: BoxDecoration(
                  color: VFTheme.surface,
                  borderRadius:
                      BorderRadius.circular(VFTheme.cardRadius(context)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: weeklyCompletion.map((week) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right:
                                week == weeklyCompletion.last ? 0 : 8 * scale),
                        child: Column(
                          children: [
                            Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: VFTheme.surfaceAlt,
                                borderRadius: BorderRadius.circular(6 * scale),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: week.progress == 0
                                      ? 0
                                      : (barHeight * week.progress)
                                          .clamp(8.0, barHeight),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(6 * scale),
                                    color: week.isCurrent
                                        ? null
                                        : week.done == week.total
                                            ? VFTheme.accent
                                            : VFTheme.accent
                                                .withValues(alpha: 0.55),
                                    gradient: week.isCurrent
                                        ? const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              VFTheme.accent,
                                              Color(0x882E856E)
                                            ],
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 4 * scale),
                            Text(
                              '${week.done}/${week.total}',
                              style: TextStyle(
                                fontSize: VFTheme.font(context, 13),
                                fontWeight: FontWeight.w800,
                                color: week.isCurrent
                                    ? VFTheme.accent
                                    : week.isFuture
                                        ? VFTheme.textMuted
                                        : VFTheme.text,
                              ),
                            ),
                            SizedBox(height: 1 * scale),
                            Text(
                              week.label,
                              style: TextStyle(
                                fontSize: VFTheme.font(context, 10),
                                fontWeight: FontWeight.w600,
                                color: week.isCurrent
                                    ? VFTheme.accent
                                    : VFTheme.textMuted,
                              ),
                            ),
                            if (week.done == week.total && !week.isFuture)
                              Padding(
                                padding: EdgeInsets.only(top: 2 * scale),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 12 * scale,
                                  color: VFTheme.accent,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          SizedBox(height: 10 * scale),
          Opacity(
            opacity: 0.6,
            child: Container(
              padding: EdgeInsets.all(14 * scale),
              decoration: BoxDecoration(
                color: VFTheme.surface,
                borderRadius:
                    BorderRadius.circular(VFTheme.cardRadius(context)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36 * scale,
                    height: 36 * scale,
                    decoration: BoxDecoration(
                      color: VFTheme.accentBg,
                      borderRadius: BorderRadius.circular(10 * scale),
                    ),
                    child: Icon(
                      Icons.article_outlined,
                      size: 18 * scale,
                      color: VFTheme.accent,
                    ),
                  ),
                  SizedBox(width: 12 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Báo cáo AI hàng tuần',
                          style: TextStyle(
                            fontSize: VFTheme.font(context, 13),
                            fontWeight: FontWeight.w700,
                            color: VFTheme.text,
                          ),
                        ),
                        SizedBox(height: 2 * scale),
                        Text(
                          'Nhận xét chi tiết bằng AI về form, xu hướng, và gợi ý cá nhân hóa mỗi tuần',
                          style: TextStyle(
                            fontSize: VFTheme.font(context, 11),
                            fontWeight: FontWeight.w600,
                            color: VFTheme.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const BadgePill(label: 'PRO'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.insight,
    required this.isLast,
  });

  final CoachInsightData insight;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scale = VFTheme.scale(context);

    return Container(
      padding: EdgeInsets.symmetric(vertical: 10 * scale),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: VFTheme.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28 * scale,
            height: 28 * scale,
            decoration: BoxDecoration(
              color: insight.background,
              borderRadius: BorderRadius.circular(8 * scale),
            ),
            alignment: Alignment.center,
            child: Text(
              insight.iconText,
              style: TextStyle(
                fontSize: VFTheme.font(context, 13),
                fontWeight: FontWeight.w800,
                color: insight.color,
              ),
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontSize: VFTheme.font(context, 13),
                    fontWeight: FontWeight.w700,
                    color: VFTheme.text,
                  ),
                ),
                SizedBox(height: 2 * scale),
                Text(
                  insight.detail,
                  style: TextStyle(
                    fontSize: VFTheme.font(context, 11),
                    fontWeight: FontWeight.w500,
                    color: VFTheme.textMuted,
                    height: 1.4,
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

class _FormHighlightPill extends StatelessWidget {
  const _FormHighlightPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scale = VFTheme.scale(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6 * scale),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontSize: VFTheme.font(context, 10),
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: VFTheme.font(context, 10),
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.label,
    required this.labelColor,
    required this.color,
    required this.data,
    this.opacity = 1,
  });

  final String label;
  final Color labelColor;
  final Color color;
  final AngleFigureData data;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final scale = VFTheme.scale(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8 * scale,
        vertical: 10 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: VFTheme.font(context, 9),
              fontWeight: FontWeight.w700,
              color: labelColor,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 4 * scale),
          SizedBox(
            width: 60 * scale,
            height: 90 * scale,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FormFigurePainter(
                      color: color,
                      data: data,
                      opacity: opacity,
                    ),
                  ),
                ),
                Positioned(
                  left: (data.knee.dx + 10) * scale,
                  top: (data.knee.dy - 4) * scale,
                  child: Text(
                    data.angle,
                    style: TextStyle(
                      fontSize: VFTheme.font(context, 10),
                      fontWeight: FontWeight.w800,
                      color: color.withValues(alpha: opacity),
                    ),
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

class _FormFigurePainter extends CustomPainter {
  _FormFigurePainter({
    required this.color,
    required this.data,
    required this.opacity,
  });

  final Color color;
  final AngleFigureData data;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 60;
    final scaleY = size.height / 90;

    Offset point(Offset input) => Offset(input.dx * scaleX, input.dy * scaleY);

    final hip = point(data.hip);
    final knee = point(data.knee);
    final ankle = point(data.ankle);

    final linePaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final jointFill = Paint()..color = color.withValues(alpha: 0.3 * opacity);
    final jointStroke = Paint()
      ..color = color.withValues(alpha: 0.5 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(hip, knee, linePaint);
    canvas.drawLine(knee, ankle, linePaint);
    canvas.drawCircle(knee, 4 * scaleX, jointFill);
    canvas.drawCircle(knee, 4 * scaleX, jointStroke);
  }

  @override
  bool shouldRepaint(covariant _FormFigurePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.data != data ||
        oldDelegate.opacity != opacity;
  }
}
