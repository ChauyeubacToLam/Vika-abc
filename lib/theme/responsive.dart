// Vika responsive sizing — Premium Ivory main app.
//
// The whole Premium Ivory v1 prototype was designed against a 390×844pt
// reference (iPhone 14 baseline). Every padding, font size, card width
// is calibrated to that. To run cleanly on the phone size range
// (375 → 430pt iOS, 360 → 412dp Android), values need to scale
// proportionally — but tightly clamped, so a Pro Max phone doesn't
// inflate everything by 10% and feel cartoonish.
//
// Usage:
// ```dart
// final r = Responsive.of(context);
// padding: EdgeInsets.all(r.w(24)),
// fontSize: r.sp(46),
// child: SizedBox(height: r.gap(18)),
// ```
//
// Or via the extension (`context.r.w(24)`).
//
// Layout decisions (not just sizing) use the breakpoint flags:
// ```dart
// if (r.isCompact) {
//   // single-column, tighter
// } else {
//   // standard / large layout
// }
// ```

import 'package:flutter/widgets.dart';

class Responsive {
  Responsive._({
    required this.size,
    required this.scale,
    required this.textScaler,
  });

  /// Physical screen size in logical pixels.
  final Size size;

  /// Width-derived scale factor, clamped tightly. Ranges 0.92–1.13.
  final double scale;

  /// User's preferred text scaling, already clamped to [0.9, 1.3] by
  /// `VikaType.clampTextScaler`. We multiply font sizes by this AND by
  /// the screen `scale` factor.
  final TextScaler textScaler;

  // ─── Reference + clamps ────────────────────────────────────────────────

  /// Vika's design baseline width (iPhone 14 / 15). All ratios derive
  /// from this.
  static const double referenceWidth = 390;

  /// Min/max clamp on the screen-derived scale factor. Tight on purpose
  /// — we don't want layouts to noticeably inflate on Pro Max or
  /// shrink on SE. Sub-15% range means visual rhythm holds across the
  /// whole phone size range.
  static const double minScale = 0.92;
  static const double maxScale = 1.13;

  // ─── Breakpoints (used for layout decisions, not sizing) ──────────────

  /// True when the device is narrower than the design baseline. Layouts
  /// may swap to single-column, tighter card padding, smaller hero
  /// stats. Most iPhone SE units land here.
  bool get isCompact => size.width < 380;

  /// 380–410pt. The design baseline range; iPhone 14, 15, most modern
  /// Androids.
  bool get isStandard => size.width >= 380 && size.width < 410;

  /// 410+. Pro Max / large Androids. Layouts can afford slightly more
  /// breathing room (extra inter-card gap, larger hero peek, etc.).
  bool get isLarge => size.width >= 410;

  // ─── Constructors ────────────────────────────────────────────────────

  /// Build a `Responsive` from a `BuildContext`. Reads `MediaQuery.sizeOf`
  /// and `MediaQuery.textScalerOf` once per call.
  factory Responsive.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = (size.width / referenceWidth).clamp(minScale, maxScale);
    final textScaler = MediaQuery.textScalerOf(context);
    return Responsive._(
      size: size,
      scale: scale.toDouble(),
      textScaler: textScaler,
    );
  }

  // ─── Sizing helpers ──────────────────────────────────────────────────

  /// Width-scaled px. Use for padding, card widths, icon button sizes,
  /// margins. Most pixel literals in widgets become `r.w(N)`.
  double w(double px) => px * scale;

  /// Height-scaled px. Rarely needed — most vertical spacing should
  /// follow `w()` because the Vika design's vertical proportions are
  /// driven by horizontal width. Use only when something is genuinely
  /// height-driven (e.g. a card's min-height pegged to viewport).
  double h(double px) => px * scale;

  /// Convenience for vertical gaps. `SizedBox(height: r.gap(18))`.
  double gap(double px) => w(px);

  /// Font sizing. Combines screen scale with the user's text scaler.
  /// Use this for raw `fontSize:` values in TextStyle. The
  /// VikaType.X styles already encode their reference size; multiplying
  /// by `r.scale` adapts them to the device.
  double sp(double px) => textScaler.scale(px * scale);

  // ─── Bottom inset (nav bar handles its own bottom padding) ─────────

  /// Convenience for screens that need to know the home-indicator
  /// inset directly. Most main-app screens get this via
  /// `IvoryBottomNav` reading `MediaQuery.viewPadding.bottom`.
  double get bottomInset {
    return WidgetsBinding
            .instance.platformDispatcher.views.first.padding.bottom /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
  }
}

extension ResponsiveContext on BuildContext {
  /// Shorthand: `context.r.w(24)`.
  Responsive get r => Responsive.of(this);
}
