import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VFTheme {
  const VFTheme._();

  static const Color background = Color(0xFFF0EDE6);
  static const Color surface = Color(0xFFFEFCF7);
  static const Color white = Color(0xFFFFFFFF);

  static const Color jade = Color(0xFF1B6B52);
  static const Color jadeDark = Color(0xFF0F4435);
  static const Color jadeMid = Color(0xFF18594A);
  static const Color jadeGlow = Color(0xFF5CEAA8);
  static const Color jadeMist = Color(0xFFD4E8DF);
  static const Color jadeLight = Color(0xFFEAF3EE);

  static const Color text = Color(0xFF181B19);
  static const Color textSecondary = Color(0xFF4A4D47);
  static const Color textMuted = Color(0xFF97958D);

  static const Color amber = Color(0xFFB87320);
  static const Color amberBg = Color(0xFFFDF3E2);
  static const Color coral = Color(0xFFB84435);
  static const Color coralBg = Color(0xFFFAECE8);
  static const Color blue = Color(0xFF2B5EA6);
  static const Color blueBg = Color(0xFFE8EFF8);
  static const Color purple = Color(0xFF7040B8);
  static const Color purpleDark = Color(0xFF2A1548);
  static const Color purpleBg = Color(0xFFEDE4F8);

  static const Color bg = background;
  static const Color bgDeep = Color(0xFFECE7DE);
  static const Color surfaceAlt = Color(0xFFF6F2EB);
  static const Color accent = jade;
  static const Color accentBg = jadeMist;
  static const Color accentText = jadeDark;
  static const Color textSec = textSecondary;

  static const double cardRadiusValue = 24;
  static const double tightCardRadius = 22;
  static const double smallRadiusValue = 16;
  static const double navHeight = 78;
  static const double fabSize = 52;

  static const LinearGradient jadeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [jade, jadeDark],
  );

  static const LinearGradient jadeCardGradient = LinearGradient(
    begin: Alignment(-0.86, -1.0),
    end: Alignment(1.0, 1.0),
    colors: [jadeMid, jadeDark, Color(0xFF0A2E22)],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient purpleCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purpleDark, Color(0xFF170D2A)],
  );

  static const LinearGradient jadeProgressGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [jade, jadeGlow],
  );

  static double scale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / 393).clamp(0.85, 1.15).toDouble();
  }

  static double sp(BuildContext context, double size) => size * scale(context);

  static EdgeInsets insets(
    BuildContext context, {
    double horizontal = 18,
    double top = 0,
    double bottom = 0,
  }) {
    final s = scale(context);
    return EdgeInsets.fromLTRB(
      horizontal * s,
      top * s,
      horizontal * s,
      bottom * s,
    );
  }

  static BorderRadius radius([double value = cardRadiusValue]) =>
      BorderRadius.circular(value);

  static Color alpha(Color color, double opacity) =>
      color.withValues(alpha: opacity);

  static Color get hairline => text.withValues(alpha: 0.06);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF181B19).withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: const Color(0xFF181B19).withValues(alpha: 0.05),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ];

  static List<BoxShadow> get jadeShadow => [
        BoxShadow(
          color: jade.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: jade.withValues(alpha: 0.12),
          blurRadius: 32,
          offset: const Offset(0, 14),
        ),
      ];

  static List<BoxShadow> get purpleShadow => [
        BoxShadow(
          color: purple.withValues(alpha: 0.16),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: purple.withValues(alpha: 0.08),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];

  static BoxDecoration surfaceCard({
    double radiusValue = cardRadiusValue,
    Color color = surface,
    bool withBorder = true,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radiusValue),
      border: withBorder ? Border.all(color: hairline) : null,
      boxShadow: boxShadow ?? cardShadow,
    );
  }

  static BoxDecoration navDecoration() {
    return BoxDecoration(
      color: background.withValues(alpha: 0.92),
      border: Border(
        top: BorderSide(color: text.withValues(alpha: 0.05), width: 0.5),
      ),
    );
  }

  static TextStyle textStyle(
    BuildContext context, {
    required double size,
    FontWeight weight = FontWeight.w500,
    Color color = text,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) {
    return GoogleFonts.dmSans(
      fontSize: sp(context, size),
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
    );
  }

  static double cardRadius(BuildContext context) => 24 * scale(context);

  static double smallRadius(BuildContext context) => 16 * scale(context);

  static double iconTileRadius(BuildContext context) => 12 * scale(context);

  static double font(BuildContext context, double size) => sp(context, size);

  static EdgeInsets screenPadding(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: 18 * scale(context));

  static double sectionGap(BuildContext context) => 10 * scale(context);

  static TextStyle headerLarge(BuildContext context, {Color color = text}) {
    return textStyle(
      context,
      size: 22,
      weight: FontWeight.w800,
      color: color,
      letterSpacing: -0.5,
      height: 1.05,
    );
  }

  static TextStyle sectionTitle(BuildContext context, {Color color = text}) {
    return textStyle(
      context,
      size: 16,
      weight: FontWeight.w700,
      color: color,
      letterSpacing: -0.3,
      height: 1.1,
    );
  }

  static TextStyle body(BuildContext context, {Color color = textSecondary}) {
    return textStyle(
      context,
      size: 13,
      weight: FontWeight.w600,
      color: color,
      height: 1.3,
    );
  }

  static TextStyle muted(BuildContext context, {double size = 11}) {
    return textStyle(
      context,
      size: size,
      weight: FontWeight.w500,
      color: textMuted,
      height: 1.3,
    );
  }

  static TextStyle label(BuildContext context, {Color color = textMuted}) {
    return textStyle(
      context,
      size: 10,
      weight: FontWeight.w700,
      color: color,
      letterSpacing: 0.8,
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: jade,
        onPrimary: white,
        secondary: blue,
        onSecondary: white,
        surface: surface,
        onSurface: text,
        error: coral,
        onError: white,
      ),
    );

    final textTheme = GoogleFonts.dmSansTextTheme(base.textTheme)
        .apply(bodyColor: text, displayColor: text);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: hairline,
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
      scaffoldBackgroundColor: background,
      cardColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

class VFScrollBehavior extends MaterialScrollBehavior {
  const VFScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    this.sigma = 28,
    this.decoration,
  });

  final Widget child;
  final double sigma;
  final Decoration? decoration;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: decoration ?? VFTheme.navDecoration(),
          child: child,
        ),
      ),
    );
  }
}

/// Primary jade-pill CTA. Ported from the deleted onboarding/vf_theme.dart so
/// the rest of the codebase keeps working off a single theme module.
class VFButton extends StatelessWidget {
  const VFButton({
    super.key,
    required this.label,
    this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: 54 * s,
        decoration: BoxDecoration(
          color: enabled ? VFTheme.jade : VFTheme.bgDeep,
          borderRadius: BorderRadius.circular(16 * s),
          boxShadow: enabled ? VFTheme.jadeShadow : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: VFTheme.textStyle(
            context,
            size: 15,
            weight: FontWeight.w800,
            color: enabled ? Colors.white : VFTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VikaIvory — Premium Ivory register for the active-exercise v8 screen.
//
// Added alongside VFTheme (not replacing it). All hex values come from the
// locked JSX prototype (vika-active-exercise-ivory-v8.jsx) and the Canonical
// Numbers doc. Pure black (#000000) is intentionally absent.
//
// Font: Plus Jakarta Sans, bundled as asset font in assets/fonts/.
// ═══════════════════════════════════════════════════════════════════════════════

class VikaIvory {
  const VikaIvory._();

  // ─── Page & scaffold ───

  /// Page background (outside the camera view). JSX: pageBg '#EBE3D2'
  static const Color bg = Color(0xFFEBE3D2);

  /// Soft page bg variant.
  static const Color bgSoft = Color(0xFFF5F0E5);

  /// White surface for cards / pause overlay. JSX: surface '#FFFFFF'
  static const Color surface = Color(0xFFFFFFFF);

  /// Soft surface, cream. JSX: surfaceSoft '#FBF6EA'
  static const Color surfaceSoft = Color(0xFFFBF6EA);

  /// Dark scaffold behind camera. JSX: scaffoldBg '#15110D'
  static const Color heroBg = Color(0xFF15110D);

  /// Slightly lighter scaffold. JSX: scaffoldMid '#1F1812'
  static const Color heroBgDeep = Color(0xFF1F1812);

  // ─── Ink (light-on-dark) ───

  /// Inverted ink, near-white cream. JSX: invInk '#FBF6EA'
  static const Color ink = Color(0xFF2A1F12);

  /// Dark ink at 0.62 opacity. JSX: inkSoft 'rgba(42, 31, 18, 0.62)'
  static Color get inkSoft => ink.withValues(alpha: 0.62);

  /// Dark ink at 0.38 opacity. JSX: inkFaint 'rgba(42, 31, 18, 0.38)'
  static Color get inkFaint => ink.withValues(alpha: 0.38);

  /// Inverted ink (cream white on dark). JSX: invInk '#FBF6EA'
  static const Color invInk = Color(0xFFFBF6EA);

  /// Inverted ink at 0.70 opacity.
  static Color get invInkSoft => invInk.withValues(alpha: 0.70);

  /// Inverted ink at 0.45 opacity.
  static Color get invInkDim => invInk.withValues(alpha: 0.45);

  /// Inverted ink at 0.30 opacity. JSX: invInkFaint 'rgba(251, 246, 234, 0.38)'
  static Color get invInkFaint => invInk.withValues(alpha: 0.30);

  // ─── Glass layers ───

  /// JSX: glass06 'rgba(255, 255, 255, 0.06)'
  static Color get glass06 => const Color(0xFFFFFFFF).withValues(alpha: 0.06);

  /// JSX: glass08 'rgba(255, 255, 255, 0.08)'
  static Color get glass08 => const Color(0xFFFFFFFF).withValues(alpha: 0.08);

  /// JSX: glass12 'rgba(255, 255, 255, 0.12)'
  static Color get glass12 => const Color(0xFFFFFFFF).withValues(alpha: 0.12);

  /// JSX: glassBorderHi 'rgba(255, 255, 255, 0.16)'
  static Color get glassBorderHi =>
      const Color(0xFFFFFFFF).withValues(alpha: 0.16);

  // ─── Yellow / Amber accent ───

  /// Primary yellow. JSX: yellow '#FFB701'
  static const Color yellow = Color(0xFFFFB701);

  /// Deep yellow. JSX: yellowDeep '#C18800'
  static const Color yellowDeep = Color(0xFFC18800);

  /// Yellow at 0.18 opacity. JSX: yellowSoft
  static Color get yellowSoft => yellow.withValues(alpha: 0.18);

  /// Yellow glow at 0.60 opacity. JSX: yellowGlow 'rgba(255, 183, 1, 0.45)'
  static Color get yellowGlow => yellow.withValues(alpha: 0.60);

  /// Weak yellow glow at 0.18. JSX: yellowGlowWeak 'rgba(255, 183, 1, 0.22)'
  static Color get yellowGlowWeak => yellow.withValues(alpha: 0.18);

  /// Dark ink on yellow buttons. JSX: yellowInk '#1F1812'
  static const Color yellowInk = Color(0xFF1F1812);

  // ─── Semantic ───

  /// Attention / fault color. JSX: attention '#D67B3E'
  static const Color attention = Color(0xFFD67B3E);

  /// Attention at 0.18 opacity.
  static Color get attentionSoft => attention.withValues(alpha: 0.18);

  /// Live / active color. JSX: live '#22C55E'
  static const Color live = Color(0xFF22C55E);

  /// Live at 0.22 opacity.
  static Color get liveSoft => live.withValues(alpha: 0.22);

  // ─── Typography ───

  /// Plus Jakarta Sans, bundled as asset font.
  static const String fontFamily = 'PlusJakartaSans';

  // ─── Convenience shadows ───

  static List<BoxShadow> get glassIconShadow => [
        BoxShadow(
          color: const Color(0xFF15110D).withValues(alpha: 0.30),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// Warm vignette gradient for overlay on camera feed.
  static LinearGradient get warmVignette => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          heroBg.withValues(alpha: 0.55),
          heroBg.withValues(alpha: 0.06),
          heroBg.withValues(alpha: 0.04),
          heroBg.withValues(alpha: 0.22),
          heroBg.withValues(alpha: 0.78),
        ],
        stops: const [0.0, 0.18, 0.60, 0.80, 1.0],
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// VikaIvoryMain — Premium Ivory register for the main-app screens (Home, Plan,
// Progress, Profile, Library). Sibling to VikaIvory; values come from the
// vika-main-app-ivory-v1.jsx prototype. Calibrated separately because the
// active-exercise-v8 prototype uses subtly different cream tones (#EBE3D2 vs
// #F4EEE2) and a darker ink (#2A1F12 vs #1F1812).
// ═══════════════════════════════════════════════════════════════════════════════

class VikaIvoryMain {
  const VikaIvoryMain._();

  // ─── Surfaces ───
  static const Color bg = Color(0xFFF4EEE2);
  static const Color bgRaised = Color(0xFFFBF7EE);
  static const Color bgInverse = Color(0xFF1F1812);
  static const Color bgInverseHi = Color(0xFF2A1F12);
  static const Color powder = Color(0xFFEDE2CD);

  // ─── Ink (always warm, never pure black) ───
  static const Color ink = Color(0xFF1F1812);
  static const Color inkSoft = Color(0xFF5A4A3A);
  static const Color inkFaint = Color(0xFF8B7A66);
  static const Color inkGhost = Color(0xFFC9BBA6);

  // ─── Inverse ink (on warm-dark surfaces) ───
  static const Color invInk = Color(0xFFF4EEE2);
  static Color get invInkSoft => invInk.withValues(alpha: 0.72);
  static Color get invInkFaint => invInk.withValues(alpha: 0.42);

  // ─── Borders (warm, ivory-aware) ───
  static const Color border = Color(0xFFE6DCC8);
  static const Color borderHi = Color(0xFFD4C8B0);
  static Color get borderDark => invInk.withValues(alpha: 0.10);

  // ─── Yellow — RESERVED for 4 uses only (stat / dot / underline / CTA) ───
  static const Color yellow = Color(0xFFFFB701);
  static const Color yellowInk = Color(0xFF1F1812);
  static Color get yellowGhost => yellow.withValues(alpha: 0.14);

  // ─── Status (used outside Plan, but lives here for completeness) ───
  static const Color attention = Color(0xFFD67B3E);
  static const Color live = Color(0xFF22C55E);

  // ─── Phase-distinct accents (used SPARINGLY, only for phase identity) ───
  static const Color phase1 = Color(0xFFA8C5B1); // sage — Khởi đầu
  static const Color phase2 = Color(0xFFE89A4B); // amber — Củng cố
  static const Color phase3 = Color(0xFFD67B3E); // earth — Đẩy mạnh
  static const Color phase4 = Color(0xFF7DA3D9); // dusk — Đỉnh cao

  // ─── Typography ───
  // Two-family pairing — see DESIGN.md § Typography.
  //
  //   serif  → Fraunces. Used in italic at display sizes (18–80pt).
  //            The signature editorial-coaching tone.
  //   sans   → BeVietnamPro. Workhorse for body, eyebrows, numerals.
  //            Designed for Vietnamese diacritics.
  //
  // `fontFamily` aliases the sans family — most usages (body / eyebrow /
  // labels) want the sans, so it stays the default.
  static const String serifFamily = 'Fraunces';
  static const String sansFamily = 'BeVietnamPro';
  static const String fontFamily = sansFamily;

  /// Tabular figures — stat numbers and dates need column-aligned digits.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// Phone-frame max width as referenced in the JSX (390pt iPhone). The plan
  /// screen lays out at this width; SafeArea + scaling handles smaller phones.
  static const double phoneWidth = 390;

  // ─── Card decorations ───
  static BoxDecoration creamCard({double radius = 22}) => BoxDecoration(
        color: bgRaised,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      );

  static BoxDecoration darkCard({double radius = 24}) => BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.4, -1),
          end: const Alignment(0.4, 1),
          colors: const [bgInverse, bgInverseHi],
        ),
        borderRadius: BorderRadius.circular(radius),
      );

  // ─── Yellow radial wash (top-right of warm-dark cards) ───
  static Decoration yellowWashTopRight({
    double topOffset = -50,
    double rightOffset = -60,
    double size = 200,
    double opacity = 0.18,
  }) {
    return BoxDecoration(
      gradient: RadialGradient(
        colors: [
          yellow.withValues(alpha: opacity),
          yellow.withValues(alpha: 0),
        ],
        stops: const [0, 0.65],
      ),
    );
  }
}
