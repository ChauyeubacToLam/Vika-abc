import 'dart:ui';

import 'package:flutter/material.dart';

class VFTheme {
  const VFTheme._();

  static const Color bg = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF0F2F5);
  static const Color accent = Color(0xFF2E856E);
  static const Color accentBg = Color(0xFFE8F4EF);
  static const Color accentText = Color(0xFF1D5C4A);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueBg = Color(0xFFEEF4FF);
  static const Color amber = Color(0xFFD97706);
  static const Color amberBg = Color(0xFFFEF9EC);
  static const Color coral = Color(0xFFE04A2F);
  static const Color coralBg = Color(0xFFFAECE7);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleBg = Color(0xFFF4F0FF);
  static const Color text = Color(0xFF111318);
  static const Color textSec = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF9CA3B0);
  static const Color border = Color(0x0F000000);
  static const Color darkSurface = Color(0xFF111318);

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
      ).copyWith(
        surface: surface,
        primary: accent,
        onSurface: text,
        secondary: blue,
      ),
    );

    return base.copyWith(
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
      cardColor: surface,
      dividerColor: border,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
      ),
    );
  }

  static double scale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / 390).clamp(0.92, 1.1).toDouble();
  }

  static double font(BuildContext context, double size) {
    return size * scale(context);
  }

  static EdgeInsets screenPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return EdgeInsets.symmetric(horizontal: width * 0.051);
  }

  static double sectionGap(BuildContext context) => 10 * scale(context);

  static double cardRadius(BuildContext context) => 14 * scale(context);

  static double smallRadius(BuildContext context) => 10 * scale(context);

  static double iconTileRadius(BuildContext context) => 12 * scale(context);

  static double navHeight(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return (height * 0.084).clamp(64.0, 74.0).toDouble();
  }

  static double fabSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.135).clamp(50.0, 58.0).toDouble();
  }

  static BoxDecoration glassBarDecoration(BuildContext context) {
    return BoxDecoration(
      color: surface.withValues(alpha: 0.92),
      border: Border(
        top:
            BorderSide(color: Colors.black.withValues(alpha: 0.06), width: 0.5),
      ),
    );
  }

  static TextStyle headerLarge(BuildContext context, {Color color = text}) {
    return TextStyle(
      fontSize: font(context, 22),
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: -0.5,
      height: 1.05,
    );
  }

  static TextStyle sectionTitle(BuildContext context, {Color color = text}) {
    return TextStyle(
      fontSize: font(context, 16),
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: -0.3,
      height: 1.1,
    );
  }

  static TextStyle body(BuildContext context, {Color color = textSec}) {
    return TextStyle(
      fontSize: font(context, 13),
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.3,
    );
  }

  static TextStyle muted(BuildContext context, {double size = 11}) {
    return TextStyle(
      fontSize: font(context, size),
      fontWeight: FontWeight.w500,
      color: textMuted,
      height: 1.3,
    );
  }

  static TextStyle label(BuildContext context, {Color color = textMuted}) {
    return TextStyle(
      fontSize: font(context, 10),
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: 0.8,
      textBaseline: TextBaseline.alphabetic,
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
    this.sigma = 18,
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
          decoration: decoration ?? VFTheme.glassBarDecoration(context),
          child: child,
        ),
      ),
    );
  }
}
