import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'v5_theme.dart';

class V5FadeIn extends StatefulWidget {
  const V5FadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.slideY = 0,
    this.curve = Curves.easeOut,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideY;
  final Curve curve;

  @override
  State<V5FadeIn> createState() => _V5FadeInState();
}

class _V5FadeInState extends State<V5FadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _dy;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _dy = Tween<double>(begin: widget.slideY, end: 0).animate(curved);
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(offset: Offset(0, _dy.value), child: child),
      ),
    );
  }
}

class V5Screen extends StatelessWidget {
  const V5Screen({
    super.key,
    required this.index,
    required this.children,
    this.onBack,
    this.inverted = false,
    this.background = V5.bg,
    this.showChrome = true,
  });

  final int index;
  final List<Widget> children;
  final VoidCallback? onBack;
  final bool inverted;
  final Color background;
  final bool showChrome;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ...children,
          const V5StatusBar(inverted: false),
          if (showChrome)
            V5TopChrome(
              index: index,
              total: 16,
              onBack: onBack,
              inverted: inverted,
            ),
        ],
      ),
    );
  }
}

class V5StatusBar extends StatelessWidget {
  const V5StatusBar({super.key, this.inverted = false});

  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final fg = inverted ? V5.invInk : V5.ink;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 54,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('9:41',
                  style: V5.text(context,
                      size: 14, weight: FontWeight.w600, color: fg)),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      width: 3,
                      height: 4 + i * 2.3,
                      margin: const EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(
                        color: fg,
                        borderRadius: BorderRadius.circular(0.5),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    width: 23,
                    height: 12,
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      border: Border.all(color: fg.withValues(alpha: 0.45)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 18,
                        decoration: BoxDecoration(
                          color: fg,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class V5TopChrome extends StatelessWidget {
  const V5TopChrome({
    super.key,
    required this.index,
    required this.total,
    this.onBack,
    this.inverted = false,
  });

  final int index;
  final int total;
  final VoidCallback? onBack;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final fg = inverted ? V5.invInk : V5.ink;
    final fgSoft = inverted ? V5.invInkSoft : V5.inkSoft;
    final border = inverted ? Colors.white.withValues(alpha: 0.18) : V5.borderHi;
    // Position chrome 12px below the OS status bar / notch, regardless of
    // device. iPhone 14 Pro: ~59 + 12 = 71. Android Pixel: ~30 + 12 = 42.
    // Prototype's hardcoded `top: 60` looked good on iPhone but left an
    // empty band on Android.
    final topInset = MediaQuery.viewPaddingOf(context).top + 12;
    return Positioned(
      top: topInset,
      left: 24,
      right: 24,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: border),
                  ),
                  child: Icon(Icons.chevron_left_rounded, color: fg, size: 23),
                ),
              ),
              Text(
                '${index.toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
                style: V5.text(
                  context,
                  size: 11,
                  weight: FontWeight.w600,
                  color: fgSoft,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          V5PhaseProgress(index: index, inverted: inverted),
        ],
      ),
    );
  }
}

class V5PhaseProgress extends StatelessWidget {
  const V5PhaseProgress({
    super.key,
    required this.index,
    this.inverted = false,
  });

  final int index;
  final bool inverted;

  static const _phases = [
    ('Khởi đầu', 1, 6),
    ('Đánh giá', 7, 10),
    ('Lộ trình', 11, 16),
  ];

  @override
  Widget build(BuildContext context) {
    final fg = inverted ? V5.invInk : V5.ink;
    final fgFaint = inverted ? V5.invInkFaint : V5.inkFaint;
    final track =
        inverted ? Colors.white.withValues(alpha: 0.10) : V5.border;
    final current = _phases.indexWhere((p) => index >= p.$2 && index <= p.$3);
    return Row(
      children: _phases.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        final done = i < current;
        final active = i == current;
        final pct = done
            ? 1.0
            : active
                ? ((index - p.$2 + 1) / (p.$3 - p.$2 + 1)).clamp(0.0, 1.0)
                : 0.0;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == _phases.length - 1 ? 0 : 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: track,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p.$1.toUpperCase(),
                  style: V5.text(
                    context,
                    size: 9,
                    weight: FontWeight.w700,
                    color: active ? fg : fgFaint,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class V5PillCTA extends StatefulWidget {
  const V5PillCTA({
    super.key,
    required this.label,
    required this.onTap,
    this.disabledLabel = 'Chọn để tiếp',
    this.enabled = true,
    this.yellow = false,
    this.bottom = 32,
  });

  final String label;
  final String disabledLabel;
  final VoidCallback? onTap;
  final bool enabled;
  final bool yellow;
  final double bottom;

  @override
  State<V5PillCTA> createState() => _V5PillCTAState();
}

class _V5PillCTAState extends State<V5PillCTA>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: widget.bottom,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final glow = 0.20 + _controller.value * 0.08;
          final enabled = widget.enabled && widget.onTap != null;
          final bg = !enabled
              ? Colors.transparent
              : widget.yellow
                  ? V5.yellow
                  : V5.ink;
          final fg = !enabled
              ? V5.inkFaint
              : widget.yellow
                  ? V5.yellowInk
                  : V5.invInk;
          // Subtle press feedback — JSX has `transform: scale(0.99)` on
          // active state. Tween via AnimatedScale so the gesture feels
          // physical rather than instantaneous.
          return GestureDetector(
            onTap: enabled ? widget.onTap : null,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              scale: _pressed ? 0.985 : 1.0,
              child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: widget.yellow ? 64 : 60,
              padding: EdgeInsets.fromLTRB(28, 0, enabled ? 8 : 28, 0),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(32),
                border: enabled ? null : Border.all(color: V5.borderHi, width: 1.5),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: widget.yellow
                              ? V5.yellow.withValues(alpha: 0.35)
                              : V5.ink.withValues(alpha: glow),
                          blurRadius: widget.yellow ? 32 : 28 + 8 * _controller.value,
                          offset: Offset(0, widget.yellow ? 12 : 10),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      enabled ? widget.label : widget.disabledLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V5.text(
                        context,
                        size: 15,
                        weight: widget.yellow ? FontWeight.w800 : FontWeight.w700,
                        color: fg,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: enabled ? (widget.yellow ? 48 : 44) : 24,
                    height: enabled ? (widget.yellow ? 48 : 44) : 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: enabled
                          ? widget.yellow
                              ? V5.ink
                              : V5.yellow
                          : Colors.transparent,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: enabled ? 19 : 14,
                      color: enabled
                          ? widget.yellow
                              ? V5.yellow
                              : V5.yellowInk
                          : V5.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}

class V5HeroCard extends StatelessWidget {
  const V5HeroCard({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary caches the rasterized card so first-paint shader
    // compilation jank doesn't show through. Combined with Clip.hardEdge
    // (no saveLayer for AA) this eliminates the orange flash on S02/S05
    // hero cards on Android emulator.
    return RepaintBoundary(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: V5.heroGradient,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: V5.heroBorder),
          boxShadow: [
            V5.cardShadow(),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.04),
              blurRadius: 0,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -70,
              left: -70,
              child: _GlowBlob(
                width: 280,
                height: 230,
                color: V5.yellow.withValues(alpha: 0.16),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // RadialGradient instead of ImageFiltered+blur. End color is fully
    // transparent BLACK (`Colors.transparent`) — interpolating to a low-alpha
    // version of the SAME color leaves bright RGB with low alpha at the
    // edge, which can show as a flash on first frame in unpremultiplied
    // pipelines (Android emulator software renderer).
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

/// Radial-gradient glow for full-bleed dark screens (S01 Welcome, S08
/// Analyzing, S16 Closer, S08 Phase1 mock data card). Replaces ImageFiltered
/// blur to avoid the first-frame flash.
class V5AmbientGlow extends StatelessWidget {
  const V5AmbientGlow({
    super.key,
    required this.size,
    required this.opacity,
    this.color = V5.yellow,
  });

  final Size size;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

class V5Eyebrow extends StatelessWidget {
  const V5Eyebrow({
    super.key,
    required this.label,
    this.dark = false,
    this.sparkle = false,
  });

  final String label;
  final bool dark;
  final bool sparkle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.08)
            : V5.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: sparkle ? Border.all(color: V5.yellow.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sparkle)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: V5Sparkle(size: 10),
            )
          else
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(
                color: V5.yellow,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            label.toUpperCase(),
            style: V5.text(
              context,
              size: 10,
              weight: FontWeight.w700,
              color: dark ? V5.invInk : V5.ink,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class V5Sparkle extends StatelessWidget {
  const V5Sparkle({super.key, this.size = 12, this.color = V5.yellow});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SparklePainter(color)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.58, h * 0.42)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.58, h * 0.58)
      ..lineTo(w * 0.5, h)
      ..lineTo(w * 0.42, h * 0.58)
      ..lineTo(0, h * 0.5)
      ..lineTo(w * 0.42, h * 0.42)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.color != color;
}

class V5PulseDot extends StatefulWidget {
  const V5PulseDot({super.key});

  @override
  State<V5PulseDot> createState() => _V5PulseDotState();
}

class _V5PulseDotState extends State<V5PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Transform.scale(
        scale: 1 + _controller.value * 0.2,
        child: Opacity(
          opacity: 1 - _controller.value * 0.4,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class V5HeroFigure extends StatelessWidget {
  const V5HeroFigure({super.key, required this.pose, this.opacity = 1});

  final String pose;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        painter: _HeroFigurePainter(pose: pose),
      ),
    );
  }
}

class _HeroFigurePainter extends CustomPainter {
  _HeroFigurePainter({required this.pose});

  final String pose;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = math.min(size.width / 320, size.height / 380);
    canvas.translate((size.width - 320 * scale) / 2, (size.height - 380 * scale) / 2);
    canvas.scale(scale);

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3A2E20), Color(0xFF1A1209), Color(0xFF0A0603)],
        stops: [0, 0.6, 1],
      ).createShader(const Rect.fromLTWH(60, 20, 220, 360));
    final rim = Paint()..color = V5.yellow.withValues(alpha: 0.72);
    final line = Paint()
      ..color = V5.yellow.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Soft yellow glow drawn as a radial gradient instead of MaskFilter.blur.
    // MaskFilter requires a separate blur pass that on Android emulators
    // can show the unblurred solid disk for one frame (the orange/red flash).
    final glowRect = const Rect.fromLTWH(-70, -40, 300, 360);
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            V5.yellow.withValues(alpha: 0.13),
            Colors.transparent,
          ],
        ).createShader(glowRect),
    );

    switch (pose) {
      case 'reach':
        _reach(canvas, bg, rim, line);
        break;
      case 'lunge':
        _lunge(canvas, bg, rim, line);
        break;
      case 'tree':
        _tree(canvas, bg, rim, line);
        break;
      case 'squat':
      default:
        _squat(canvas, bg, rim, line);
    }
    canvas.restore();
  }

  void _head(Canvas canvas, Paint p, Offset c, double rx, double ry) {
    canvas.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2), p);
  }

  Path _path(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  void _squat(Canvas c, Paint body, Paint rim, Paint line) {
    _head(c, rim, const Offset(158, 84), 22, 25);
    c.drawPath(_path([const Offset(137, 113), const Offset(144, 116), const Offset(138, 168), const Offset(142, 215), const Offset(138, 215), const Offset(132, 175)]), rim);
    _head(c, body, const Offset(162, 84), 22, 25);
    c.drawPath(_path([const Offset(142, 110), const Offset(184, 110), const Offset(186, 130), const Offset(140, 130)]), body);
    c.drawPath(Path()
      ..moveTo(138, 130)
      ..quadraticBezierTo(124, 175, 134, 220)
      ..quadraticBezierTo(128, 250, 145, 268)
      ..lineTo(195, 268)
      ..quadraticBezierTo(218, 250, 214, 220)
      ..quadraticBezierTo(224, 175, 210, 130)
      ..close(), body);
    c.drawPath(_path([const Offset(138, 145), const Offset(80, 200), const Offset(92, 215), const Offset(148, 175)]), body);
    c.drawPath(_path([const Offset(210, 145), const Offset(268, 200), const Offset(256, 215), const Offset(200, 175)]), body);
    c.drawPath(_path([const Offset(145, 268), const Offset(144, 350), const Offset(172, 354), const Offset(175, 268)]), body);
    c.drawPath(_path([const Offset(195, 268), const Offset(196, 350), const Offset(168, 354), const Offset(165, 268)]), body);
    c.drawPath(Path()
      ..moveTo(184, 110)
      ..lineTo(210, 130)
      ..quadraticBezierTo(224, 175, 214, 220)
      ..quadraticBezierTo(218, 250, 195, 268)
      ..quadraticBezierTo(208, 305, 196, 350), line);
  }

  void _reach(Canvas c, Paint body, Paint rim, Paint line) {
    _head(c, rim, const Offset(158, 68), 20, 23);
    _head(c, body, const Offset(160, 68), 20, 23);
    c.drawPath(_path([const Offset(144, 92), const Offset(178, 92), const Offset(180, 110), const Offset(142, 110)]), body);
    c.drawPath(Path()
      ..moveTo(138, 110)
      ..quadraticBezierTo(128, 180, 138, 250)
      ..lineTo(184, 250)
      ..quadraticBezierTo(194, 180, 184, 110)
      ..close(), body);
    c.drawPath(_path([const Offset(142, 116), const Offset(90, 18), const Offset(105, 14), const Offset(152, 110)]), body);
    c.drawPath(_path([const Offset(180, 116), const Offset(232, 18), const Offset(217, 14), const Offset(170, 110)]), body);
    c.drawPath(_path([const Offset(138, 250), const Offset(138, 380), const Offset(162, 380), const Offset(162, 250)]), body);
    c.drawPath(_path([const Offset(158, 250), const Offset(158, 380), const Offset(184, 380), const Offset(184, 250)]), body);
    c.drawPath(Path()
      ..moveTo(178, 92)
      ..lineTo(184, 110)
      ..quadraticBezierTo(194, 180, 184, 250)
      ..quadraticBezierTo(192, 320, 184, 380), line);
  }

  void _lunge(Canvas c, Paint body, Paint rim, Paint line) {
    _head(c, rim, const Offset(170, 80), 21, 24);
    _head(c, body, const Offset(172, 80), 21, 24);
    c.drawPath(_path([const Offset(156, 105), const Offset(188, 105), const Offset(190, 122), const Offset(154, 122)]), body);
    c.drawPath(Path()
      ..moveTo(148, 122)
      ..quadraticBezierTo(138, 175, 148, 240)
      ..lineTo(198, 240)
      ..quadraticBezierTo(208, 175, 198, 122)
      ..close(), body);
    c.drawPath(_path([const Offset(152, 130), const Offset(102, 215), const Offset(116, 228), const Offset(158, 152)]), body);
    c.drawPath(_path([const Offset(196, 130), const Offset(232, 180), const Offset(222, 192), const Offset(188, 152)]), body);
    c.drawPath(_path([const Offset(152, 240), const Offset(200, 320), const Offset(222, 332), const Offset(178, 252)]), body);
    c.drawPath(_path([const Offset(198, 240), const Offset(142, 365), const Offset(118, 372), const Offset(168, 252)]), body);
    c.drawPath(Path()
      ..moveTo(188, 105)
      ..lineTo(190, 122)
      ..quadraticBezierTo(208, 175, 198, 240)
      ..quadraticBezierTo(200, 290, 222, 332), line);
  }

  void _tree(Canvas c, Paint body, Paint rim, Paint line) {
    _head(c, rim, const Offset(158, 62), 18, 21);
    _head(c, body, const Offset(160, 62), 18, 21);
    c.drawPath(_path([const Offset(146, 84), const Offset(174, 84), const Offset(176, 100), const Offset(144, 100)]), body);
    c.drawPath(Path()
      ..moveTo(140, 100)
      ..quadraticBezierTo(130, 170, 140, 250)
      ..lineTo(180, 250)
      ..quadraticBezierTo(190, 170, 180, 100)
      ..close(), body);
    c.drawPath(_path([const Offset(142, 250), const Offset(142, 380), const Offset(162, 380), const Offset(162, 250)]), body);
    c.drawPath(Path()
      ..moveTo(178, 254)
      ..quadraticBezierTo(215, 268, 232, 252)
      ..lineTo(232, 268)
      ..quadraticBezierTo(210, 285, 178, 272)
      ..close(), body);
    c.drawPath(Path()
      ..moveTo(174, 84)
      ..lineTo(176, 100)
      ..quadraticBezierTo(190, 170, 180, 250)
      ..quadraticBezierTo(192, 320, 184, 380), line);
  }

  @override
  bool shouldRepaint(covariant _HeroFigurePainter oldDelegate) =>
      oldDelegate.pose != pose;
}

class V5CheckCircle extends StatelessWidget {
  const V5CheckCircle({
    super.key,
    required this.selected,
    this.size = 20,
  });

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? V5.yellow : Colors.transparent,
        border: selected ? null : Border.all(color: V5.borderHi, width: 1.5),
      ),
      child: selected
          ? Icon(Icons.check_rounded, color: V5.yellowInk, size: size * 0.68)
          : null,
    );
  }
}

class V5Glass extends StatelessWidget {
  const V5Glass({
    super.key,
    required this.child,
    this.borderRadius = 100,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: child,
        ),
      ),
    );
  }
}

class V5BodyDiagram extends StatelessWidget {
  const V5BodyDiagram({
    super.key,
    required this.painAreas,
    required this.noPain,
  });

  final List<String> painAreas;
  final bool noPain;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BodyDiagramPainter(painAreas: painAreas, noPain: noPain),
    );
  }
}

class _BodyDiagramPainter extends CustomPainter {
  const _BodyDiagramPainter({required this.painAreas, required this.noPain});

  final List<String> painAreas;
  final bool noPain;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = math.min(size.width / 200, size.height / 260);
    canvas.translate((size.width - 200 * scale) / 2, (size.height - 260 * scale) / 2);
    canvas.scale(scale);
    final body = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round;
    // Soft glow as radial gradient (no MaskFilter pass — avoids first-frame
    // unblurred-disk flash on Android emulators).
    const glowRect = Rect.fromLTWH(10, 0, 180, 240);
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            V5.yellow.withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ).createShader(glowRect),
    );
    canvas.drawCircle(const Offset(100, 32), 17, body);
    canvas.drawCircle(const Offset(100, 32), 17, stroke);
    void draw(Path p) {
      canvas.drawPath(p, body);
      canvas.drawPath(p, stroke);
    }

    draw(Path()
      ..moveTo(72, 60)
      ..quadraticBezierTo(64, 80, 68, 130)
      ..lineTo(132, 130)
      ..quadraticBezierTo(136, 80, 128, 60)
      ..close());
    draw(Path()
      ..moveTo(72, 66)
      ..lineTo(50, 90)
      ..lineTo(42, 142)
      ..lineTo(52, 145)
      ..lineTo(60, 95)
      ..lineTo(72, 80)
      ..close());
    draw(Path()
      ..moveTo(128, 66)
      ..lineTo(150, 90)
      ..lineTo(158, 142)
      ..lineTo(148, 145)
      ..lineTo(140, 95)
      ..lineTo(128, 80)
      ..close());
    draw(Path()
      ..moveTo(68, 130)
      ..quadraticBezierTo(68, 152, 74, 168)
      ..lineTo(126, 168)
      ..quadraticBezierTo(132, 152, 132, 130)
      ..close());
    draw(_poly([const Offset(78, 168), const Offset(75, 215), const Offset(78, 250), const Offset(92, 250), const Offset(95, 215), const Offset(92, 168)]));
    draw(_poly([const Offset(108, 168), const Offset(105, 215), const Offset(108, 250), const Offset(122, 250), const Offset(125, 215), const Offset(122, 168)]));

    marker(canvas, const Offset(100, 56), 'neck');
    marker(canvas, const Offset(100, 100), 'back');
    marker(canvas, const Offset(100, 148), 'hip');
    marker(canvas, const Offset(48, 146), 'wrist', 4);
    marker(canvas, const Offset(152, 146), 'wrist', 4);
    marker(canvas, const Offset(84, 200), 'knee', 4);
    marker(canvas, const Offset(116, 200), 'knee', 4);
    canvas.restore();
  }

  Path _poly(List<Offset> points) {
    final p = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      p.lineTo(point.dx, point.dy);
    }
    return p..close();
  }

  void marker(Canvas canvas, Offset center, String area, [double r = 5]) {
    final selected = !noPain && painAreas.contains(area);
    if (selected) {
      canvas.drawCircle(center, r * 2.4, Paint()..color = V5.yellow.withValues(alpha: 0.28));
      canvas.drawCircle(center, r * 1.6, Paint()..color = V5.yellow.withValues(alpha: 0.18));
    }
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = selected ? V5.yellow : Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = selected ? V5.yellow : Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _BodyDiagramPainter oldDelegate) =>
      oldDelegate.painAreas != painAreas || oldDelegate.noPain != noPain;
}

/// Canonical Google "G" mark. Four colored arcs forming the outer ring +
/// horizontal blue tab extending inward from the right edge.
///
/// Color layout (matches the official Google branding):
///   Red    : top of the ring
///   Yellow : left side
///   Green  : bottom
///   Blue   : right side + horizontal tab
class V5GoogleMark extends StatelessWidget {
  const V5GoogleMark({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;
    final cy = w / 2;
    final stroke = w * 0.18;
    final r = (w - stroke) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Angles below are in radians, with 0 = east and increasing CW.
    // Layout going clockwise:
    //   Red:    -160° → -20°  (top half, slightly weighted toward right)
    //   Blue:    -20° → +60°  (right going down to bottom-right)
    //   Green:  +60° → +160° (bottom)
    //   Yellow: +160° → +200° (left side, short — wraps under top arc start)
    //
    // Actual canonical Google G has angle weighting: red biggest (~140°),
    // green ~100°, yellow ~60°, blue ~60° + the tab. We approximate.
    canvas.drawArc(rect, _rad(-160), _rad(140), false, arc(_red));
    canvas.drawArc(rect, _rad(-20), _rad(80), false, arc(_blue));
    canvas.drawArc(rect, _rad(60), _rad(100), false, arc(_green));
    canvas.drawArc(rect, _rad(160), _rad(40), false, arc(_yellow));

    // Horizontal blue tab — extends LEFTWARD from the right outer edge to
    // the center, sitting on the horizontal axis. The tab represents the
    // G's "horizontal stroke". Drawn as a thick line capped on the inner
    // (left) end so it ends cleanly at center.
    final tabPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    // Tab starts inside the outer ring (so it appears to attach to the right
    // arc) and extends to ~50% width. The right end overlaps the blue arc;
    // the left end is the open inner edge of the tab.
    canvas.drawLine(
      Offset(cx, cy),
      Offset(rect.right, cy),
      tabPaint,
    );
  }

  double _rad(double deg) => deg * math.pi / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Solid Facebook brand mark — white "f" on the blue button background.
/// Drawn manually so it sits at the correct optical position regardless of
/// font metrics (Material's Icons.facebook ships a different-style mark).
class V5FacebookMark extends StatelessWidget {
  const V5FacebookMark({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _FacebookPainter()),
    );
  }
}

class _FacebookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Vertical stem of the f
    final paint = Paint()..color = Colors.white;
    final stem = Rect.fromLTRB(w * 0.50, h * 0.18, w * 0.62, h * 0.96);
    canvas.drawRRect(
      RRect.fromRectAndRadius(stem, Radius.circular(w * 0.04)),
      paint,
    );
    // The hook at the top of the f (curves left and down)
    final hook = Path()
      ..moveTo(w * 0.62, h * 0.18)
      ..quadraticBezierTo(w * 0.62, h * 0.04, w * 0.78, h * 0.04)
      ..lineTo(w * 0.84, h * 0.04)
      ..lineTo(w * 0.84, h * 0.20)
      ..lineTo(w * 0.78, h * 0.20)
      ..quadraticBezierTo(w * 0.74, h * 0.20, w * 0.74, h * 0.28)
      ..lineTo(w * 0.74, h * 0.40)
      ..lineTo(w * 0.50, h * 0.40)
      ..close();
    canvas.drawPath(hook, paint);
    // Horizontal crossbar
    final bar = Rect.fromLTRB(w * 0.36, h * 0.40, w * 0.84, h * 0.52);
    canvas.drawRect(bar, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Apple logo — Material's `Icons.apple` ships the canonical silhouette
/// (with bite + leaf). We just upscale it slightly to optically match the
/// Google G and Facebook f next to it.
class V5AppleMark extends StatelessWidget {
  const V5AppleMark({super.key, this.size = 18, this.color = Colors.white});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.apple, size: size + 4, color: color);
  }
}
