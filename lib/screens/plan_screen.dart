import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/vf_theme.dart';
import '../widgets/badge_pill.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.bottomPadding,
  });

  final double bottomPadding;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  int _weekIndex = 0;

  @override
  Widget build(BuildContext context) {
    final padding = VFTheme.screenPadding(context);
    final scale = VFTheme.scale(context);
    final week = planWeeks[_weekIndex];

    return SingleChildScrollView(
      key: const PageStorageKey<String>('plan-scroll'),
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
          Text('Kế hoạch tập', style: VFTheme.headerLarge(context)),
          SizedBox(height: 14 * scale),
          Container(
            padding: EdgeInsets.all(16 * scale),
            decoration: BoxDecoration(
              color: VFTheme.surface,
              borderRadius: BorderRadius.circular(VFTheme.cardRadius(context)),
            ),
            child: Row(
              children: [
                _CompactRing(
                  value: week.workouts,
                  total: 7,
                  size: 48 * scale,
                ),
                SizedBox(width: 14 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chương trình cơ bản',
                        style: TextStyle(
                          fontSize: VFTheme.font(context, 15),
                          fontWeight: FontWeight.w700,
                          color: VFTheme.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2 * scale),
                      Text(
                        week.subtitle,
                        style: VFTheme.muted(context, size: 12),
                      ),
                    ],
                  ),
                ),
                const BadgePill(label: '4 tuần'),
              ],
            ),
          ),
          SizedBox(height: 14 * scale),
          Row(
            children: List.generate(planWeeks.length, (index) {
              final item = planWeeks[index];
              final active = index == _weekIndex;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == planWeeks.length - 1 ? 0 : 6 * scale,
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _weekIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * scale,
                        vertical: 10 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: active ? VFTheme.accent : VFTheme.surface,
                        borderRadius: BorderRadius.circular(10 * scale),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: VFTheme.font(context, 13),
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : VFTheme.textSec,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 14 * scale),
          Padding(
            padding: EdgeInsets.only(left: 20 * scale),
            child: Stack(
              children: [
                Positioned(
                  left: 7 * scale,
                  top: 8 * scale,
                  bottom: 8 * scale,
                  child: Container(
                    width: 2 * scale,
                    decoration: BoxDecoration(
                      color: VFTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(scale),
                    ),
                  ),
                ),
                Column(
                  children: week.days.map((day) {
                    return day.isRest
                        ? _RestTimelineRow(day: day)
                        : _WorkoutTimelineCard(day: day);
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactRing extends StatelessWidget {
  const _CompactRing({
    required this.value,
    required this.total,
    required this.size,
  });

  final int value;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _CompactRingPainter(progress: value / total),
          ),
          Center(
            child: Text(
              '$value/$total',
              style: TextStyle(
                fontSize: VFTheme.font(context, 14),
                fontWeight: FontWeight.w800,
                color: VFTheme.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactRingPainter extends CustomPainter {
  _CompactRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(4, size.width * 0.09).toDouble();
    final radius = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = VFTheme.surfaceAlt
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final active = Paint()
      ..color = VFTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(rect, -math.pi / 2, progress * 2 * math.pi, false, active);
  }

  @override
  bool shouldRepaint(covariant _CompactRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _RestTimelineRow extends StatelessWidget {
  const _RestTimelineRow({required this.day});

  final PlanDayData day;

  @override
  Widget build(BuildContext context) {
    final scale = VFTheme.scale(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6 * scale),
      child: Row(
        children: [
          Transform.translate(
            offset: Offset(-16 * scale, 0),
            child: Container(
              width: 8 * scale,
              height: 8 * scale,
              decoration: BoxDecoration(
                color: VFTheme.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: VFTheme.bg, width: 2 * scale),
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${day.shortDay} · Nghỉ ngơi',
              style: TextStyle(
                fontSize: VFTheme.font(context, 11),
                fontWeight: FontWeight.w500,
                color: VFTheme.textMuted.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutTimelineCard extends StatelessWidget {
  const _WorkoutTimelineCard({required this.day});

  final PlanDayData day;

  @override
  Widget build(BuildContext context) {
    final scale = VFTheme.scale(context);

    return Padding(
      padding: EdgeInsets.only(bottom: 8 * scale),
      child: Stack(
        children: [
          Positioned(
            left: -18 * scale,
            top: 14 * scale,
            child: Container(
              width: 12 * scale,
              height: 12 * scale,
              decoration: BoxDecoration(
                color: day.color,
                shape: BoxShape.circle,
                border: Border.all(color: VFTheme.bg, width: 2.5 * scale),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: VFTheme.surface,
              borderRadius: BorderRadius.circular(VFTheme.cardRadius(context)),
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3 * scale, color: day.color),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(14 * scale),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  day.label.toUpperCase(),
                                  style:
                                      VFTheme.label(context, color: day.color),
                                ),
                              ),
                              Text(
                                day.duration,
                                style: TextStyle(
                                  fontSize: VFTheme.font(context, 10),
                                  fontWeight: FontWeight.w600,
                                  color: VFTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            day.focus,
                            style: TextStyle(
                              fontSize: VFTheme.font(context, 16),
                              fontWeight: FontWeight.w800,
                              color: VFTheme.text,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2 * scale),
                          Text(
                            '${day.exerciseCount} bài tập · Cơ bản',
                            style: VFTheme.muted(context, size: 12),
                          ),
                          SizedBox(height: 8 * scale),
                          Wrap(
                            spacing: 4 * scale,
                            runSpacing: 4 * scale,
                            children: day.muscles.map((muscle) {
                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8 * scale,
                                  vertical: 3 * scale,
                                ),
                                decoration: BoxDecoration(
                                  color: muscle.color.withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(4 * scale),
                                ),
                                child: Text(
                                  muscle.name,
                                  style: TextStyle(
                                    fontSize: VFTheme.font(context, 10),
                                    fontWeight: FontWeight.w700,
                                    color: muscle.color,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 8 * scale),
                          Padding(
                            padding: EdgeInsets.only(top: 8 * scale),
                            child: Wrap(
                              spacing: 2 * scale,
                              children: List.generate(
                                day.exercisePreview.length,
                                (index) {
                                  final exercise = day.exercisePreview[index];
                                  final suffix =
                                      index < day.exercisePreview.length - 1
                                          ? ' ·'
                                          : '';
                                  return Text(
                                    '$exercise$suffix',
                                    style: TextStyle(
                                      fontSize: VFTheme.font(context, 10),
                                      fontWeight: FontWeight.w600,
                                      color: VFTheme.textMuted,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                          Container(
                            height: 3 * scale,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: day.muscles
                                    .map((muscle) => muscle.color)
                                    .toList(),
                              ),
                              borderRadius: BorderRadius.circular(2 * scale),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
