import 'package:flutter/material.dart';

/// Vika onboarding design tokens — premium athletic system inspired by
/// Future / Caliber / Ladder. Warm cream paper, espresso ink, refined gold.
///
/// All sizing assumes a 390pt reference width; [V5.scale] returns a clamp
/// for adaptive scaling. Spacing follows a 4pt grid. Typography is a
/// closed scale of 8 named styles — do not pick arbitrary sizes.
class V5 {
  const V5._();

  // ─────────────────────────────────────────────────────────────
  // COLOR — warm cream paper, espresso ink, refined gold accent
  // ─────────────────────────────────────────────────────────────

  // Surfaces (warm cream paper, slightly varied for layering)
  static const bg = Color(0xFFF3ECDE); // canvas
  static const bgSoft = Color(0xFFEBE3D2); // recessed
  static const surface = Color(0xFFFAF4E6); // raised card
  static const surfaceSoft = Color(0xFFF6EFDE); // secondary card
  static const surfaceRaised = Color(0xFFFFFBF1); // floating card

  // Dark espresso (richer, less brown than before)
  static const heroBg = Color(0xFF1C1610);
  static const heroBgDeep = Color(0xFF120D08);
  static const heroSurface = Color(0xFF26201A); // raised on dark

  // Ink (text + outlines on light)
  static const ink = Color(0xFF1B1410);
  static Color get inkSoft => ink.withValues(alpha: 0.62);
  static Color get inkFaint => ink.withValues(alpha: 0.38);
  static Color get inkDim => ink.withValues(alpha: 0.20);
  static Color get inkHair => ink.withValues(alpha: 0.06);

  // Inverted ink (text + outlines on dark)
  static const invInk = Color(0xFFFAF4E6);
  static Color get invInkSoft => invInk.withValues(alpha: 0.66);
  static Color get invInkFaint => invInk.withValues(alpha: 0.42);
  static Color get invInkDim => invInk.withValues(alpha: 0.22);

  // Accent — refined gold-amber (warmer, less neon than #FFB701)
  static const yellow = Color(0xFFE5B33A);
  static const yellowDeep = Color(0xFFB7831E);
  static const yellowSpark = Color(0xFFF4D77E); // highlight variant
  static Color get yellowSoft => yellow.withValues(alpha: 0.16);
  static Color get yellowMist => yellow.withValues(alpha: 0.08);
  static const yellowInk = Color(0xFF1B1410); // text on accent

  // Semantic (used sparingly)
  static const success = Color(0xFF4F9F76);
  static const danger = Color(0xFFC85746);
  static const info = Color(0xFF6B89C0);

  // Borders + shadows
  static Color get border => ink.withValues(alpha: 0.06);
  static Color get borderHi => ink.withValues(alpha: 0.12);
  static Color get borderStrong => ink.withValues(alpha: 0.22);
  static Color get heroBorder => Colors.white.withValues(alpha: 0.06);
  static Color get heroBorderHi => Colors.white.withValues(alpha: 0.14);
  static Color get shadow => ink.withValues(alpha: 0.08);
  static Color get shadowDeep => ink.withValues(alpha: 0.18);

  // ─────────────────────────────────────────────────────────────
  // SPACING — 4pt grid (use these constants, not magic numbers)
  // ─────────────────────────────────────────────────────────────

  static const space2 = 2.0;
  static const space4 = 4.0;
  static const space6 = 6.0;
  static const space8 = 8.0;
  static const space10 = 10.0;
  static const space12 = 12.0;
  static const space14 = 14.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space28 = 28.0;
  static const space32 = 32.0;
  static const space40 = 40.0;
  static const space48 = 48.0;
  static const space56 = 56.0;
  static const space64 = 64.0;

  /// Outer screen gutter (each side).
  static const gutter = 24.0;

  /// Standard vertical rhythm between major sections.
  static const sectionGap = 28.0;

  // ─────────────────────────────────────────────────────────────
  // RADII — corner system
  // ─────────────────────────────────────────────────────────────

  static const radiusXs = 8.0; // chips, pills, small badges
  static const radiusSm = 12.0; // buttons, small cards
  static const radiusMd = 16.0; // standard cards
  static const radiusLg = 22.0; // hero-adjacent surfaces
  static const radiusXl = 28.0; // hero cards
  static const radius2xl = 36.0; // big editorial surfaces
  static const radiusFull = 999.0; // pills

  // ─────────────────────────────────────────────────────────────
  // SCALE — adaptive sizing helper
  // ─────────────────────────────────────────────────────────────

  static double scale(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w / 390).clamp(0.92, 1.12).toDouble();
  }

  /// Clamp [MediaQuery.textScaler] to a tasteful onboarding range.
  /// Honors the user's preference (so an accessibility user still gets
  /// bigger text) but prevents 1.5×+ scales from blowing apart hand-tuned
  /// layouts. Apply once at the navigator root via [MediaQuery].
  static TextScaler clampedTextScaler(BuildContext context) {
    final raw = MediaQuery.textScalerOf(context);
    final s = raw.scale(14) / 14;
    final clamped = s.clamp(0.92, 1.15);
    return TextScaler.linear(clamped);
  }

  // ─────────────────────────────────────────────────────────────
  // TYPOGRAPHY — closed scale, premium athletic feel
  //
  // Sizes designed for 390pt reference. Multiply by [scale] in screens
  // where adaptive sizing matters most (display headlines).
  //
  // Scale (refer to these by name, do NOT pick arbitrary sizes):
  //   display    44/0.96   w800  -1.8     hero headlines (rare)
  //   headline   28/1.04   w800  -1.0     section headlines
  //   titleLg    22/1.18   w700  -0.5     card titles, prominent body
  //   title      17/1.30   w700  -0.3     standard titles, dense body
  //   body       15/1.46   w500  -0.1     primary running text
  //   bodySm     13/1.46   w500  -0.05    secondary running text
  //   eyebrow    10.5/1.0  w700  1.6      uppercase label
  //   caption    11/1.30   w500  0        meta, supplementary
  //   stat       48/0.94   w800  -2.6     numeric stats, scores
  // ─────────────────────────────────────────────────────────────

  /// Base text helper — prefer the named scale below unless you have a
  /// specific reason to pick arbitrary values.
  static TextStyle text(
    BuildContext context, {
    required double size,
    FontWeight weight = FontWeight.w500,
    Color color = ink,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'BeVietnamPro',
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle display(BuildContext c, {Color? color}) => text(c,
      size: 44,
      weight: FontWeight.w800,
      letterSpacing: -1.8,
      height: 0.96,
      color: color ?? ink);

  static TextStyle headline(BuildContext c, {Color? color}) => text(c,
      size: 28,
      weight: FontWeight.w800,
      letterSpacing: -1.0,
      height: 1.04,
      color: color ?? ink);

  static TextStyle displaySm(BuildContext c, {Color? color}) => text(c,
      size: 36,
      weight: FontWeight.w800,
      letterSpacing: -1.4,
      height: 0.98,
      color: color ?? ink);

  static TextStyle titleLg(BuildContext c, {Color? color}) => text(c,
      size: 22,
      weight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.18,
      color: color ?? ink);

  static TextStyle title(BuildContext c, {Color? color}) => text(c,
      size: 17,
      weight: FontWeight.w700,
      letterSpacing: -0.3,
      height: 1.3,
      color: color ?? ink);

  static TextStyle titleSm(BuildContext c, {Color? color}) => text(c,
      size: 15,
      weight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.25,
      color: color ?? ink);

  static TextStyle bodyLg(BuildContext c, {Color? color}) => text(c,
      size: 16,
      weight: FontWeight.w500,
      letterSpacing: -0.15,
      height: 1.5,
      color: color ?? ink);

  static TextStyle body(BuildContext c, {Color? color}) => text(c,
      size: 15,
      weight: FontWeight.w500,
      letterSpacing: -0.1,
      height: 1.46,
      color: color ?? ink);

  static TextStyle bodySm(BuildContext c, {Color? color}) => text(c,
      size: 13,
      weight: FontWeight.w500,
      letterSpacing: -0.05,
      height: 1.46,
      color: color ?? ink);

  static TextStyle bodyXs(BuildContext c, {Color? color}) => text(c,
      size: 11.5,
      weight: FontWeight.w500,
      letterSpacing: -0.02,
      height: 1.4,
      color: color ?? ink);

  static TextStyle eyebrow(BuildContext c, {Color? color}) => text(c,
      size: 10.5,
      weight: FontWeight.w700,
      letterSpacing: 1.6,
      height: 1.0,
      color: color ?? ink);

  static TextStyle caption(BuildContext c, {Color? color}) => text(c,
      size: 11,
      weight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.3,
      color: color ?? ink);

  static TextStyle stat(BuildContext c, {Color? color}) => text(c,
      size: 48,
      weight: FontWeight.w800,
      letterSpacing: -2.6,
      height: 0.94,
      color: color ?? ink);

  // ─────────────────────────────────────────────────────────────
  // SHADOWS — multi-layer for premium depth
  //
  // Premium apps stack contact (tight, dark) + key (mid, soft) +
  // ambient (wide, faint). Don't use single-layer shadows.
  // ─────────────────────────────────────────────────────────────

  /// Single-layer fallback. Prefer [elevation1+] for premium feel.
  static BoxShadow cardShadow([double alpha = 0.08]) => BoxShadow(
        color: ink.withValues(alpha: alpha),
        blurRadius: 20,
        offset: const Offset(0, 8),
      );

  /// Tight contact shadow — sits under cards on the surface.
  static List<BoxShadow> get elevation1 => [
        BoxShadow(
            color: ink.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1)),
        BoxShadow(
            color: ink.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4)),
      ];

  /// Standard card lift — most surfaces.
  static List<BoxShadow> get elevation2 => [
        BoxShadow(
            color: ink.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1)),
        BoxShadow(
            color: ink.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8)),
        BoxShadow(
            color: ink.withValues(alpha: 0.10),
            blurRadius: 40,
            offset: const Offset(0, 20)),
      ];

  /// Hero card lift — prominent surfaces.
  static List<BoxShadow> get elevation3 => [
        BoxShadow(
            color: ink.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1)),
        BoxShadow(
            color: ink.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 14)),
        BoxShadow(
            color: ink.withValues(alpha: 0.14),
            blurRadius: 56,
            offset: const Offset(0, 28)),
      ];

  /// Floating CTA / selected state lift.
  static List<BoxShadow> get elevation4 => [
        BoxShadow(
            color: ink.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2)),
        BoxShadow(
            color: ink.withValues(alpha: 0.16),
            blurRadius: 40,
            offset: const Offset(0, 20)),
      ];

  /// Accent halo — for selected cards or the primary yellow CTA.
  static List<BoxShadow> yellowGlow([double alpha = 0.32]) => [
        BoxShadow(
            color: yellow.withValues(alpha: alpha),
            blurRadius: 36,
            offset: const Offset(0, 14)),
        BoxShadow(
            color: yellow.withValues(alpha: alpha * 0.45),
            blurRadius: 72,
            offset: const Offset(0, 28)),
      ];

  // ─────────────────────────────────────────────────────────────
  // GRADIENTS
  // ─────────────────────────────────────────────────────────────

  static LinearGradient get heroGradient => const LinearGradient(
        begin: Alignment(-0.8, -1),
        end: Alignment(1, 1),
        colors: [heroBg, heroBgDeep],
      );

  /// Soft cream gradient for raised surfaces — adds subtle dimensionality
  /// without breaking the flat-paper aesthetic.
  static LinearGradient get paperGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [surfaceRaised, surface],
      );

  /// Refined accent gradient — slightly desaturated, with a warmer top.
  static LinearGradient get accentGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [yellowSpark, yellow],
      );

  /// Vignette overlay for hero cards — top transparent → bottom darkened.
  static LinearGradient heroVignette({double alpha = 0.36}) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          heroBgDeep.withValues(alpha: alpha),
        ],
        stops: const [0.4, 1.0],
      );

  // ─────────────────────────────────────────────────────────────
  // CURVES — refined motion
  // ─────────────────────────────────────────────────────────────

  /// Premium ease — slow start, gentle settle. For card reveals.
  static const curve = Cubic(0.16, 1, 0.3, 1);

  /// Sharp ease — quick start, soft end. For button feedback.
  static const curveSharp = Cubic(0.22, 1, 0.36, 1);

  // ─────────────────────────────────────────────────────────────
  // LABELS — Vietnamese mappings (data → display)
  // ─────────────────────────────────────────────────────────────

  static String levelLabel(String? level) {
    return switch (level) {
      'advanced' => 'Nâng cao',
      'intermediate' => 'Trung cấp',
      _ => 'Người mới',
    };
  }
}

/// Responsive metrics derived from [MediaQuery] in one place. Use this
/// instead of scattering `height < 720` ternaries through every screen.
///
/// Height tiers (matches what most v5 screens were already doing, just
/// named and centralized):
///   veryShort  < 640 — iPhone SE 1st gen, very compressed
///   short      < 720 — iPhone SE 2nd/3rd, smaller Androids
///   cozy       < 860 — most phones (iPhone 13, Pixel 7, etc.)
///   tall       ≥ 860 — iPhone Pro Max, large Androids
///
/// Width tiers:
///   narrow  < 360 — older small phones
///   tablet  ≥ 600 — iPad, foldables
class V5Responsive {
  const V5Responsive._({
    required this.size,
    required this.viewPadding,
    required this.textScale,
  });

  final Size size;
  final EdgeInsets viewPadding;

  /// Effective text scale (post-clamping). 1.0 = system default.
  final double textScale;

  factory V5Responsive.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = mq.textScaler.scale(14) / 14;
    return V5Responsive._(
      size: mq.size,
      viewPadding: mq.viewPadding,
      textScale: s,
    );
  }

  // Height tiers
  bool get isVeryShort => size.height < 640;
  bool get isShort => size.height < 720;
  bool get isCozy => size.height < 860;
  bool get isTall => size.height >= 860;

  // Width tiers
  bool get isNarrow => size.width < 360;
  bool get isTablet => size.width >= 600;

  /// Combined density score: higher = more cramped. Combines short
  /// screens AND large text scale settings. Useful when you want one
  /// number to decide compactness rather than a stack of ternaries.
  double get density {
    final heightSlack = ((860 - size.height) / 220).clamp(0.0, 1.0);
    final textPressure = ((textScale - 1.0) / 0.15).clamp(0.0, 1.0);
    return heightSlack * 0.7 + textPressure * 0.3;
  }

  /// True for any screen that needs compressed layouts (short OR large text).
  bool get isDense => density > 0.35;

  /// Pick a value across the three height tiers. [cozy] is required (the
  /// design target); [short] and [veryShort] are step-downs. Tablets
  /// inherit [cozy] unless [tall] is provided.
  T pick<T>({
    required T cozy,
    T? short,
    T? veryShort,
    T? tall,
  }) {
    if (isTall && tall != null) return tall;
    if (isVeryShort && veryShort != null) return veryShort;
    if (isShort) return short ?? veryShort ?? cozy;
    return cozy;
  }

  /// Linear interpolation between two values across a height range.
  /// Smoother than discrete tiers — use for spacing that should scale
  /// gracefully (not for text sizes; those should stay on the closed scale).
  double lerpHeight({
    required double min,
    required double max,
    double minHeight = 640,
    double maxHeight = 900,
  }) {
    final t = ((size.height - minHeight) / (maxHeight - minHeight))
        .clamp(0.0, 1.0);
    return min + (max - min) * t;
  }

  /// Standard top padding for [V5TopChrome]: status bar + chrome height
  /// + a comfortable air gap. Use this instead of magic numbers like 84/96/108.
  double get chromeTopPadding {
    final base = viewPadding.top + 12 + 38 + 16 + 2 + 8 + 12;
    return base + pick(cozy: 18.0, short: 8.0, veryShort: 2.0);
  }

  /// Standard bottom padding clearing the floating [V5PillCTA]. The CTA
  /// itself is 60pt tall + 32pt bottom inset; we add breathing room.
  double get ctaBottomPadding {
    return viewPadding.bottom + 60 + 32 + pick(cozy: 24.0, short: 16.0, veryShort: 10.0);
  }
}
