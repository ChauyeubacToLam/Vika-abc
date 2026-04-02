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
