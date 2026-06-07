// IvoryRulerPicker — a horizontal snap-to-tick ruler with a yellow centre
// marker, the Premium Ivory cousin of the onboarding V5RulerPicker. Used by
// the body-stats editor so the Profile tab matches the onboarding feel without
// importing the self-contained V5 theme into the main app.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

class IvoryRulerPicker extends StatefulWidget {
  const IvoryRulerPicker({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  final int value;
  final String label;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  State<IvoryRulerPicker> createState() => _IvoryRulerPickerState();
}

class _IvoryRulerPickerState extends State<IvoryRulerPicker> {
  static const _tickWidth = 10.0;
  late final ScrollController _controller;
  int _lastHaptic = 0;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: (widget.value - widget.min) * _tickWidth,
    );
    _lastHaptic = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _valueForOffset(double offset) {
    return (widget.min + (offset / _tickWidth).round())
        .clamp(widget.min, widget.max);
  }

  void _reportCurrentValue() {
    if (!_controller.hasClients) return;
    final value = _valueForOffset(_controller.offset);
    if (value != widget.value) {
      if (value != _lastHaptic) {
        _lastHaptic = value;
        HapticFeedback.selectionClick();
      }
      widget.onChanged(value);
    }
  }

  void _snapToNearest() {
    if (!_controller.hasClients) return;
    final value = _valueForOffset(_controller.offset);
    final target = (value - widget.min) * _tickWidth;
    if ((_controller.offset - target).abs() < 0.5) return;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final totalTicks = widget.max - widget.min + 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
      decoration: BoxDecoration(
        color: c.bgRaised,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ĐANG CHỈNH ${widget.label.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: c.inkFaint,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${widget.value}',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -2.0,
                  height: 1.0,
                  color: c.ink,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  widget.unit,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sidePadding =
                    math.max(0.0, constraints.maxWidth / 2 - _tickWidth / 2);
                return Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollUpdateNotification ||
                            notification is OverscrollNotification) {
                          _reportCurrentValue();
                        } else if (notification is ScrollEndNotification) {
                          _reportCurrentValue();
                          _snapToNearest();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _controller,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: sidePadding),
                        itemCount: totalTicks,
                        itemBuilder: (context, index) {
                          final num = widget.min + index;
                          final major = num % 10 == 0;
                          final mid = num % 5 == 0 && !major;
                          final tickHeight = major
                              ? 32.0
                              : mid
                                  ? 22.0
                                  : 14.0;
                          return SizedBox(
                            width: _tickWidth,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.topCenter,
                              children: [
                                Container(
                                  width: major ? 2 : 1,
                                  height: tickHeight,
                                  color: major
                                      ? c.ink
                                      : mid
                                          ? c.inkSoft
                                          : c.inkFaint,
                                ),
                                if (major)
                                  Positioned(
                                    top: tickHeight + 4,
                                    child: Text(
                                      '$num',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'BeVietnamPro',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        height: 1,
                                        color: c.inkSoft,
                                        fontFeatures:
                                            VikaIvoryMain.tabularFigures,
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
                              painter: _TrianglePainter(color: c.yellow),
                            ),
                            Container(
                              width: 2,
                              height: 42,
                              decoration: BoxDecoration(
                                color: c.yellow,
                                boxShadow: [
                                  BoxShadow(
                                    color: c.yellow.withValues(alpha: 0.5),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}
