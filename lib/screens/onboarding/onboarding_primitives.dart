import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vika/widgets/vf_primitives.dart';

import 'vf_theme.dart';

enum VFButtonTone { jade, white }

class VFOnboardingButton extends StatelessWidget {
  const VFOnboardingButton({
    super.key,
    required this.label,
    required this.onTap,
    this.tone = VFButtonTone.jade,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 24),
  });

  final String label;
  final VoidCallback? onTap;
  final VFButtonTone tone;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    final enabled = onTap != null;
    final background = switch (tone) {
      VFButtonTone.white => Colors.white,
      VFButtonTone.jade => VF.accent,
    };
    final foreground = switch (tone) {
      VFButtonTone.white => VF.jadeDark,
      VFButtonTone.jade => Colors.white,
    };

    return Padding(
      padding: padding.add(
        EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 58 * s,
          decoration: BoxDecoration(
            color: enabled ? background : background.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(18 * s),
            border: Border.all(
              color: tone == VFButtonTone.white
                  ? Colors.white.withValues(alpha: enabled ? 0.10 : 0.04)
                  : VF.accent.withValues(alpha: enabled ? 0.14 : 0.06),
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: tone == VFButtonTone.white
                          ? Colors.black.withValues(alpha: 0.08)
                          : VF.accent.withValues(alpha: 0.22),
                      blurRadius: tone == VFButtonTone.white ? 14 : 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: VF.textStyle(
              context,
              size: 15.5,
              weight: FontWeight.w800,
              color: enabled ? foreground : foreground.withValues(alpha: 0.45),
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class VFOnboardingNavBar extends StatelessWidget {
  const VFOnboardingNavBar({
    super.key,
    required this.current,
    required this.total,
    this.onBack,
    this.dark = false,
  });

  final int current;
  final int total;
  final VoidCallback? onBack;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    final top = MediaQuery.of(context).padding.top + 12 * s;
    final barBg = dark
        ? Colors.white.withValues(alpha: 0.10)
        : VF.textMuted.withValues(alpha: 0.15);
    final fill = dark ? VF.jadeGlow.withValues(alpha: 0.60) : VF.accent;
    final textColor =
        dark ? Colors.white.withValues(alpha: 0.30) : VF.textMuted;

    return Padding(
      padding: EdgeInsets.fromLTRB(24 * s, top, 24 * s, 0),
      child: Row(
        children: [
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 36 * s,
                height: 36 * s,
                decoration: BoxDecoration(
                  color:
                      dark ? Colors.white.withValues(alpha: 0.08) : VF.surface,
                  borderRadius: BorderRadius.circular(12 * s),
                  border: Border.all(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14 * s,
                  color: dark
                      ? Colors.white.withValues(alpha: 0.55)
                      : VF.textMuted,
                ),
              ),
            ),
            SizedBox(width: 10 * s),
          ],
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 3 * s,
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : current / total,
                  backgroundColor: barBg,
                  valueColor: AlwaysStoppedAnimation<Color>(fill),
                ),
              ),
            ),
          ),
          SizedBox(width: 10 * s),
          Text(
            '$current/$total',
            style: VF.textStyle(
              context,
              size: 11,
              weight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class VFDarkCurveBackdrop extends StatelessWidget {
  const VFDarkCurveBackdrop({
    super.key,
    required this.height,
    this.radius = 40,
    this.child,
  });

  final double height;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: height * s,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(radius * s),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      VF.surfaceDark,
                      VF.jadeDark,
                      Color(0xFF0A2E22),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 36 * s,
                right: -48 * s,
                child: Container(
                  width: 180 * s,
                  height: 180 * s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: VF.jadeGlow.withValues(alpha: 0.05),
                  ),
                ),
              ),
              const VFGrainOverlay(opacity: 0.035),
              if (child != null) child!,
            ],
          ),
        ),
      ),
    );
  }
}

class VFDecorativeRing extends StatelessWidget {
  const VFDecorativeRing({
    super.key,
    this.size = 120,
    this.opacity = 0.05,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    final scaledSize = size * s;
    return SizedBox(
      width: scaledSize,
      height: scaledSize,
      child: CustomPaint(
        painter: _VFDecorativeRingPainter(opacity: opacity),
      ),
    );
  }
}

class _VFDecorativeRingPainter extends CustomPainter {
  const _VFDecorativeRingPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Paint()
      ..color = VF.jadeGlow.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final inner = Paint()
      ..color = VF.jadeGlow.withValues(alpha: opacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final outerRect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    final innerRect = Rect.fromLTWH(28, 28, size.width - 56, size.height - 56);
    canvas.drawOval(outerRect, outer);

    const gap = math.pi / 40;
    for (double angle = 0; angle < math.pi * 2; angle += gap * 2) {
      canvas.drawArc(innerRect, angle, gap, false, inner);
    }
  }

  @override
  bool shouldRepaint(covariant _VFDecorativeRingPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}

class VFLeftAccentOptionCard extends StatelessWidget {
  const VFLeftAccentOptionCard({
    super.key,
    required this.selected,
    required this.accentColor,
    required this.child,
    this.onTap,
  });

  final bool selected;
  final Color accentColor;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20 * s),
          color: VF.surface,
          border: Border.all(
            color: selected
                ? accentColor.withValues(alpha: 0.15)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? accentColor.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: selected ? 18 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4 * s,
                color:
                    selected ? accentColor : VF.bgDeep.withValues(alpha: 0.5),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class VFBottomAccentTile extends StatelessWidget {
  const VFBottomAccentTile({
    super.key,
    required this.selected,
    required this.accentColor,
    required this.child,
    this.onTap,
  });

  final bool selected;
  final Color accentColor;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22 * s),
          color: VF.surface,
          border: Border.all(
            color: selected
                ? accentColor.withValues(alpha: 0.15)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? accentColor.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: selected ? 18 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(child: child),
            Container(
              height: 4 * s,
              color: selected ? accentColor : VF.bgDeep.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class VFProgressRing extends StatelessWidget {
  const VFProgressRing({
    super.key,
    required this.progress,
    required this.size,
    required this.strokeWidth,
    required this.color,
    required this.backgroundColor,
    this.glowWidth = 0,
    this.center,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final double glowWidth;
  final Color color;
  final Color backgroundColor;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _VFProgressRingPainter(
              progress: progress,
              strokeWidth: strokeWidth,
              glowWidth: glowWidth,
              color: color,
              backgroundColor: backgroundColor,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _VFProgressRingPainter extends CustomPainter {
  const _VFProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.glowWidth,
    required this.color,
    required this.backgroundColor,
  });

  final double progress;
  final double strokeWidth;
  final double glowWidth;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (glowWidth > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        progress * math.pi * 2,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = glowWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * math.pi * 2,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _VFProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.glowWidth != glowWidth ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class VFRulerPicker extends StatelessWidget {
  const VFRulerPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.step = 1,
    this.color = VF.accent,
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final ValueChanged<int> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final values = <int>[
      for (int current = min; current <= max; current += step) current,
    ];
    final selectedIndex =
        ((value - min) / step).round().clamp(0, values.length - 1);
    final visibleCount = math.min(9, values.length);
    final half = visibleCount ~/ 2;
    final maxStart = math.max(0, values.length - visibleCount);
    final start = math.max(0, math.min(maxStart, selectedIndex - half));
    final visibleValues = values.sublist(start, start + visibleCount);
    final localCenter = visibleValues.indexOf(values[selectedIndex]);

    final s = VF.scale(context);
    return Column(
      children: [
        Row(
          children: [
            _VFStepperButton(
              icon: CupertinoIcons.minus,
              onTap: value > min ? () => onChanged(value - step) : null,
            ),
            SizedBox(width: 10 * s),
            Expanded(
              child: SizedBox(
                height: 62 * s,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      top: 2 * s,
                      bottom: 8 * s,
                      child: Container(
                        width: 3 * s,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(visibleValues.length, (index) {
                        final item = visibleValues[index];
                        final distance = (index - localCenter).abs();
                        final selected = item == value;
                        final major = item % 5 == 0;
                        final tickHeight = (selected
                                ? 32.0
                                : major
                                    ? math.max(18, 26 - distance * 3).toDouble()
                                    : math
                                        .max(12, 18 - distance * 2)
                                        .toDouble()) *
                            s;
                        final opacity =
                            selected ? 1.0 : math.max(0.22, 1 - distance * 0.2);

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => onChanged(item),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '$item',
                                  style: VF.textStyle(
                                    context,
                                    size: selected ? 12 : 9,
                                    weight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: selected
                                        ? color
                                        : VF.textMuted
                                            .withValues(alpha: opacity),
                                  ),
                                ),
                                SizedBox(height: 5 * s),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: (selected
                                          ? 3
                                          : major
                                              ? 2
                                              : 1.5) *
                                      s,
                                  height: tickHeight,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? color
                                        : VF.textMuted.withValues(
                                            alpha: opacity * 0.35,
                                          ),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 10 * s),
            _VFStepperButton(
              icon: CupertinoIcons.plus,
              onTap: value < max ? () => onChanged(value + step) : null,
            ),
          ],
        ),
        SizedBox(height: 8 * s),
        Text(
          unit,
          style: VF.textStyle(
            context,
            size: 10,
            weight: FontWeight.w700,
            color: VF.textMuted,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class VFScrollableRulerPicker extends StatefulWidget {
  const VFScrollableRulerPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.step = 1,
    this.color = VF.accent,
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final ValueChanged<int> onChanged;
  final Color color;

  @override
  State<VFScrollableRulerPicker> createState() =>
      _VFScrollableRulerPickerState();
}

class _VFScrollableRulerPickerState extends State<VFScrollableRulerPicker> {
  static const double _viewportFraction = 0.12;
  late final PageController _controller;

  List<int> get _values => <int>[
        for (int current = widget.min;
            current <= widget.max;
            current += widget.step)
          current,
      ];

  int get _selectedIndex =>
      ((widget.value - widget.min) / widget.step).round().clamp(
            0,
            _values.length - 1,
          );

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: _selectedIndex,
      viewportFraction: _viewportFraction,
    );
  }

  @override
  void didUpdateWidget(covariant VFScrollableRulerPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value &&
        oldWidget.min == widget.min &&
        oldWidget.max == widget.max &&
        oldWidget.step == widget.step) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final currentIndex =
          (_controller.page ?? _controller.initialPage.toDouble()).round();
      if (currentIndex == _selectedIndex) return;
      _controller.animateToPage(
        _selectedIndex,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateValue(int nextValue) {
    final clamped = nextValue.clamp(widget.min, widget.max);
    if (clamped != widget.value) {
      widget.onChanged(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Column(
      children: [
        Row(
          children: [
            _VFStepperButton(
              icon: CupertinoIcons.minus,
              onTap: widget.value > widget.min
                  ? () => _updateValue(widget.value - widget.step)
                  : null,
            ),
            SizedBox(width: 10 * s),
            Expanded(
              child: SizedBox(
                height: 72 * s,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: VF.bg.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(20 * s),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.04),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10 * s,
                      bottom: 12 * s,
                      child: IgnorePointer(
                        child: Container(
                          width: 2 * s,
                          decoration: BoxDecoration(
                            color: widget.color,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(
                                color: widget.color.withValues(alpha: 0.20),
                                blurRadius: 10 * s,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    PageView.builder(
                      controller: _controller,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _values.length,
                      onPageChanged: (index) => _updateValue(_values[index]),
                      itemBuilder: (context, index) {
                        final item = _values[index];
                        final distance = (index - _selectedIndex).abs();
                        final selected = item == widget.value;
                        final major = index % 5 == 0;
                        final tickHeight = (selected
                                ? 30.0
                                : major
                                    ? math
                                        .max(18, 25 - distance * 2.8)
                                        .toDouble()
                                    : math
                                        .max(12, 18 - distance * 2)
                                        .toDouble()) *
                            s;
                        final opacity = selected
                            ? 1.0
                            : math.max(0.22, 1 - distance * 0.20);

                        return GestureDetector(
                          onTap: () => _updateValue(item),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 160),
                                style: VF.textStyle(
                                  context,
                                  size: selected ? 12 : 9,
                                  weight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: selected
                                      ? widget.color
                                      : VF.textMuted.withValues(alpha: opacity),
                                ),
                                child: Text('$item'),
                              ),
                              SizedBox(height: 5 * s),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                curve: Curves.easeOutCubic,
                                width: (selected
                                        ? 3
                                        : major
                                            ? 2
                                            : 1.5) *
                                    s,
                                height: tickHeight,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? widget.color
                                      : VF.textMuted.withValues(
                                          alpha: opacity * 0.36,
                                        ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 10 * s),
            _VFStepperButton(
              icon: CupertinoIcons.plus,
              onTap: widget.value < widget.max
                  ? () => _updateValue(widget.value + widget.step)
                  : null,
            ),
          ],
        ),
        SizedBox(height: 8 * s),
        Text(
          '${widget.unit} \u2022 k\u00e9o sang tr\u00e1i/ph\u1ea3i \u0111\u1ec3 ch\u1ecdn',
          style: VF.textStyle(
            context,
            size: 10,
            weight: FontWeight.w700,
            color: VF.textMuted,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _VFStepperButton extends StatelessWidget {
  const _VFStepperButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34 * s,
        height: 34 * s,
        decoration: BoxDecoration(
          color: enabled ? VF.surface : VF.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12 * s),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 16 * s,
          color: enabled ? VF.textMuted : VF.textMuted.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class VFGoogleMark extends StatelessWidget {
  const VFGoogleMark({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _VFGoogleMarkPainter(),
      ),
    );
  }
}

class VFAppleMark extends StatelessWidget {
  const VFAppleMark({super.key, this.size = 18, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _VFAppleMarkPainter(color: color),
      ),
    );
  }
}

class _VFAppleMarkPainter extends CustomPainter {
  const _VFAppleMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final leftLobe = Path()
      ..addOval(
        Rect.fromLTWH(
          size.width * 0.18,
          size.height * 0.27,
          size.width * 0.32,
          size.height * 0.42,
        ),
      );
    final rightLobe = Path()
      ..addOval(
        Rect.fromLTWH(
          size.width * 0.40,
          size.height * 0.18,
          size.width * 0.32,
          size.height * 0.46,
        ),
      );
    final base = Path()
      ..addOval(
        Rect.fromLTWH(
          size.width * 0.26,
          size.height * 0.42,
          size.width * 0.36,
          size.height * 0.30,
        ),
      );
    final mergedTop = Path.combine(PathOperation.union, leftLobe, rightLobe);
    final appleBody = Path.combine(PathOperation.union, mergedTop, base);
    final bite = Path()
      ..addOval(
        Rect.fromLTWH(
          size.width * 0.62,
          size.height * 0.31,
          size.width * 0.16,
          size.height * 0.16,
        ),
      );
    final finalBody = Path.combine(PathOperation.difference, appleBody, bite);
    canvas.drawPath(finalBody, fill);

    canvas.save();
    canvas.translate(size.width * 0.55, size.height * 0.16);
    canvas.rotate(-math.pi / 5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.16,
        height: size.height * 0.10,
      ),
      fill,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VFAppleMarkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _VFGoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.18;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    void drawArc(Color color, double startDeg, double sweepDeg) {
      canvas.drawArc(
        rect,
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    drawArc(const Color(0xFFEA4335), -136, 88);
    drawArc(const Color(0xFFFBBC05), -48, 68);
    drawArc(const Color(0xFF34A853), 20, 100);
    drawArc(const Color(0xFF4285F4), 120, 146);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final y = size.height * 0.53;
    canvas.drawLine(
      Offset(size.width * 0.55, y),
      Offset(size.width * 0.92, y),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
