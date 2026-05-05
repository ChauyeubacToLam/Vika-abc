import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S11BodyInfo extends StatefulWidget {
  const S11BodyInfo({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<S11BodyInfo> createState() => _S11BodyInfoState();
}

class _S11BodyInfoState extends State<S11BodyInfo>
    with SingleTickerProviderStateMixin {
  String _activeMetric = 'height';
  late AnimationController _bmiController;
  late Animation<double> _bmiTween;
  double _animatedBmi = 22.0;

  int get _height => (widget.data.heightCm ?? 165).round();
  int get _weight => (widget.data.weightKg ?? 60).round();
  int get _age => widget.data.age ?? 28;
  double get _bmi => _weight / math.pow(_height / 100, 2);

  @override
  void initState() {
    super.initState();
    widget.data.heightCm ??= 165;
    widget.data.weightKg ??= 60;
    widget.data.age ??= 28;
    _animatedBmi = _bmi;
    _bmiController = AnimationController(
      duration: const Duration(milliseconds: 240),
      vsync: this,
    );
    _bmiTween = AlwaysStoppedAnimation(_animatedBmi);
  }

  @override
  void dispose() {
    _bmiController.dispose();
    super.dispose();
  }

  void _setMetricValue(int value) {
    setState(() {
      switch (_activeMetric) {
        case 'height':
          widget.data.heightCm = value.toDouble();
          break;
        case 'weight':
          widget.data.weightKg = value.toDouble();
          break;
        case 'age':
          widget.data.age = value;
          break;
      }
      _animateBmi();
    });
  }

  void _animateBmi() {
    final start = _animatedBmi;
    final target = _bmi;
    _bmiTween = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(parent: _bmiController, curve: Curves.easeOutCubic),
    )..addListener(() {
        if (mounted) setState(() => _animatedBmi = _bmiTween.value);
      });
    _bmiController.forward(from: 0);
  }

  _BmiZone _zone(double bmi) {
    // TODO(LOGIC-REFINEMENT-#6): S10 BodyInfo — BMI zone nuance uses WHO Asia-Pacific static zones without athlete adjustment.
    // Currently using v1 placeholder from JSX prototype. Real logic deferred to Phase 2.
    // See Notion: Vika State > Onboarding Logic Refinement block for full context.
    if (bmi < 18.5) {
      return const _BmiZone('Hơi gầy', Color(0xFF7DA3D9));
    }
    if (bmi < 23) return const _BmiZone('Cân đối', V5.yellow);
    if (bmi < 25) return const _BmiZone('Hơi tròn', Color(0xFFE89A4B));
    return const _BmiZone('Cần chú ý', Color(0xFFD67B3E));
  }

  @override
  Widget build(BuildContext context) {
    final zone = _zone(_animatedBmi);
    final metrics = [
      _Metric('height', 'Chiều cao', _height, 'cm', 140, 210),
      _Metric('weight', 'Cân nặng', _weight, 'kg', 35, 150),
      _Metric('age', 'Tuổi', _age, 'tuổi', 16, 80),
    ];
    final active = metrics.firstWhere((m) => m.id == _activeMetric);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return V5Screen(
      index: 11,
      onBack: widget.onBack,
      children: [
        // Single Column flow from below the chrome to just above the CTA.
        // Hero is part of the column, content is Expanded+scrollable, so on
        // any screen size everything composes without overflowing into the
        // ruler or off the bottom.
        Positioned(
          top: 144,
          left: 0,
          right: 0,
          bottom: 32 + 60 + bottomInset + 12,
          child: Column(
            children: [
              // Hero card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: V5FadeIn(
                  child: SizedBox(
                    height: 200,
                    child: V5HeroCard(
                      borderRadius: 24,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _BodyInfoHeroPainter(
                                height: _height,
                                weight: _weight,
                                age: _age,
                                gender: widget.data.gender,
                              ),
                            ),
                          ),
                          const Positioned(
                            top: 14,
                            left: 16,
                            child:
                                V5Eyebrow(label: 'Vóc dáng của bạn', dark: true),
                          ),
                          Positioned(
                            right: 14,
                            bottom: 12,
                            child: V5Glass(
                              child: Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'BMI',
                                        style: V5.text(
                                          context,
                                          size: 7,
                                          weight: FontWeight.w700,
                                          color: V5.invInkSoft,
                                          letterSpacing: .8,
                                          height: 1,
                                        ),
                                      ),
                                      Text(
                                        _animatedBmi.toStringAsFixed(1),
                                        style: V5.text(
                                          context,
                                          size: 13,
                                          weight: FontWeight.w800,
                                          color: V5.invInk,
                                          letterSpacing: -.3,
                                          height: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 1,
                                    height: 20,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    color: Colors.white.withValues(alpha: .15),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 320),
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: zone.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    zone.label,
                                    style: V5.text(
                                      context,
                                      size: 10,
                                      weight: FontWeight.w700,
                                      color: V5.invInk,
                                      letterSpacing: -.1,
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
                ),
              ),
              const SizedBox(height: 18),
              // Content area — scrollable so no overflow on short screens.
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: V5.bgSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: metrics.map((m) {
                            final isActive = _activeMetric == m.id;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _activeMetric = m.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 9, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? V5.ink
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: isActive
                                        ? [V5.cardShadow(0.18)]
                                        : null,
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        m.label.toUpperCase(),
                                        style: V5.text(
                                          context,
                                          size: 10,
                                          weight: FontWeight.w700,
                                          color: isActive
                                              ? V5.invInkSoft
                                              : V5.inkSoft,
                                          letterSpacing: .4,
                                        ),
                                      ),
                                      Text(
                                        '${m.value} ${m.unit}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: V5.text(
                                          context,
                                          size: 14,
                                          weight: FontWeight.w800,
                                          color:
                                              isActive ? V5.yellow : V5.ink,
                                          letterSpacing: -.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      V5RulerPicker(
                        key: ValueKey(active.id),
                        value: active.value,
                        min: active.min,
                        max: active.max,
                        unit: active.unit,
                        onChanged: _setMetricValue,
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            'GIỚI TÍNH',
                            style: V5.text(
                              context,
                              size: 10,
                              weight: FontWeight.w700,
                              color: V5.inkSoft,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _genderChip('male', 'Nam'),
                          const SizedBox(width: 6),
                          _genderChip('female', 'Nữ'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        V5PillCTA(
          label: 'Tiếp tục',
          disabledLabel: 'Chọn giới tính',
          enabled: widget.data.gender != null,
          onTap: widget.onNext,
          bottom: 32 + bottomInset,
        ),
      ],
    );
  }

  Widget _genderChip(String id, String label) {
    final selected = widget.data.gender == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => widget.data.gender = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? V5.ink : V5.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? V5.ink : V5.border),
            boxShadow: [selected ? V5.cardShadow(0.18) : V5.cardShadow(0.08)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                const V5CheckCircle(selected: true, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: V5.text(
                  context,
                  size: 14,
                  weight: FontWeight.w700,
                  color: selected ? V5.invInk : V5.ink,
                  letterSpacing: -.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class V5RulerPicker extends StatefulWidget {
  const V5RulerPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  State<V5RulerPicker> createState() => _V5RulerPickerState();
}

class _V5RulerPickerState extends State<V5RulerPicker> {
  static const tickWidth = 10.0;
  late final ScrollController _controller;
  Timer? _snapTimer;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: (widget.value - widget.min) * tickWidth,
    );
  }

  @override
  void dispose() {
    _snapTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final value =
        (widget.min + (_controller.offset / tickWidth).round()).clamp(widget.min, widget.max);
    if (value != widget.value) widget.onChanged(value);
    _snapTimer?.cancel();
    _snapTimer = Timer(const Duration(milliseconds: 100), () {
      if (!_controller.hasClients) return;
      final target = (value - widget.min) * tickWidth;
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalTicks = widget.max - widget.min + 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
      decoration: BoxDecoration(
        color: V5.surface,
        border: Border.all(color: V5.border),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [V5.cardShadow(0.08)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Value display with EXPLICIT height. Baseline alignment + Inter
          // metrics was making the Row's intrinsic height ~7px taller than
          // expected (ascent + descent > 48px font size). Explicit SizedBox
          // + center alignment prevents font-metric-induced overflow.
          SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${widget.value}',
                  style: V5.text(
                    context,
                    size: 44,
                    weight: FontWeight.w800,
                    color: V5.ink,
                    letterSpacing: -1.6,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    widget.unit,
                    style: V5.text(
                      context,
                      size: 16,
                      weight: FontWeight.w700,
                      color: V5.inkSoft,
                      letterSpacing: -.4,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            // 64 → 72 for buffer. ListView item Columns with major ticks
            // + text label have natural heights that vary by font, and
            // the IgnorePointer marker line is 50px — buffer keeps both
            // safely inside.
            height: 72,
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (_) {
                    _onScroll();
                    return false;
                  },
                  child: ListView.builder(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.sizeOf(context).width / 2 - 21,
                    ),
                    itemCount: totalTicks,
                    itemBuilder: (context, index) {
                      final num = widget.min + index;
                      final major = num % 10 == 0;
                      final mid = num % 5 == 0 && !major;
                      final tickHeight = major ? 32.0 : mid ? 22.0 : 14.0;
                      return SizedBox(
                        width: tickWidth,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            Container(
                              width: major ? 2 : 1,
                              height: tickHeight,
                              color: major
                                  ? V5.ink
                                  : mid
                                      ? V5.inkSoft
                                      : V5.inkFaint,
                            ),
                            if (major)
                              Positioned(
                                top: tickHeight + 2,
                                child: Text(
                                  '$num',
                                  textAlign: TextAlign.center,
                                  style: V5.text(
                                    context,
                                    size: 9,
                                    weight: FontWeight.w700,
                                    color: V5.inkSoft,
                                    height: 1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                IgnorePointer(
                  child: Center(
                    child: Column(
                      children: [
                        CustomPaint(
                          size: const Size(12, 8),
                          painter: _TrianglePainter(),
                        ),
                        Container(
                          width: 2,
                          height: 42,
                          decoration: BoxDecoration(
                            color: V5.yellow,
                            boxShadow: [
                              BoxShadow(
                                color: V5.yellow.withValues(alpha: .5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = V5.yellow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Metric {
  const _Metric(this.id, this.label, this.value, this.unit, this.min, this.max);
  final String id;
  final String label;
  final int value;
  final String unit;
  final int min;
  final int max;
}

class _BmiZone {
  const _BmiZone(this.label, this.color);
  final String label;
  final Color color;
}

class _BodyInfoHeroPainter extends CustomPainter {
  const _BodyInfoHeroPainter({
    required this.height,
    required this.weight,
    required this.age,
    required this.gender,
  });

  final int height;
  final int weight;
  final int age;
  final String? gender;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Logical canvas is 320x200 — scale to fit the hero card.
    final sx = size.width / 320;
    final sy = size.height / 200;
    canvas.scale(sx, sy);
    final tp = TextPainter(textDirection: TextDirection.ltr);

    // ── Height ruler (left side) ───────────────────────────────────
    // Range y=60..168 in painter coords. The top is pushed below 60 so
    // the marker pill (which sits at markerY-8) can never overlap the
    // "Vóc dáng của bạn" eyebrow at painter y≈14-30.
    const rulerTop = 60.0;
    const rulerBottom = 168.0;
    const rulerSpan = rulerBottom - rulerTop;
    final tickPaint = Paint()
      ..color = V5.yellow.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    // 9 evenly-spaced ticks across the ruler, every 4th major.
    for (var i = 0; i < 9; i++) {
      final y = rulerTop + i * (rulerSpan / 8);
      canvas.drawLine(
        Offset(48, y),
        Offset(i % 4 == 0 ? 60 : 55, y),
        tickPaint,
      );
    }
    _text(canvas, tp, '210', const Offset(38, rulerTop - 3),
        V5.yellow.withValues(alpha: 0.5), 7,
        alignRight: true);
    _text(canvas, tp, '140', const Offset(38, rulerBottom),
        V5.yellow.withValues(alpha: 0.5), 7,
        alignRight: true);

    // Active marker — clamped so the pill never overlaps the eyebrow.
    final markerY = rulerBottom - ((height - 140) / 70) * rulerSpan;
    canvas.drawLine(
      Offset(48, markerY),
      Offset(68, markerY),
      Paint()
        ..color = V5.yellow
        ..strokeWidth = 2,
    );
    canvas.drawCircle(Offset(68, markerY), 3.5, Paint()..color = V5.yellow);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(74, markerY - 8, 42, 16),
        const Radius.circular(8),
      ),
      Paint()..color = V5.yellow,
    );
    _text(canvas, tp, '$height cm', Offset(95, markerY - 5),
        V5.yellowInk, 9, center: true);

    // ── Body silhouette (centre) ───────────────────────────────────
    // Drawn as a yellow stroke + faint inner fill. The previous solid
    // dark fill (#1A1209) was identical to heroBgDeep, making the body
    // invisible against the gradient.
    _drawBody(canvas);

    // ── Weight callout (right side, mid) ────────────────────────────
    const weightPillRect = Rect.fromLTWH(216, 108, 60, 18);
    canvas.drawLine(
      const Offset(190, 118),
      Offset(weightPillRect.left + 4, 118),
      Paint()
        ..color = V5.yellow.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(weightPillRect, const Radius.circular(9)),
      Paint()..color = V5.yellow,
    );
    _text(canvas, tp, '$weight kg',
        Offset(weightPillRect.center.dx, weightPillRect.top + 5),
        V5.yellowInk, 9,
        center: true);

    // ── Age callout (right side, top) ──────────────────────────────
    const agePillRect = Rect.fromLTWH(216, 50, 60, 18);
    canvas.drawLine(
      const Offset(190, 60),
      Offset(agePillRect.left + 4, 60),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(agePillRect, const Radius.circular(9)),
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );
    _text(canvas, tp, '$age tuổi',
        Offset(agePillRect.center.dx, agePillRect.top + 5),
        V5.invInk, 9,
        center: true);

    canvas.restore();
  }

  /// Draws a simple yellow-stroked body silhouette in painter coordinates
  /// (~x=140..200, y=30..170).
  void _drawBody(Canvas canvas) {
    final fill = Paint()
      ..color = V5.yellow.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = V5.yellow.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Head
    const headCenter = Offset(170, 50);
    const headR = 10.5;
    canvas.drawCircle(headCenter, headR, fill);
    canvas.drawCircle(headCenter, headR, stroke);

    // Torso — slightly trapezoid silhouette
    final torso = Path()
      ..moveTo(155, 65)
      ..lineTo(185, 65)
      ..lineTo(190, 78)
      ..lineTo(192, 132)
      ..quadraticBezierTo(192, 142, 186, 145)
      ..lineTo(154, 145)
      ..quadraticBezierTo(148, 142, 148, 132)
      ..lineTo(150, 78)
      ..close();
    canvas.drawPath(torso, fill);
    canvas.drawPath(torso, stroke);

    // Legs — two simple rounded rects
    final legL = Path()
      ..moveTo(155, 145)
      ..lineTo(168, 145)
      ..lineTo(167, 175)
      ..lineTo(157, 175)
      ..close();
    canvas.drawPath(legL, fill);
    canvas.drawPath(legL, stroke);
    final legR = Path()
      ..moveTo(172, 145)
      ..lineTo(185, 145)
      ..lineTo(183, 175)
      ..lineTo(173, 175)
      ..close();
    canvas.drawPath(legR, fill);
    canvas.drawPath(legR, stroke);

    // Arms — drop down at the sides (gestural)
    final armL = Path()
      ..moveTo(150, 80)
      ..quadraticBezierTo(140, 100, 144, 132);
    final armR = Path()
      ..moveTo(190, 80)
      ..quadraticBezierTo(200, 100, 196, 132);
    canvas.drawPath(armL, stroke);
    canvas.drawPath(armR, stroke);
  }

  void _text(Canvas canvas, TextPainter tp, String text, Offset offset, Color color, double size,
      {bool center = false, bool alignRight = false}) {
    tp.text = TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800),
    );
    tp.layout();
    final dx = center
        ? offset.dx - tp.width / 2
        : alignRight
            ? offset.dx - tp.width
            : offset.dx;
    tp.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _BodyInfoHeroPainter oldDelegate) =>
      oldDelegate.height != height ||
      oldDelegate.weight != weight ||
      oldDelegate.age != age ||
      oldDelegate.gender != gender;
}
