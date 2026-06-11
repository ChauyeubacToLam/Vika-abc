import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'v5_theme.dart';

// ═══════════════════════════════════════════════════════════════
// ANIMATION HELPERS
// ═══════════════════════════════════════════════════════════════

/// Subtle entrance: fade + slide. Premium feel comes from slow curves
/// (V5.curve = 0.16,1,0.3,1) and modest distances (8–14px).
class V5FadeIn extends StatefulWidget {
  const V5FadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 540),
    this.slideY = 0,
    this.curve = V5.curve,
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
      builder: (context, child) {
        final translated = Transform.translate(
          offset: Offset(0, _dy.value),
          child: child,
        );
        // Hero cards skip opacity to avoid the orange flash from rasterizing
        // a half-transparent gradient on first frame.
        if (widget.child is V5HeroCard) {
          return translated;
        }
        return Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: translated,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SCREEN SCAFFOLDING
// ═══════════════════════════════════════════════════════════════

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
          if (showChrome)
            V5TopChrome(
              index: index,
              total: 17,
              onBack: onBack,
              inverted: inverted,
            ),
        ],
      ),
    );
  }
}

/// Higher-level scaffold that bundles [V5Screen] + the standard
/// SafeArea/gutter/padding math + an optional floating [V5PillCTA].
///
/// Use this instead of hand-rolling `Positioned.fill → SafeArea → Padding`
/// with magic numbers for chrome-top and CTA-bottom in every screen.
class V5Page extends StatelessWidget {
  const V5Page({
    super.key,
    required this.index,
    required this.child,
    this.cta,
    this.onBack,
    this.inverted = false,
    this.background = V5.bg,
    this.showChrome = true,
    this.backgroundLayers = const <Widget>[],
    this.scroll = false,
    this.bottomPaddingOverride,
    this.topPaddingOverride,
  });

  final int index;
  final Widget child;
  final Widget? cta;
  final VoidCallback? onBack;
  final bool inverted;
  final Color background;
  final bool showChrome;

  /// Decorative layers painted BEHIND [child] but on top of [background].
  /// Use for ambient glows, textures, full-bleed images.
  final List<Widget> backgroundLayers;

  /// If true, wraps [child] in a [SingleChildScrollView]. Use only when
  /// content can legitimately exceed the viewport (e.g., dense forms).
  /// Default false keeps the editorial fixed-frame feel.
  final bool scroll;

  final double? bottomPaddingOverride;
  final double? topPaddingOverride;

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    final topPad = topPaddingOverride ??
        (showChrome ? r.chromeTopPadding : r.viewPadding.top + 16);
    final bottomPad = bottomPaddingOverride ??
        (cta != null ? r.ctaBottomPadding : r.viewPadding.bottom + 24);

    Widget body = Padding(
      padding: EdgeInsets.fromLTRB(V5.gutter, topPad, V5.gutter, bottomPad),
      child: child,
    );
    if (scroll) {
      body = SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: body,
      );
    }

    return V5Screen(
      index: index,
      onBack: onBack,
      inverted: inverted,
      background: background,
      showChrome: showChrome,
      children: [
        ...backgroundLayers,
        Positioned.fill(child: body),
        if (cta != null) cta!,
      ],
    );
  }
}

/// Gold-standard keyboard-aware form scaffold.
///
/// The hard part of a form screen is the keyboard. When it opens it must:
/// (a) never squeeze, rescale, or swap the layout, (b) keep the focused field
/// visible, and (c) keep the submit button pinned directly above the keyboard.
/// The recipe — used identically by the standalone [LoginScreen] and the S13
/// onboarding sign-in so the two behave the same — is:
///
/// ```
/// Scaffold(resizeToAvoidBottomInset: true)
///   └ SafeArea(bottom: false)                     // top inset → never hits status bar
///      └ Column
///         ├ Expanded(SingleChildScrollView(child)) // scrolls; viewport ends at footer
///         └ SafeArea(top: false) → footer          // pinned above keyboard / home bar
/// ```
///
/// With [resizeToAvoidBottomInset] the Scaffold lifts the whole Column above
/// the keyboard, so the scroll viewport ends exactly at the footer and the
/// focused field auto-scrolls to rest right above it — the two can never
/// overlap and no manual scrolling is needed.
///
/// This owns its own [Scaffold], so when used inside another resizing Scaffold
/// (e.g. the onboarding PageView) that outer Scaffold should set
/// `resizeToAvoidBottomInset: false` — otherwise both resize and sibling pages
/// get squeezed.
class V5KeyboardForm extends StatelessWidget {
  const V5KeyboardForm({
    super.key,
    required this.child,
    required this.footer,
    this.backgroundLayers = const <Widget>[],
    this.background = V5.bg,
    this.scrollPadding,
  });

  /// The scrollable form content (header, fields, etc.).
  final Widget child;

  /// Pinned bottom action — rides above the keyboard when open, above the
  /// home indicator otherwise.
  final Widget footer;

  /// Decorative layers painted behind [child] (ambient glows, textures).
  final List<Widget> backgroundLayers;

  final Color background;

  /// Padding around [child] inside the scroll view. Defaults to the standard
  /// gutter with a small top gap (chrome is expected to scroll in flow).
  final EdgeInsets? scrollPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          ...backgroundLayers,
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: scrollPadding ??
                        const EdgeInsets.fromLTRB(
                          V5.gutter,
                          V5.space8,
                          V5.gutter,
                          V5.space24,
                        ),
                    child: child,
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      V5.gutter,
                      V5.space12,
                      V5.gutter,
                      0,
                    ),
                    child: footer,
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
    final border = inverted ? V5.heroBorderHi : V5.borderHi;
    final topInset = MediaQuery.viewPaddingOf(context).top + 12;
    return Positioned(
      top: topInset,
      left: V5.gutter,
      right: V5.gutter,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IgnorePointer(
                ignoring: onBack == null,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: onBack == null ? 0 : 1,
                  child: GestureDetector(
                    onTap: onBack,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: border, width: 1),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: fg,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                '${index.toString().padLeft(2, '0')} — ${total.toString().padLeft(2, '0')}',
                style: V5.text(
                  context,
                  size: 11,
                  weight: FontWeight.w600,
                  color: fgSoft,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
    ('Khởi đầu', 1, 8),
    ('Đánh giá', 9, 12),
    ('Lộ trình', 13, 17),
  ];

  @override
  Widget build(BuildContext context) {
    final fg = inverted ? V5.invInk : V5.ink;
    final fgFaint = inverted ? V5.invInkFaint : V5.inkFaint;
    final track = inverted ? V5.heroBorder : V5.border;
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
            padding: EdgeInsets.only(right: i == _phases.length - 1 ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 2,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct),
                      duration: const Duration(milliseconds: 600),
                      curve: V5.curve,
                      builder: (_, value, __) => LinearProgressIndicator(
                        value: value,
                        backgroundColor: track,
                        valueColor: AlwaysStoppedAnimation<Color>(fg),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  p.$1.toUpperCase(),
                  style: V5
                      .eyebrow(
                        context,
                        color: active ? fg : fgFaint,
                      )
                      .copyWith(fontSize: 9, letterSpacing: 1.2),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SCREEN HEADER (eyebrow + headline + optional subhead)
// ═══════════════════════════════════════════════════════════════

/// Standard premium-app header pattern: small eyebrow tag, big display
/// headline, optional supporting paragraph. Each line fades in staggered.
class V5ScreenHeader extends StatelessWidget {
  const V5ScreenHeader({
    super.key,
    this.eyebrow,
    this.eyebrowSparkle = false,
    required this.title,
    this.subtitle,
    this.dark = false,
    this.size = V5HeaderSize.large,
    this.delayMs = 0,
  });

  final String? eyebrow;
  final bool eyebrowSparkle;
  final String title;
  final String? subtitle;
  final bool dark;
  final V5HeaderSize size;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? V5.invInk : V5.ink;
    final subColor = dark ? V5.invInkSoft : V5.inkSoft;
    final titleStyle = switch (size) {
      V5HeaderSize.display => V5.display(context, color: titleColor),
      V5HeaderSize.large => V5.headline(context, color: titleColor),
      V5HeaderSize.medium => V5.titleLg(context, color: titleColor),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          V5FadeIn(
            delay: Duration(milliseconds: delayMs),
            slideY: 6,
            child:
                V5Eyebrow(label: eyebrow!, dark: dark, sparkle: eyebrowSparkle),
          ),
          const SizedBox(height: 14),
        ],
        V5FadeIn(
          delay: Duration(milliseconds: delayMs + 60),
          slideY: 10,
          child: Text(title, style: titleStyle),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          V5FadeIn(
            delay: Duration(milliseconds: delayMs + 120),
            slideY: 8,
            child: Text(
              subtitle!,
              style: V5.body(context, color: subColor),
            ),
          ),
        ],
      ],
    );
  }
}

enum V5HeaderSize { display, large, medium }

// ═══════════════════════════════════════════════════════════════
// EYEBROW + ACCENT MARKS
// ═══════════════════════════════════════════════════════════════

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
    final fg = dark ? V5.invInk : V5.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.06)
            : V5.ink.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(V5.radiusFull),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.10)
              : V5.ink.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sparkle)
            const Padding(
              padding: EdgeInsets.only(right: 7),
              child: V5Sparkle(size: 11),
            )
          else
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: V5.yellow,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            label.toUpperCase(),
            style: V5.eyebrow(context, color: fg),
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
  const V5PulseDot({super.key, this.color = const Color(0xFF22C55E)});

  final Color color;

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
      duration: const Duration(milliseconds: 1800),
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
        scale: 1 + _controller.value * 0.25,
        child: Opacity(
          opacity: 1 - _controller.value * 0.5,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.6),
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

// ═══════════════════════════════════════════════════════════════
// CTA
// ═══════════════════════════════════════════════════════════════

/// Primary call-to-action — confident, still by default. Premium apps
/// don't pulse their CTAs (looks nervous). Only press feedback + a
/// subtle one-time entrance.
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

class _V5PillCTAState extends State<V5PillCTA> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
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
    return Positioned(
      left: V5.gutter,
      right: V5.gutter,
      bottom: widget.bottom,
      child: GestureDetector(
        onTap: enabled ? widget.onTap : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          scale: _pressed ? 0.97 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: V5.curveSharp,
            height: 60,
            padding: EdgeInsets.fromLTRB(28, 0, enabled ? 8 : 28, 0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(V5.radiusFull),
              border:
                  enabled ? null : Border.all(color: V5.borderHi, width: 1.4),
              boxShadow: enabled
                  ? (widget.yellow ? V5.yellowGlow(0.34) : V5.elevation4)
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
                      weight: FontWeight.w700,
                      color: fg,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: V5.curveSharp,
                  width: enabled ? 44 : 24,
                  height: enabled ? 44 : 24,
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HERO CARD (dark gradient surface, premium depth)
// ═══════════════════════════════════════════════════════════════

class V5HeroCard extends StatelessWidget {
  const V5HeroCard({
    super.key,
    required this.child,
    this.borderRadius = V5.radiusXl,
    this.padding,
    this.elevation = 2,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final int elevation;

  @override
  Widget build(BuildContext context) {
    final shadows = switch (elevation) {
      1 => V5.elevation1,
      3 => V5.elevation3,
      _ => V5.elevation2,
    };
    return RepaintBoundary(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: V5.heroGradient,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: V5.heroBorder),
          boxShadow: shadows,
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // Subtle inner top highlight — gives the hero edge a refined
            // "embossed" look like Future / Caliber dark cards.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: borderRadius,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CARD — light surface with refined depth
// ═══════════════════════════════════════════════════════════════

/// Premium light-surface card. Use this instead of one-off Container
/// decorations to keep elevation + radius + border consistent.
class V5Card extends StatelessWidget {
  const V5Card({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = V5.radiusLg,
    this.elevation = 1,
    this.selected = false,
    this.tint = V5CardTint.cream,
    this.onTap,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final int elevation;
  final bool selected;
  final V5CardTint tint;
  final VoidCallback? onTap;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final bg = switch (tint) {
      V5CardTint.cream => V5.surface,
      V5CardTint.creamSoft => V5.surfaceSoft,
      V5CardTint.creamRaised => V5.surfaceRaised,
      V5CardTint.ink => V5.heroSurface,
      V5CardTint.transparent => Colors.transparent,
    };
    final shadows = !border
        ? const <BoxShadow>[]
        : switch (elevation) {
            0 => const <BoxShadow>[],
            2 => V5.elevation2,
            3 => V5.elevation3,
            _ => V5.elevation1,
          };
    final borderColor = tint == V5CardTint.ink
        ? V5.heroBorder
        : (selected ? V5.ink : V5.border);
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: V5.curveSharp,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border
            ? Border.all(color: borderColor, width: selected ? 1.4 : 1)
            : null,
        boxShadow: shadows,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}

enum V5CardTint { cream, creamSoft, creamRaised, ink, transparent }

// ═══════════════════════════════════════════════════════════════
// DIVIDER — refined hairline
// ═══════════════════════════════════════════════════════════════

class V5Divider extends StatelessWidget {
  const V5Divider({super.key, this.dark = false, this.indent = 0});

  final bool dark;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: indent),
      height: 1,
      color: dark ? V5.heroBorder : V5.border,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CHECK CIRCLE — refined selected indicator
// ═══════════════════════════════════════════════════════════════

class V5CheckCircle extends StatelessWidget {
  const V5CheckCircle({
    super.key,
    required this.selected,
    this.size = 22,
    this.dark = false,
  });

  final bool selected;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: V5.curveSharp,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? V5.yellow : Colors.transparent,
        border: selected
            ? null
            : Border.all(
                color: dark ? V5.heroBorderHi : V5.borderHi,
                width: 1.4,
              ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, color: V5.yellowInk, size: size * 0.62)
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// IMAGE SLOT (with intentional fallback for asset-less design)
// ═══════════════════════════════════════════════════════════════

class OnboardingImageSlot extends StatelessWidget {
  const OnboardingImageSlot({
    super.key,
    required this.assetKey,
    required this.caption,
    this.imageAsset,
    this.imageUrl,
    this.dark = true,
    this.showCaption = true,
    this.cameraAiBadge = false,
    this.badgeLabel = 'CAMERA AI',
    this.fit = BoxFit.cover,
  });

  final String assetKey;
  final String caption;
  final String? imageAsset;
  final String? imageUrl;
  final bool dark;
  final bool showCaption;
  final bool cameraAiBadge;
  final String badgeLabel;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageAsset != null || imageUrl != null;

    Widget imageFallback() {
      // Intentional "no asset" state: a refined dark canvas with ambient
      // glow + texture. Looks like an editorial-grade loading state
      // rather than a missing-image placeholder.
      return _RefinedFallback(dark: dark, label: assetKey);
    }

    Widget image() {
      if (imageAsset != null) {
        return Image.asset(
          imageAsset!,
          fit: fit,
          errorBuilder: (_, __, ___) => imageFallback(),
        );
      }
      if (imageUrl != null) {
        return Image.network(
          imageUrl!,
          fit: fit,
          errorBuilder: (_, __, ___) => imageFallback(),
        );
      }
      return imageFallback();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: image()),
        if (hasImage)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: V5.heroVignette(alpha: dark ? 0.34 : 0.12),
              ),
            ),
          ),
        if (cameraAiBadge)
          Positioned(
            top: 14,
            left: 14,
            child: V5Glass(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const V5PulseDot(),
                  const SizedBox(width: 8),
                  Text(
                    badgeLabel.toUpperCase(),
                    style: V5
                        .eyebrow(
                          context,
                          color: dark ? V5.invInk : V5.ink,
                        )
                        .copyWith(fontSize: 9.5),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RefinedFallback extends StatelessWidget {
  const _RefinedFallback({required this.dark, required this.label});

  final bool dark;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: dark ? V5.heroGradient : V5.paperGradient,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient glow — gives the empty surface a soft luminance focal
          // point so it doesn't read as "broken image". The glow is warm
          // when dark, cool-cream when light, matching the palette.
          Center(
            child: V5AmbientGlow(
              size: const Size(280, 280),
              opacity: dark ? 0.18 : 0.10,
              color: V5.yellow,
            ),
          ),
          // Subtle film grain texture — escapes the flat digital look.
          Positioned.fill(child: V5Texture(opacity: dark ? 0.05 : 0.025)),
          // Centered logomark + caption — feels editorial, not error-state.
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MonogramV(dark: dark),
                  const SizedBox(height: 14),
                  Text(
                    'VIKA',
                    style: V5
                        .eyebrow(
                          context,
                          color: dark ? V5.invInk : V5.ink,
                        )
                        .copyWith(fontSize: 11, letterSpacing: 4),
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

class _MonogramV extends StatelessWidget {
  const _MonogramV({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: V5.accentGradient,
        shape: BoxShape.circle,
        boxShadow: V5.yellowGlow(0.24),
      ),
      child: Center(
        child: Text(
          'V',
          style: V5.text(
            context,
            size: 28,
            weight: FontWeight.w800,
            color: V5.yellowInk,
            letterSpacing: -1,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AMBIENT GLOW (radial gradient highlight)
// ═══════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════
// TEXTURE — subtle film grain overlay
// ═══════════════════════════════════════════════════════════════

/// Subtle noise overlay. Premium apps (Calm, Headspace, Future, Caliber)
/// use this to escape the "flat digital" feel. Generated procedurally
/// from a hash so no asset dependency.
class V5Texture extends StatelessWidget {
  const V5Texture({super.key, this.opacity = 0.04, this.density = 1.4});

  final double opacity;
  final double density;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _TexturePainter(opacity: opacity, density: density),
      ),
    );
  }
}

class _TexturePainter extends CustomPainter {
  _TexturePainter({required this.opacity, required this.density});

  final double opacity;
  final double density;

  @override
  void paint(Canvas canvas, Size size) {
    // Deterministic seed so repaint doesn't shimmer.
    final rng = math.Random(42);
    final count = (size.width * size.height * 0.0008 * density).round();
    final paint = Paint()..isAntiAlias = false;
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final a = rng.nextDouble() * opacity;
      final tone = rng.nextDouble();
      paint.color =
          (tone > 0.5 ? Colors.white : Colors.black).withValues(alpha: a);
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TexturePainter old) =>
      old.opacity != opacity || old.density != density;
}

// ═══════════════════════════════════════════════════════════════
// GLASS (frosted morphism)
// ═══════════════════════════════════════════════════════════════

class V5Glass extends StatelessWidget {
  const V5Glass({
    super.key,
    required this.child,
    this.borderRadius = V5.radiusFull,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.tint = const Color(0x0FFFFFFF),
    this.borderColor,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color tint;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.14),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STAT TILE — labeled numeric block (for plan summary)
// ═══════════════════════════════════════════════════════════════

class V5StatTile extends StatelessWidget {
  const V5StatTile({
    super.key,
    required this.value,
    required this.label,
    this.dark = false,
    this.accent = false,
  });

  final String value;
  final String label;
  final bool dark;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? V5.invInk : V5.ink;
    final fgSoft = dark ? V5.invInkSoft : V5.inkSoft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: V5.text(
            context,
            size: 28,
            weight: FontWeight.w800,
            color: accent ? V5.yellow : fg,
            letterSpacing: -1.2,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: V5.eyebrow(context, color: fgSoft).copyWith(fontSize: 9.5),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ICON BUBBLE — refined circular icon container
// ═══════════════════════════════════════════════════════════════

class V5IconBubble extends StatelessWidget {
  const V5IconBubble({
    super.key,
    required this.icon,
    this.size = 40,
    this.tint = V5IconBubbleTint.yellow,
    this.dark = false,
  });

  final IconData icon;
  final double size;
  final V5IconBubbleTint tint;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tint) {
      V5IconBubbleTint.yellow => (V5.yellowSoft, V5.yellowDeep),
      V5IconBubbleTint.ink => (
          dark
              ? Colors.white.withValues(alpha: 0.08)
              : V5.ink.withValues(alpha: 0.06),
          dark ? V5.invInk : V5.ink,
        ),
      V5IconBubbleTint.accent => (V5.yellow, V5.yellowInk),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: tint == V5IconBubbleTint.yellow
            ? Border.all(color: V5.yellow.withValues(alpha: 0.22))
            : null,
      ),
      child: Icon(icon, color: fg, size: size * 0.48),
    );
  }
}

enum V5IconBubbleTint { yellow, ink, accent }

// ═══════════════════════════════════════════════════════════════
// CHOICE ROW — multi-select row used by S02
// ═══════════════════════════════════════════════════════════════

class V5ChoiceRow extends StatelessWidget {
  const V5ChoiceRow({
    super.key,
    required this.label,
    this.sub,
    required this.selected,
    required this.onTap,
    this.delay = Duration.zero,
  });

  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return V5FadeIn(
      delay: delay,
      slideY: 6,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dense = constraints.maxHeight <= 62;
          final showSub = sub != null && !dense;
          return GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: V5.curveSharp,
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 14 : 16,
                vertical: dense ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: selected ? V5.ink : V5.surface,
                borderRadius: BorderRadius.circular(V5.radiusMd),
                border: Border.all(
                  color: selected ? V5.ink : V5.border,
                  width: selected ? 1.2 : 1,
                ),
                boxShadow: selected ? V5.elevation2 : V5.elevation1,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: dense ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: V5
                              .title(
                                context,
                                color: selected ? V5.invInk : V5.ink,
                              )
                              .copyWith(
                                fontSize: dense ? 13.5 : 14.5,
                                height: dense ? 1.18 : 1.15,
                              ),
                        ),
                        if (showSub) ...[
                          const SizedBox(height: 3),
                          Text(
                            sub!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V5
                                .bodySm(
                                  context,
                                  color: selected ? V5.invInkSoft : V5.inkSoft,
                                )
                                .copyWith(fontSize: 11.5, height: 1.2),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  V5CheckCircle(selected: selected, size: dense ? 20 : 22),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BODY SILHOUETTE — decoration only (used by S04)
//
// Uses the real PNG silhouette from assets/images/body_*.png. No
// pinpoint markers — selected pain areas are shown in the surrounding
// chip UI, not painted on top of the body (point-on-2D-silhouette
// always reads as "floating", not anatomical).
// ═══════════════════════════════════════════════════════════════

class V5BodySilhouette extends StatelessWidget {
  const V5BodySilhouette({
    super.key,
    this.gender,
    this.hasSelection = false,
    this.selectedAreas = const <String>[],
    this.noPain = false,
  });

  final String? gender;
  final bool hasSelection;
  final List<String> selectedAreas;
  final bool noPain;

  @override
  Widget build(BuildContext context) {
    final asset = gender == 'female'
        ? 'assets/images/body_female.png'
        : 'assets/images/body_male.png';
    final aspect = gender == 'female' ? 200 / 612 : 200 / 676;
    return Center(
      child: AspectRatio(
        aspectRatio: aspect,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Soft warm glow behind the body — slightly more intense
            // when something is selected, so the silhouette feels
            // "active" without using floating markers.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.7,
                      colors: [
                        V5.yellow.withValues(alpha: hasSelection ? 0.14 : 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Silhouette image, recolored to a warm tone that reads
            // on the dark hero. Slightly more saturated when selected.
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                hasSelection
                    ? V5.yellow.withValues(alpha: 0.78)
                    : V5.invInk.withValues(alpha: 0.65),
                BlendMode.srcIn,
              ),
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            if (!noPain && selectedAreas.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: _PainRibbonPainter(
                    selectedAreas: List<String>.of(selectedAreas),
                  ),
                ),
              ),
            if (noPain)
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: V5.success.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: V5.success.withValues(alpha: 0.38),
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: V5.success,
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PainRibbonPainter extends CustomPainter {
  const _PainRibbonPainter({required this.selectedAreas});

  final List<String> selectedAreas;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    final glow = Paint()
      ..color = V5.yellow.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final ribbon = Paint()
      ..shader = LinearGradient(
        colors: [
          V5.yellowSpark.withValues(alpha: 0.96),
          V5.yellow.withValues(alpha: 0.74),
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final area in selectedAreas) {
      _drawArea(canvas, size, area, glow, true);
      _drawArea(canvas, size, area, ribbon, false);
    }
    canvas.restore();
  }

  void _drawArea(
    Canvas canvas,
    Size size,
    String area,
    Paint paint,
    bool isGlow,
  ) {
    final stroke = (isGlow ? size.width * 0.15 : size.width * 0.07)
        .clamp(isGlow ? 10.0 : 5.0, isGlow ? 20.0 : 10.0)
        .toDouble();
    paint.strokeWidth = stroke;
    Offset p(double x, double y) => Offset(size.width * x, size.height * y);

    switch (area) {
      case 'neck':
        final path = Path()
          ..moveTo(size.width * 0.34, size.height * 0.23)
          ..quadraticBezierTo(
            size.width * 0.50,
            size.height * 0.19,
            size.width * 0.66,
            size.height * 0.23,
          );
        canvas.drawPath(path, paint);
        break;
      case 'back':
        final path = Path()
          ..moveTo(size.width * 0.40, size.height * 0.43)
          ..quadraticBezierTo(
            size.width * 0.50,
            size.height * 0.47,
            size.width * 0.60,
            size.height * 0.43,
          );
        canvas.drawPath(path, paint);
        break;
      case 'hip':
        final path = Path()
          ..moveTo(size.width * 0.33, size.height * 0.55)
          ..quadraticBezierTo(
            size.width * 0.50,
            size.height * 0.61,
            size.width * 0.67,
            size.height * 0.55,
          );
        canvas.drawPath(path, paint);
        break;
      case 'knee':
        canvas.drawLine(p(0.39, 0.74), p(0.49, 0.74), paint);
        canvas.drawLine(p(0.51, 0.74), p(0.61, 0.74), paint);
        break;
      case 'wrist':
        canvas.drawLine(p(0.23, 0.48), p(0.25, 0.55), paint);
        canvas.drawLine(p(0.77, 0.48), p(0.75, 0.55), paint);
        break;
      default:
        final path = Path()
          ..moveTo(size.width * 0.35, size.height * 0.34)
          ..quadraticBezierTo(
            size.width * 0.50,
            size.height * 0.30,
            size.width * 0.65,
            size.height * 0.34,
          )
          ..moveTo(size.width * 0.34, size.height * 0.62)
          ..quadraticBezierTo(
            size.width * 0.50,
            size.height * 0.66,
            size.width * 0.66,
            size.height * 0.62,
          );
        canvas.drawPath(path, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PainRibbonPainter oldDelegate) =>
      oldDelegate.selectedAreas.length != selectedAreas.length ||
      !oldDelegate.selectedAreas.every(selectedAreas.contains);
}

// ═══════════════════════════════════════════════════════════════
// BODY DIAGRAM — legacy procedural skeleton (kept for compat)
// ═══════════════════════════════════════════════════════════════

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
    canvas.translate(
        (size.width - 200 * scale) / 2, (size.height - 260 * scale) / 2);
    canvas.scale(scale);
    final body = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
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
    draw(_poly([
      const Offset(78, 168),
      const Offset(75, 215),
      const Offset(78, 250),
      const Offset(92, 250),
      const Offset(95, 215),
      const Offset(92, 168)
    ]));
    draw(_poly([
      const Offset(108, 168),
      const Offset(105, 215),
      const Offset(108, 250),
      const Offset(122, 250),
      const Offset(125, 215),
      const Offset(122, 168)
    ]));

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
      canvas.drawCircle(
          center, r * 2.6, Paint()..color = V5.yellow.withValues(alpha: 0.24));
      canvas.drawCircle(
          center, r * 1.7, Paint()..color = V5.yellow.withValues(alpha: 0.18));
    }
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = selected ? V5.yellow : Colors.white.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = selected ? V5.yellow : Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _BodyDiagramPainter oldDelegate) =>
      oldDelegate.painAreas != painAreas || oldDelegate.noPain != noPain;
}

// ═══════════════════════════════════════════════════════════════
// BRAND MARKS — Google / Apple / Facebook for social signin.
//
// All three load their authentic brand logos from the SVG assets in
// assets/brands/. Apple is a single monochrome path tinted to ink; Google
// and Facebook keep their native brand colors.
// ═══════════════════════════════════════════════════════════════

class V5GoogleMark extends StatelessWidget {
  const V5GoogleMark({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/brands/google.svg',
        width: size,
        height: size,
      );
}

class V5FacebookMark extends StatelessWidget {
  const V5FacebookMark({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/brands/facebook.svg',
        width: size,
        height: size,
      );
}

class V5AppleMark extends StatelessWidget {
  const V5AppleMark({super.key, this.size = 18, this.color = V5.ink});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/brands/apple.svg',
        // The Apple glyph is portrait; size by height and let width follow.
        height: size + 2,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}

